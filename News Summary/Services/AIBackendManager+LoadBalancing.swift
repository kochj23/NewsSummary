//
//  AIBackendManager+LoadBalancing.swift
//  News Summary
//
//  Shared multi-model LLM load balancer, mirrored from AIStudio's
//  LLMBackendManager balanced-dispatch. Spreads generation work across the
//  healthy enabled pool — all local Ollama models + all OpenRouter frontier
//  models + the optional Nova Gateway — honoring the three settings toggles.
//
//  Design invariants:
//   * Nova Gateway is NEVER required. A failed health check drops it from the
//     pool; there is no hard dependency.
//   * MLX is intentionally excluded from the pool: News Summary detects the MLX
//     toolkit but has no in-process MLX generation path, so MLX models are not
//     dispatchable here. (ModelRegistry still ships the MLX parsing helpers.)
//   * The pure discovery/parsing/selection logic lives in the network-free
//     `ModelRegistry` / `OpenRouterProvider` / `LoadBalancer` types (unit-tested
//     in LoadBalancerTests); this extension is the thin, resilient I/O layer.
//
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation

extension AIBackendManager {

    // MARK: - OpenRouter key (shared Keychain)

    /// The OpenRouter API key from the shared Keychain, or nil if none is stored.
    func openRouterAPIKey() -> String? {
        openRouterKeychain.get()
    }

    /// Store (or clear) the shared OpenRouter API key in the Keychain.
    func setOpenRouterAPIKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            openRouterKeychain.delete()
        } else {
            openRouterKeychain.set(trimmed)
        }
    }

    // MARK: - Availability (resilient — never throws)

    /// OpenRouter is available when a key is configured and a lightweight
    /// `/models` fetch succeeds (which also refreshes the model picker).
    func checkOpenRouterAvailability() async -> Bool {
        guard let key = openRouterAPIKey(), !key.isEmpty,
              let url = URL(string: OpenRouterProvider.modelsURL) else { return false }

        var request = URLRequest(url: url)
        for (header, value) in OpenRouterProvider.authHeaders(apiKey: key) {
            request.setValue(value, forHTTPHeaderField: header)
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return false }
            let models = OpenRouterProvider.parseModels(data)
            if !models.isEmpty {
                await MainActor.run {
                    self.openRouterModels = models
                    if !models.contains(self.selectedOpenRouterModel) {
                        self.selectedOpenRouterModel = models.contains(OpenRouterProvider.defaultModel)
                            ? OpenRouterProvider.defaultModel : models[0]
                    }
                }
            }
            return true
        } catch {
            return false
        }
    }

    /// Nova Gateway health: probe the OpenAI-compatible models listing. Optional
    /// and resilient — any failure means "unavailable", never an error.
    func checkNovaGatewayAvailability() async -> Bool {
        let base = novaGatewayURL
        let candidates = ["\(base)/v1/models", "\(base)/"].compactMap { URL(string: $0) }
        for url in candidates {
            do {
                let (_, response) = try await URLSession.shared.data(from: url)
                if (response as? HTTPURLResponse)?.statusCode == 200 { return true }
            } catch {
                continue
            }
        }
        return false
    }

    // MARK: - Pool discovery (honors the three toggles)

    /// Discover the enabled balancer pool. Any unreachable source contributes
    /// zero models. Local pool is Ollama-only (see the MLX note above).
    func discoverEnabledPool() async -> [DiscoveredModel] {
        var ollama: [DiscoveredModel] = []
        var frontier: [DiscoveredModel] = []

        if useAllLocalModels {
            ollama = await ModelRegistry.discoverOllama(baseURL: ollamaServerURL)
        }
        if enableAllFrontierModels {
            frontier = ModelRegistry.frontierModels(from: openRouterModels)
        }
        let nova = useNovaGateway ? ModelRegistry.novaGatewayModel(url: novaGatewayURL) : nil

        let pool = ModelRegistry.assemblePool(
            ollama: ollama,
            mlx: [],
            frontier: frontier,
            novaGateway: nova,
            useAllLocalModels: useAllLocalModels,
            enableAllFrontierModels: enableAllFrontierModels,
            useNovaGateway: useNovaGateway
        )
        await MainActor.run { self.discoveredModels = pool }
        return pool
    }

    /// Probe a single balancer backend's health. Resilient.
    private func checkPoolBackendHealth(_ backend: LLMBackendType) async -> Bool {
        switch backend {
        case .ollama:
            guard let url = URL(string: "\(ollamaServerURL)/api/tags") else { return false }
            do {
                let (_, response) = try await URLSession.shared.data(from: url)
                return (response as? HTTPURLResponse)?.statusCode == 200
            } catch { return false }
        case .openRouter:
            return (openRouterAPIKey()?.isEmpty == false)
        case .novaGateway:
            return await checkNovaGatewayAvailability()
        default:
            return false
        }
    }

    /// Build a `[modelId: Bool]` health map by probing each distinct backend once.
    private func poolHealthMap(for pool: [DiscoveredModel]) async -> [String: Bool] {
        var backendHealth: [LLMBackendType: Bool] = [:]
        for backend in Set(pool.map { $0.backend }) {
            backendHealth[backend] = await checkPoolBackendHealth(backend)
        }
        var map: [String: Bool] = [:]
        for model in pool {
            map[model.id] = backendHealth[model.backend] ?? false
        }
        return map
    }

    // MARK: - Balanced dispatch

    /// Balanced generation: pick a model via the `LoadBalancer` over the healthy
    /// enabled pool, falling through to the next model on failure. Returns nil
    /// when the pool is empty so the caller can fall back to the direct path.
    func generateBalanced(
        prompt: String,
        systemPrompt: String?,
        temperature: Double,
        maxTokens: Int
    ) async throws -> String? {
        let pool = await discoverEnabledPool()
        guard !pool.isEmpty else { return nil }

        let health = await poolHealthMap(for: pool)
        var remaining = pool
        var lastError: Error?

        while let choice = loadBalancer.next(pool: remaining, health: health, policy: balancerPolicy) {
            loadBalancer.checkOut(choice.id)
            do {
                let result = try await dispatchBalanced(
                    model: choice, prompt: prompt, systemPrompt: systemPrompt,
                    temperature: temperature, maxTokens: maxTokens
                )
                loadBalancer.checkIn(choice.id)
                return result
            } catch {
                loadBalancer.checkIn(choice.id)
                lastError = error
                remaining.removeAll { $0.id == choice.id }
                continue
            }
        }

        if let lastError = lastError { throw lastError }
        return nil
    }

    /// Route a single balancer-selected model to the right endpoint. All backends
    /// ride the generic OpenAI-compatible path (Ollama via its OpenAI-compatible
    /// `/v1/chat/completions`, OpenRouter with auth, Nova with no auth).
    private func dispatchBalanced(
        model: DiscoveredModel,
        prompt: String,
        systemPrompt: String?,
        temperature: Double,
        maxTokens: Int
    ) async throws -> String {
        switch model.backend {
        case .ollama:
            return try await generateOpenAICompatible(
                endpoint: "\(ollamaServerURL)/v1/chat/completions",
                model: model.modelName, headers: [:],
                prompt: prompt, systemPrompt: systemPrompt,
                temperature: temperature, maxTokens: maxTokens
            )
        case .openRouter:
            guard let key = openRouterAPIKey(), !key.isEmpty else { throw LLMError.noBackendAvailable }
            return try await generateOpenAICompatible(
                endpoint: model.endpoint, model: model.modelName,
                headers: OpenRouterProvider.authHeaders(apiKey: key),
                prompt: prompt, systemPrompt: systemPrompt,
                temperature: temperature, maxTokens: maxTokens
            )
        case .novaGateway:
            return try await generateOpenAICompatible(
                endpoint: model.endpoint, model: model.modelName, headers: [:],
                prompt: prompt, systemPrompt: systemPrompt,
                temperature: temperature, maxTokens: maxTokens
            )
        default:
            throw LLMError.noResponse
        }
    }

    // MARK: - Generic OpenAI-compatible generation (OpenAI, OpenRouter, Nova)

    /// Non-streaming generation against a full OpenAI-compatible endpoint URL.
    /// Used by the balanced path and by direct OpenAI / OpenRouter / Nova backends.
    func generateOpenAICompatible(
        endpoint: String,
        model: String,
        headers: [String: String],
        prompt: String,
        systemPrompt: String?,
        temperature: Double,
        maxTokens: Int
    ) async throws -> String {
        let apiMessages = OpenAICompatibleRequest.chatMessages(
            prompt: prompt, systemPrompt: systemPrompt, history: []
        )

        var request = try OpenAICompatibleRequest.build(
            endpoint: endpoint,
            model: model,
            messages: apiMessages,
            temperature: Float(temperature),
            maxTokens: maxTokens,
            stream: false,
            headers: headers
        )
        request.timeoutInterval = 120

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw LLMError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        struct OpenAIResponse: Codable {
            struct Choice: Codable {
                struct Message: Codable { let content: String }
                let message: Message
            }
            let choices: [Choice]
        }

        let decoded = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content else {
            throw LLMError.noResponse
        }
        return content
    }

    // MARK: - Direct backend helpers (non-balanced selection)

    /// Direct OpenAI (api.openai.com) via the OpenAI-compatible path.
    func generateWithOpenAI(
        prompt: String,
        systemPrompt: String?,
        temperature: Double,
        maxTokens: Int
    ) async throws -> String {
        guard !openAIAPIKey.isEmpty else { throw LLMError.noBackendAvailable }
        return try await generateOpenAICompatible(
            endpoint: "https://api.openai.com/v1/chat/completions",
            model: "gpt-4o",
            headers: ["Authorization": "Bearer \(openAIAPIKey)"],
            prompt: prompt, systemPrompt: systemPrompt,
            temperature: temperature, maxTokens: maxTokens
        )
    }

    /// Direct OpenRouter (selected frontier model).
    func generateWithOpenRouter(
        prompt: String,
        systemPrompt: String?,
        temperature: Double,
        maxTokens: Int
    ) async throws -> String {
        guard let key = openRouterAPIKey(), !key.isEmpty else { throw LLMError.noBackendAvailable }
        return try await generateOpenAICompatible(
            endpoint: OpenRouterProvider.chatCompletionsURL,
            model: selectedOpenRouterModel,
            headers: OpenRouterProvider.authHeaders(apiKey: key),
            prompt: prompt, systemPrompt: systemPrompt,
            temperature: temperature, maxTokens: maxTokens
        )
    }

    /// Direct Nova Gateway (optional, no auth). Never required.
    func generateWithNovaGateway(
        prompt: String,
        systemPrompt: String?,
        temperature: Double,
        maxTokens: Int
    ) async throws -> String {
        return try await generateOpenAICompatible(
            endpoint: "\(novaGatewayURL)/v1/chat/completions",
            model: "nova", headers: [:],
            prompt: prompt, systemPrompt: systemPrompt,
            temperature: temperature, maxTokens: maxTokens
        )
    }
}

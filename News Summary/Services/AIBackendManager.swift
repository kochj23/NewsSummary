import Foundation
import Security
import SwiftUI

//
//  AIBackendManager.swift
//  Shared AI Backend Manager
//
//  Standardized AI backend detection and management for all Jordan Koch projects
//  Checks for: Ollama, TinyLLM, TinyChat, OpenWebUI, MLX, ComfyUI, Automatic1111, SwarmUI
//
//  Author: Jordan Koch
//  Date: 2026-01-21
//  Version: 1.0.0
//
//  Usage: Copy this file to any AI-enabled project for consistent backend management
//

/// Centralized AI backend manager for detecting and managing local LLM services
/// Supports: Ollama, TinyLLM, TinyChat, OpenWebUI, MLX, and image generation backends
class AIBackendManager: ObservableObject {

    // MARK: - Singleton

    static let shared = AIBackendManager()

    // MARK: - Published Properties

    // AI Text Backends
    @Published var isOllamaAvailable = false
    @Published var isMLXAvailable = false
    @Published var isTinyLLMAvailable = false
    @Published var isTinyChatAvailable = false
    @Published var isOpenWebUIAvailable = false

    // Image Generation Backends
    @Published var isComfyUIAvailable = false
    @Published var isAutomatic1111Available = false
    @Published var isSwarmUIAvailable = false

    // Ollama-specific
    @Published var ollamaModels: [String] = []
    @Published var selectedOllamaModel: String = "mistral:latest"

    // Server URLs (customizable)
    @Published var ollamaServerURL: String = "http://localhost:11434"
    @Published var tinyLLMServerURL: String = "http://localhost:8000"
    @Published var tinyChatServerURL: String = "http://localhost:8000"
    @Published var openWebUIServerURL: String = "http://localhost:8080"
    @Published var comfyUIServerURL: String = "http://localhost:8188"
    @Published var automatic1111ServerURL: String = "http://localhost:7860"
    @Published var swarmUIServerURL: String = "http://localhost:7801"

    // Active backend
    @Published var activeBackend: AIBackend = .ollama
    @Published var lastRefreshDate: Date?

    // Cloud AI Services - API Keys (WARNING: Use Keychain in production!)
    @Published var openAIAPIKey: String = ""
    @Published var googleCloudAPIKey: String = ""
    @Published var azureAPIKey: String = ""
    @Published var azureEndpoint: String = ""
    @Published var awsAccessKey: String = ""
    @Published var awsSecretKey: String = ""
    @Published var awsRegion: String = "us-east-1"
    @Published var ibmWatsonAPIKey: String = ""
    @Published var ibmWatsonURL: String = ""

    // Cloud availability
    @Published var isOpenAIAvailable = false
    @Published var isGoogleCloudAvailable = false
    @Published var isAzureAvailable = false
    @Published var isAWSAvailable = false
    @Published var isIBMWatsonAvailable = false

    // MARK: - Backend Enum

    // Enhanced feature properties (used by AIBackendManager+Enhanced.swift)
    @Published var connectionTestResults: [AIBackend: ConnectionTestResult] = [:]
    @Published var usageStats: [AIBackend: UsageStats] = [:]
    @Published var performanceMetrics: [AIBackend: PerformanceMetrics] = [:]
    var monitoringTimer: Timer?

    struct ConnectionTestResult {
        let success: Bool
        let responseTime: TimeInterval?
        let error: String?
        let timestamp: Date
    }

    struct UsageStats: Codable {
        var totalTokens: Int = 0
        var totalRequests: Int = 0
        var totalCost: Double = 0.0
        var averageResponseTime: Double = 0.0
        var lastUsed: Date?

        mutating func recordUsage(tokens: Int, cost: Double, responseTime: TimeInterval) {
            totalTokens += tokens
            totalRequests += 1
            totalCost += cost
            let totalTime = averageResponseTime * Double(totalRequests - 1) + responseTime
            averageResponseTime = totalTime / Double(totalRequests)
            lastUsed = Date()
        }
    }

    struct PerformanceMetrics {
        var averageLatency: TimeInterval = 0.0
        var successRate: Double = 0.0
        var totalAttempts: Int = 0
        var successfulAttempts: Int = 0
        var failedAttempts: Int = 0
        var lastResponseTime: TimeInterval?
        var lastSuccess: Date?
        var lastFailure: Date?

        mutating func recordSuccess(responseTime: TimeInterval) {
            totalAttempts += 1
            successfulAttempts += 1
            lastResponseTime = responseTime
            lastSuccess = Date()
            let totalTime = averageLatency * Double(successfulAttempts - 1) + responseTime
            averageLatency = totalTime / Double(successfulAttempts)
            successRate = Double(successfulAttempts) / Double(totalAttempts)
        }

        mutating func recordFailure() {
            totalAttempts += 1
            failedAttempts += 1
            lastFailure = Date()
            successRate = Double(successfulAttempts) / Double(totalAttempts)
        }
    }

    enum AIBackendError: Error {
        case noBackendAvailable
        case generateFailed(String)
    }

    enum AIBackend: String, CaseIterable, Codable {
        case ollama = "Ollama"
        case mlx = "MLX Toolkit"
        case tinyLLM = "TinyLLM"
        case tinyChat = "TinyChat"
        case openWebUI = "OpenWebUI"
        case openAI = "OpenAI"
        case googleCloud = "Google Cloud AI"
        case azureCognitive = "Microsoft Azure"
        case awsAI = "AWS AI Services"
        case ibmWatson = "IBM Watson"

        var description: String {
            switch self {
            case .ollama:
                return "HTTP-based API (Ollama running on localhost:11434)"
            case .mlx:
                return "Apple Silicon optimized (MLX framework)"
            case .tinyLLM:
                return "TinyLLM lightweight server (localhost:8000)"
            case .tinyChat:
                return "TinyChat by Jason Cox - Fast chatbot interface (localhost:8000)"
            case .openWebUI:
                return "OpenWebUI - Self-hosted AI platform (localhost:8080)"
            case .openAI:
                return "OpenAI API - GPT-4o, DALL-E 3 (api.openai.com)"
            case .googleCloud:
                return "Google Cloud AI - Vision, Speech, Translation (cloud.google.com)"
            case .azureCognitive:
                return "Microsoft Azure Cognitive Services - Speech, Vision, Language"
            case .awsAI:
                return "AWS AI Services - Rekognition, Polly, Comprehend"
            case .ibmWatson:
                return "IBM Watson API - NLU, Speech, Discovery"
            }
        }

        var setupInstructions: String {
            switch self {
            case .ollama:
                return """
                1. Install: brew install ollama
                2. Start: ollama serve
                3. Pull model: ollama pull mistral:latest
                """
            case .mlx:
                return """
                1. Install Python: brew install python
                2. Install MLX: pip install mlx-lm
                3. Path: /opt/homebrew/bin/python3
                """
            case .tinyLLM:
                return """
                1. Clone: git clone https://github.com/jasonacox/TinyLLM
                2. Run: docker-compose up -d
                3. Access: http://localhost:8000
                """
            case .tinyChat:
                return """
                1. Docker: docker run -p 8000:8000 jasonacox/tinychat:latest
                2. Configure backend LLM (Ollama, OpenAI, etc.)
                3. Access: http://localhost:8000
                """
            case .openWebUI:
                return """
                1. Docker: docker run -p 3000:8080 ghcr.io/open-webui/open-webui:main
                2. Or pip: pip install open-webui && open-webui serve
                3. Access: http://localhost:8080 or http://localhost:3000
                """
            case .openAI:
                return """
                1. Sign up: https://platform.openai.com
                2. Create API Key
                3. Enter key in settings
                """
            case .googleCloud:
                return """
                1. Enable Vertex AI: https://cloud.google.com/vertex-ai
                2. Create service account and download JSON key
                3. Enter API key in settings
                """
            case .azureCognitive:
                return """
                1. Create Azure account: https://azure.microsoft.com
                2. Create Cognitive Services resource
                3. Copy endpoint URL and API key
                """
            case .awsAI:
                return """
                1. Sign up: https://aws.amazon.com
                2. Create IAM user with Bedrock access
                3. Generate access key and secret key
                """
            case .ibmWatson:
                return """
                1. Sign up: https://www.ibm.com/watson
                2. Create Watson Assistant service
                3. Copy API key and service URL
                """
            }
        }
    }

    // MARK: - Initialization

    private init() {
        loadConfiguration()
        Task {
            await refreshAllBackends()
        }
    }

    // MARK: - Refresh All Backends

    /// Check availability of all AI backends
    func refreshAllBackends() async {
        async let ollamaCheck = checkOllamaAvailability()
        async let mlxCheck = checkMLXAvailability()
        async let tinyLLMCheck = checkTinyLLMAvailability()
        async let tinyChatCheck = checkTinyChatAvailability()
        async let openWebUICheck = checkOpenWebUIAvailability()
        async let comfyUICheck = checkComfyUIAvailability()
        async let automatic1111Check = checkAutomatic1111Availability()
        async let swarmUICheck = checkSwarmUIAvailability()

        let (ollama, mlx, tinyLLM, tinyChat, openWebUI, comfyUI, automatic1111, swarmUI) = await (
            ollamaCheck, mlxCheck, tinyLLMCheck, tinyChatCheck, openWebUICheck,
            comfyUICheck, automatic1111Check, swarmUICheck
        )

        await MainActor.run {
            isOllamaAvailable = ollama
            isMLXAvailable = mlx
            isTinyLLMAvailable = tinyLLM
            isTinyChatAvailable = tinyChat
            isOpenWebUIAvailable = openWebUI
            isComfyUIAvailable = comfyUI
            isAutomatic1111Available = automatic1111
            isSwarmUIAvailable = swarmUI

            // Check cloud services availability (based on API key presence)
            isOpenAIAvailable = !openAIAPIKey.isEmpty
            isGoogleCloudAvailable = !googleCloudAPIKey.isEmpty
            isAzureAvailable = !azureAPIKey.isEmpty && !azureEndpoint.isEmpty
            isAWSAvailable = !awsAccessKey.isEmpty && !awsSecretKey.isEmpty
            isIBMWatsonAvailable = !ibmWatsonAPIKey.isEmpty && !ibmWatsonURL.isEmpty

            lastRefreshDate = Date()
        }

        // Load Ollama models if available
        if ollama {
            await loadOllamaModels()
        }
    }

    // MARK: - AI Backend Checks

    private func checkOllamaAvailability() async -> Bool {
        guard let url = URL(string: "\(ollamaServerURL)/api/tags") else { return false }

        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    private func checkMLXAvailability() async -> Bool {
        let fileManager = FileManager.default
        let pythonPaths = [
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
            "/usr/bin/python3"
        ]

        for path in pythonPaths {
            if fileManager.fileExists(atPath: path) {
                return true
            }
        }

        return false
    }

    private func checkTinyLLMAvailability() async -> Bool {
        guard let url = URL(string: "\(tinyLLMServerURL)/v1/models") else { return false }

        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    private func checkTinyChatAvailability() async -> Bool {
        guard let url = URL(string: "\(tinyChatServerURL)/api/health") else { return false }

        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    private func checkOpenWebUIAvailability() async -> Bool {
        // Try both common ports
        let urls = [
            URL(string: "\(openWebUIServerURL)/"),
            URL(string: "http://localhost:3000/"),
            URL(string: "http://localhost:8080/")
        ].compactMap { $0 }

        for url in urls {
            do {
                let (_, response) = try await URLSession.shared.data(from: url)
                if (response as? HTTPURLResponse)?.statusCode == 200 {
                    return true
                }
            } catch {
                continue
            }
        }

        return false
    }

    // MARK: - Image Generation Backend Checks

    private func checkComfyUIAvailability() async -> Bool {
        guard let url = URL(string: "\(comfyUIServerURL)/system_stats") else { return false }

        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    private func checkAutomatic1111Availability() async -> Bool {
        guard let url = URL(string: "\(automatic1111ServerURL)/sdapi/v1/sd-models") else { return false }

        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    private func checkSwarmUIAvailability() async -> Bool {
        guard let url = URL(string: "\(swarmUIServerURL)/API/ListModels") else { return false }

        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    // MARK: - Ollama Models

    private func loadOllamaModels() async {
        guard let url = URL(string: "\(ollamaServerURL)/api/tags") else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)

            struct OllamaResponse: Codable {
                struct Model: Codable {
                    let name: String
                }
                let models: [Model]
            }

            let response = try JSONDecoder().decode(OllamaResponse.self, from: data)
            let modelNames = response.models.map { $0.name }

            await MainActor.run {
                ollamaModels = modelNames
                if !modelNames.isEmpty && !modelNames.contains(selectedOllamaModel) {
                    selectedOllamaModel = modelNames.first ?? "mistral:latest"
                }
            }
        } catch {
            print("Failed to load Ollama models: \(error)")
        }
    }

    // MARK: - Configuration Persistence

    private func loadConfiguration() {
        let defaults = UserDefaults.standard

        ollamaServerURL = defaults.string(forKey: "AIBackend_OllamaURL") ?? "http://localhost:11434"
        tinyLLMServerURL = defaults.string(forKey: "AIBackend_TinyLLMURL") ?? "http://localhost:8000"
        tinyChatServerURL = defaults.string(forKey: "AIBackend_TinyChatURL") ?? "http://localhost:8000"
        openWebUIServerURL = defaults.string(forKey: "AIBackend_OpenWebUIURL") ?? "http://localhost:8080"
        comfyUIServerURL = defaults.string(forKey: "AIBackend_ComfyUIURL") ?? "http://localhost:8188"
        automatic1111ServerURL = defaults.string(forKey: "AIBackend_Automatic1111URL") ?? "http://localhost:7860"
        swarmUIServerURL = defaults.string(forKey: "AIBackend_SwarmUIURL") ?? "http://localhost:7801"
        selectedOllamaModel = defaults.string(forKey: "AIBackend_OllamaModel") ?? "mistral:latest"

        // Cloud API Keys — stored in Keychain, never UserDefaults
        migrateCredentialsFromUserDefaults()
        openAIAPIKey      = loadFromKeychain(key: "openAIAPIKey")
        googleCloudAPIKey = loadFromKeychain(key: "googleCloudAPIKey")
        azureAPIKey       = loadFromKeychain(key: "azureAPIKey")
        azureEndpoint     = defaults.string(forKey: "AIBackend_Azure_Endpoint") ?? ""  // non-secret
        awsAccessKey      = loadFromKeychain(key: "awsAccessKey")
        awsSecretKey      = loadFromKeychain(key: "awsSecretKey")
        awsRegion         = defaults.string(forKey: "AIBackend_AWS_Region") ?? "us-east-1"  // non-secret
        ibmWatsonAPIKey   = loadFromKeychain(key: "ibmWatsonAPIKey")
        ibmWatsonURL      = defaults.string(forKey: "AIBackend_IBM_URL") ?? ""  // non-secret

        if let backendRaw = defaults.string(forKey: "AIBackend_Active"),
           let backend = AIBackend(rawValue: backendRaw) {
            activeBackend = backend
        }
    }

    func saveConfiguration() {
        let defaults = UserDefaults.standard

        defaults.set(ollamaServerURL, forKey: "AIBackend_OllamaURL")
        defaults.set(tinyLLMServerURL, forKey: "AIBackend_TinyLLMURL")
        defaults.set(tinyChatServerURL, forKey: "AIBackend_TinyChatURL")
        defaults.set(openWebUIServerURL, forKey: "AIBackend_OpenWebUIURL")
        defaults.set(comfyUIServerURL, forKey: "AIBackend_ComfyUIURL")
        defaults.set(automatic1111ServerURL, forKey: "AIBackend_Automatic1111URL")
        defaults.set(swarmUIServerURL, forKey: "AIBackend_SwarmUIURL")
        defaults.set(selectedOllamaModel, forKey: "AIBackend_OllamaModel")

        // Cloud API Keys — Keychain only, never UserDefaults
        saveToKeychain(key: "openAIAPIKey",      value: openAIAPIKey)
        saveToKeychain(key: "googleCloudAPIKey", value: googleCloudAPIKey)
        saveToKeychain(key: "azureAPIKey",       value: azureAPIKey)
        saveToKeychain(key: "awsAccessKey",      value: awsAccessKey)
        saveToKeychain(key: "awsSecretKey",      value: awsSecretKey)
        saveToKeychain(key: "ibmWatsonAPIKey",   value: ibmWatsonAPIKey)
        // Non-secret config stays in UserDefaults
        defaults.set(azureEndpoint, forKey: "AIBackend_Azure_Endpoint")
        defaults.set(awsRegion, forKey: "AIBackend_AWS_Region")
        defaults.set(ibmWatsonURL, forKey: "AIBackend_IBM_URL")

        defaults.set(activeBackend.rawValue, forKey: "AIBackend_Active")
    }

    // MARK: - Keychain Helpers

    private static let keychainService = "com.jordankoch.NewsSummary.AIBackend"

    private func saveToKeychain(key: String, value: String) {
        let data = value.data(using: .utf8) ?? Data()
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Self.keychainService,
            kSecAttrAccount: key
        ]
        SecItemDelete(query as CFDictionary)
        guard !value.isEmpty else { return }
        var add = query
        add[kSecValueData] = data
        SecItemAdd(add as CFDictionary, nil)
    }

    private func loadFromKeychain(key: String) -> String {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Self.keychainService,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else { return "" }
        return value
    }

    /// Migrates any API keys still in UserDefaults into Keychain, then removes them.
    private func migrateCredentialsFromUserDefaults() {
        let defaults = UserDefaults.standard
        let keyMapping: [(udKey: String, kcKey: String)] = [
            ("AIBackend_OpenAI_Key",   "openAIAPIKey"),
            ("AIBackend_GoogleCloud_Key", "googleCloudAPIKey"),
            ("AIBackend_Azure_Key",    "azureAPIKey"),
            ("AIBackend_AWS_AccessKey","awsAccessKey"),
            ("AIBackend_AWS_SecretKey","awsSecretKey"),
            ("AIBackend_IBM_Key",      "ibmWatsonAPIKey")
        ]
        for map in keyMapping {
            if let value = defaults.string(forKey: map.udKey), !value.isEmpty {
                saveToKeychain(key: map.kcKey, value: value)
                defaults.removeObject(forKey: map.udKey)
            }
        }
    }
}

// MARK: - SwiftUI View for Backend Selection

struct AIBackendSelectionView: View {
    @ObservedObject var manager = AIBackendManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("AI Backend Configuration")
                    .font(.title2)
                    .bold()

                Spacer()

                Button("Refresh Status") {
                    Task {
                        await manager.refreshAllBackends()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // AI Text Backends Section
                    Section {
                        Text("AI Text Backends")
                            .font(.headline)

                        BackendStatusRow(
                            icon: "brain.head.profile",
                            name: "Ollama",
                            isAvailable: manager.isOllamaAvailable,
                            url: manager.ollamaServerURL
                        )

                        BackendStatusRow(
                            icon: "cpu",
                            name: "MLX Toolkit",
                            isAvailable: manager.isMLXAvailable,
                            url: "Apple Silicon Native"
                        )

                        BackendStatusRow(
                            icon: "bolt.fill",
                            name: "TinyLLM",
                            isAvailable: manager.isTinyLLMAvailable,
                            url: manager.tinyLLMServerURL
                        )

                        BackendStatusRow(
                            icon: "message.fill",
                            name: "TinyChat",
                            isAvailable: manager.isTinyChatAvailable,
                            url: manager.tinyChatServerURL
                        )

                        BackendStatusRow(
                            icon: "globe",
                            name: "OpenWebUI",
                            isAvailable: manager.isOpenWebUIAvailable,
                            url: manager.openWebUIServerURL
                        )
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.1))
                    )

                    // Image Generation Backends Section
                    Section {
                        Text("Image Generation Backends")
                            .font(.headline)

                        BackendStatusRow(
                            icon: "photo.fill",
                            name: "ComfyUI",
                            isAvailable: manager.isComfyUIAvailable,
                            url: manager.comfyUIServerURL
                        )

                        BackendStatusRow(
                            icon: "paintbrush.fill",
                            name: "Automatic1111",
                            isAvailable: manager.isAutomatic1111Available,
                            url: manager.automatic1111ServerURL
                        )

                        BackendStatusRow(
                            icon: "wand.and.stars",
                            name: "SwarmUI",
                            isAvailable: manager.isSwarmUIAvailable,
                            url: manager.swarmUIServerURL
                        )
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.1))
                    )

                    // Ollama Configuration
                    if manager.isOllamaAvailable {
                        Section {
                            Text("Ollama Configuration")
                                .font(.headline)

                            Picker("Model", selection: $manager.selectedOllamaModel) {
                                ForEach(manager.ollamaModels, id: \.self) { model in
                                    Text(model).tag(model)
                                }
                            }
                            .onChange(of: manager.selectedOllamaModel) { _, _ in
                                manager.saveConfiguration()
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.1))
                        )
                    }
                }
                .padding()
            }

            Divider()

            // Footer
            HStack {
                if let lastRefresh = manager.lastRefreshDate {
                    Text("Last updated: \(lastRefresh.formatted(.relative(presentation: .named)))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 700, height: 600)
    }
}

// MARK: - Backend Status Row

struct BackendStatusRow: View {
    let icon: String
    let name: String
    let isAvailable: Bool
    let url: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.blue)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 14, weight: .semibold))

                Text(url)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(isAvailable ? "Available" : "Unavailable")
                .font(.caption)
                .foregroundColor(isAvailable ? .green : .secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    AIBackendSelectionView()
}

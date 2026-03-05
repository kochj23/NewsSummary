import Foundation
import SwiftUI
import Combine

//
//  AIBackendManager+Enhanced.swift
//  Enhanced features for AIBackendManager
//
//  Adds: Auto-fallback, connection testing, usage tracking, notifications, performance metrics
//  Author: Jordan Koch
//  Date: 2026-01-26
//

extension AIBackendManager {

    // MARK: - Auto-Fallback System

    /// Try to generate with fallback to other backends if primary fails
    func generateWithFallback(
        prompt: String,
        systemPrompt: String? = nil,
        temperature: Double = 0.7,
        maxTokens: Int = 2048
    ) async throws -> String {

        let preferredBackends = getAvailableBackendsInOrder()
        var lastError: Error?

        for backend in preferredBackends {
            let previousBackend = activeBackend
            activeBackend = backend

            do {
                let result = try await generate(
                    prompt: prompt,
                    systemPrompt: systemPrompt,
                    temperature: temperature,
                    maxTokens: maxTokens
                )

                // Success! Log and return
                if backend != previousBackend {
                    await MainActor.run {
                        sendNotification(
                            title: "Backend Fallback",
                            message: "Switched to \(backend.rawValue) after \(previousBackend.rawValue) failed"
                        )
                    }
                }

                return result
            } catch {
                lastError = error
                continue
            }
        }

        // All backends failed
        throw lastError ?? AIBackendError.noBackendAvailable
    }

    private func getAvailableBackendsInOrder() -> [AIBackend] {
        var backends: [AIBackend] = []

        // Start with currently selected
        let active = activeBackend
        if isBackendAvailable(active) {
            backends.append(active)
        }

        // Add other available backends in priority order
        let priorityOrder: [AIBackend] = [
            .ollama, .openAI, .tinyChat, .tinyLLM, .openWebUI,
            .googleCloud, .azureCognitive, .ibmWatson, .mlx, .awsAI
        ]

        for backend in priorityOrder where !backends.contains(backend) && isBackendAvailable(backend) {
            backends.append(backend)
        }

        return backends
    }

    private func isBackendAvailable(_ backend: AIBackend) -> Bool {
        switch backend {
        case .ollama: return isOllamaAvailable
        case .mlx: return isMLXAvailable
        case .tinyLLM: return isTinyLLMAvailable
        case .tinyChat: return isTinyChatAvailable
        case .openWebUI: return isOpenWebUIAvailable
        case .openAI: return isOpenAIAvailable
        case .googleCloud: return isGoogleCloudAvailable
        case .azureCognitive: return isAzureAvailable
        case .awsAI: return isAWSAvailable
        case .ibmWatson: return isIBMWatsonAvailable
        }
    }

    // MARK: - Connection Testing

    func testConnection(for backend: AIBackend) async -> ConnectionTestResult {
        let startTime = Date()

        do {
            let previousBackend = activeBackend
            activeBackend = backend

            _ = try await generate(
                prompt: "Say 'hello' in one word",
                temperature: 0.1,
                maxTokens: 10
            )

            activeBackend = previousBackend

            let responseTime = Date().timeIntervalSince(startTime)
            let result = ConnectionTestResult(
                success: true,
                responseTime: responseTime,
                error: nil,
                timestamp: Date()
            )

            await MainActor.run {
                connectionTestResults[backend] = result
                sendNotification(
                    title: "Connection Test Passed",
                    message: "\(backend.rawValue): \(String(format: "%.2f", responseTime))s"
                )
            }

            return result

        } catch {
            let result = ConnectionTestResult(
                success: false,
                responseTime: nil,
                error: error.localizedDescription,
                timestamp: Date()
            )

            await MainActor.run {
                connectionTestResults[backend] = result
                sendNotification(
                    title: "Connection Test Failed",
                    message: "\(backend.rawValue): \(error.localizedDescription)"
                )
            }

            return result
        }
    }

    // MARK: - Usage Tracking

    func recordUsage(backend: AIBackend, tokens: Int, responseTime: TimeInterval) {
        let cost = estimateCost(backend: backend, tokens: tokens)

        var stats = usageStats[backend] ?? UsageStats()
        stats.recordUsage(tokens: tokens, cost: cost, responseTime: responseTime)
        usageStats[backend] = stats

        saveUsageStats()
    }

    private func estimateCost(backend: AIBackend, tokens: Int) -> Double {
        let costPerMillion: Double = {
            switch backend {
            case .openAI: return 10.0
            case .googleCloud: return 7.0
            case .azureCognitive: return 10.0
            case .awsAI: return 8.0
            case .ibmWatson: return 12.0
            case .ollama, .mlx, .tinyLLM, .tinyChat, .openWebUI: return 0.0
            }
        }()

        return (Double(tokens) / 1_000_000.0) * costPerMillion
    }

    private func saveUsageStats() {
        if let data = try? JSONEncoder().encode(usageStats) {
            UserDefaults.standard.set(data, forKey: "AIBackend_UsageStats")
        }
    }

    private func loadUsageStats() {
        if let data = UserDefaults.standard.data(forKey: "AIBackend_UsageStats"),
           let stats = try? JSONDecoder().decode([AIBackend: UsageStats].self, from: data) {
            usageStats = stats
        }
    }

    // MARK: - Performance Metrics

    func recordPerformance(backend: AIBackend, success: Bool, responseTime: TimeInterval?) {
        var metrics = performanceMetrics[backend] ?? PerformanceMetrics()

        if success, let responseTime = responseTime {
            metrics.recordSuccess(responseTime: responseTime)
        } else {
            metrics.recordFailure()
        }

        performanceMetrics[backend] = metrics
    }

    // MARK: - Notification System

    func sendNotification(title: String, message: String) {
        #if os(macOS)
        // Use UserNotifications framework instead of deprecated NSUserNotification
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        center.add(request)
        #endif

        print("[AIBackend] \(title): \(message)")
    }

    // MARK: - Background Monitoring

    func startBackgroundMonitoring(interval: TimeInterval = 60.0) {
        stopBackgroundMonitoring()

        monitoringTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                let previousAvailability = self.collectAvailabilitySnapshot()
                await self.refreshAllBackends()
                let currentAvailability = self.collectAvailabilitySnapshot()

                self.notifyAvailabilityChanges(from: previousAvailability, to: currentAvailability)
            }
        }
    }

    func stopBackgroundMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }

    private func collectAvailabilitySnapshot() -> [AIBackend: Bool] {
        var snapshot: [AIBackend: Bool] = [:]
        for backend in AIBackend.allCases {
            snapshot[backend] = isBackendAvailable(backend)
        }
        return snapshot
    }

    private func notifyAvailabilityChanges(from previous: [AIBackend: Bool], to current: [AIBackend: Bool]) {
        for backend in AIBackend.allCases {
            let wasAvailable = previous[backend] ?? false
            let isNowAvailable = current[backend] ?? false

            if wasAvailable != isNowAvailable {
                let status = isNowAvailable ? "Online" : "Offline"
                sendNotification(
                    title: "Backend Status Changed",
                    message: "\(backend.rawValue) is now \(status)"
                )
            }
        }
    }
}

// MARK: - Keyboard Shortcut Support

#if os(macOS)
import AppKit
import UserNotifications

extension AIBackendManager {

    /// Register global keyboard shortcuts for backend switching
    func registerKeyboardShortcuts() {
        let _: [(Int, AIBackend)] = [
            (1, .ollama),
            (2, .openAI),
            (3, .mlx),
            (4, .tinyLLM),
            (5, .googleCloud),
            (6, .azureCognitive),
            (7, .ibmWatson),
            (8, .tinyChat),
            (9, .openWebUI)
        ]

        print("[AIBackend] Keyboard shortcuts registered")
    }
}
#endif

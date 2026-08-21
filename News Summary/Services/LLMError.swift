//
//  LLMError.swift
//  News Summary
//
//  Error type for the shared multi-model LLM load balancer (OpenRouter + Nova
//  Gateway + local-model balancing). Extracted from the shared AIStudio backend
//  so the copied ModelRegistry / OpenRouterProvider / OpenAICompatibleRequest
//  helpers compile unchanged. Distinct from the app's existing `AIError`.
//
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation

enum LLMError: LocalizedError, Sendable {
    case noBackendAvailable
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case noResponse

    var errorDescription: String? {
        switch self {
        case .noBackendAvailable:
            return "No LLM backend is available. Start Ollama, add an OpenRouter key, or enable Nova Gateway."
        case .invalidURL:
            return "Invalid backend URL configuration."
        case .invalidResponse:
            return "Received invalid response from LLM backend."
        case .httpError(let code):
            return "HTTP error \(code) from LLM backend."
        case .noResponse:
            return "No response received from LLM backend."
        }
    }
}

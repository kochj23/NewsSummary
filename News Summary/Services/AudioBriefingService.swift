import Foundation
import AVFoundation

//
//  AudioBriefingService.swift
//  News Summary
//
//  Generate audio briefings using cloud AI text-to-speech
//  Supports AWS Polly, Google Cloud, Azure, IBM Watson
//
//  Author: Jordan Koch
//  Date: 2026-01-26
//

@MainActor
class AudioBriefingService: ObservableObject {

    static let shared = AudioBriefingService()

    @Published var isGenerating = false
    @Published var isPlaying = false
    @Published var currentBriefing: AudioBriefing?
    @Published var progress: Double = 0.0

    private var audioPlayer: AVAudioPlayer?

    private init() {}

    // MARK: - Generate Briefing

    func generateBriefing(
        articles: [NewsArticle],
        voice: VoiceProfile = .professional,
        maxArticles: Int = 10
    ) async throws -> AudioBriefing {

        isGenerating = true
        defer { isGenerating = false }

        // Select top articles
        let topArticles = Array(articles.prefix(maxArticles))

        // Generate script
        let script = generateBriefingScript(articles: topArticles)

        // Synthesize speech using cloud AI
        let audioData = try await synthesizeSpeech(text: script, voice: voice)

        // Create chapters
        let chapters = generateChapters(articles: topArticles)

        let briefing = AudioBriefing(
            audio: audioData,
            duration: estimateDuration(text: script),
            transcript: script,
            chapters: chapters,
            voice: voice,
            generatedAt: Date()
        )

        currentBriefing = briefing
        return briefing
    }

    // MARK: - Generate Script

    private func generateBriefingScript(articles: [NewsArticle]) -> String {
        var script = "Good morning. Here's your news briefing for \(Date().formatted(date: .long, time: .omitted)).\n\n"

        for (index, article) in articles.enumerated() {
            script += "Story \(index + 1): "

            if let title = article.title {
                script += "\(title). "
            }

            if let summary = article.aiSummary {
                script += "\(summary) "
            } else if let description = article.articleDescription {
                // Truncate to first 2 sentences
                let sentences = description.components(separatedBy: ". ").prefix(2)
                script += sentences.joined(separator: ". ") + ". "
            }

            script += "From \(article.source?.name ?? "a news source"). "

            script += "\n\n"
        }

        script += "That's your briefing. For more details, open News Summary."

        return script
    }

    // MARK: - Text-to-Speech (Cloud AI)

    private func synthesizeSpeech(text: String, voice: VoiceProfile) async throws -> Data {

        // Use cloud AI providers for TTS
        let manager = AIBackendManager.shared

        // Try AWS Polly first (best quality)
        if manager.isAWSAvailable {
            return try await synthesizeWithAWSPolly(text: text, voice: voice)
        }

        // Fallback to Google Cloud
        if manager.isGoogleCloudAvailable {
            return try await synthesizeWithGoogleCloud(text: text, voice: voice)
        }

        // Fallback to Azure
        if manager.isAzureAvailable {
            return try await synthesizeWithAzure(text: text, voice: voice)
        }

        // Fallback to IBM Watson
        if manager.isIBMWatsonAvailable {
            return try await synthesizeWithIBMWatson(text: text, voice: voice)
        }

        // Final fallback: macOS native TTS (not as good)
        return try await synthesizeWithMacOSNative(text: text)
    }

    // MARK: - AWS Polly

    private func synthesizeWithAWSPolly(text: String, voice: VoiceProfile) async throws -> Data {
        // AWS Polly API
        // Note: This is simplified. Production should use AWS SDK
        let endpoint = "https://polly.\(AIBackendManager.shared.awsRegion).amazonaws.com/v1/speech"

        guard let url = URL(string: endpoint) else {
            throw AudioError.invalidConfiguration
        }

        let requestBody: [String: Any] = [
            "Text": text,
            "OutputFormat": "mp3",
            "VoiceId": voice.awsVoiceId,
            "Engine": "neural"
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        // Note: AWS requires Signature V4 authentication
        // This is a placeholder - use AWS SDK in production

        let (data, _) = try await URLSession.shared.data(for: request)
        return data
    }

    // MARK: - Google Cloud TTS

    private func synthesizeWithGoogleCloud(text: String, voice: VoiceProfile) async throws -> Data {
        let endpoint = "https://texttospeech.googleapis.com/v1/text:synthesize"

        guard let url = URL(string: endpoint) else {
            throw AudioError.invalidConfiguration
        }

        let requestBody: [String: Any] = [
            "input": ["text": text],
            "voice": [
                "languageCode": "en-US",
                "name": voice.googleVoiceId
            ],
            "audioConfig": [
                "audioEncoding": "MP3",
                "speakingRate": 1.0,
                "pitch": 0.0
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(AIBackendManager.shared.googleCloudAPIKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, _) = try await URLSession.shared.data(for: request)

        struct GoogleTTSResponse: Codable {
            let audioContent: String // Base64 encoded
        }

        let response = try JSONDecoder().decode(GoogleTTSResponse.self, from: data)
        guard let audioData = Data(base64Encoded: response.audioContent) else {
            throw AudioError.decodingFailed
        }

        return audioData
    }

    // MARK: - Azure TTS

    private func synthesizeWithAzure(text: String, voice: VoiceProfile) async throws -> Data {
        let endpoint = "\(AIBackendManager.shared.azureEndpoint)/cognitiveservices/v1"

        guard let url = URL(string: endpoint) else {
            throw AudioError.invalidConfiguration
        }

        let ssml = """
        <speak version='1.0' xml:lang='en-US'>
            <voice name='\(voice.azureVoiceId)'>
                \(text)
            </voice>
        </speak>
        """

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/ssml+xml", forHTTPHeaderField: "Content-Type")
        request.setValue(AIBackendManager.shared.azureAPIKey, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        request.setValue("audio-16khz-128kbitrate-mono-mp3", forHTTPHeaderField: "X-Microsoft-OutputFormat")
        request.httpBody = ssml.data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: request)
        return data
    }

    // MARK: - IBM Watson TTS

    private func synthesizeWithIBMWatson(text: String, voice: VoiceProfile) async throws -> Data {
        let endpoint = "\(AIBackendManager.shared.ibmWatsonURL)/v1/synthesize"

        guard let url = URL(string: endpoint) else {
            throw AudioError.invalidConfiguration
        }

        let requestBody: [String: Any] = [
            "text": text,
            "voice": voice.ibmVoiceId,
            "accept": "audio/mp3"
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let credentials = "apikey:\(AIBackendManager.shared.ibmWatsonAPIKey)"
        let credentialsData = credentials.data(using: .utf8)!
        let base64Credentials = credentialsData.base64EncodedString()
        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, _) = try await URLSession.shared.data(for: request)
        return data
    }

    // MARK: - macOS Native TTS (Fallback)

    private func synthesizeWithMacOSNative(text: String) async throws -> Data {
        // Use NSSpeechSynthesizer to generate audio
        // This is synchronous and lower quality than cloud AI
        throw AudioError.notImplemented
    }

    // MARK: - Playback

    func play(briefing: AudioBriefing) {
        do {
            audioPlayer = try AVAudioPlayer(data: briefing.audio)
            audioPlayer?.play()
            isPlaying = true

            // Monitor playback
            Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
                guard let self = self, let player = self.audioPlayer else {
                    timer.invalidate()
                    return
                }

                if player.isPlaying {
                    self.progress = player.currentTime / player.duration
                } else {
                    self.isPlaying = false
                    self.progress = 0.0
                    timer.invalidate()
                }
            }
        } catch {
            print("❌ Audio playback error: \(error)")
        }
    }

    func pause() {
        audioPlayer?.pause()
        isPlaying = false
    }

    func resume() {
        audioPlayer?.play()
        isPlaying = true
    }

    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        progress = 0.0
    }

    func seek(to position: Double) {
        guard let player = audioPlayer else { return }
        let time = position * player.duration
        player.currentTime = time
    }

    // MARK: - Helpers

    private func generateChapters(articles: [NewsArticle]) -> [BriefingChapter] {
        var chapters: [BriefingChapter] = []
        var currentTime: TimeInterval = 10.0 // Intro

        for (index, article) in articles.enumerated() {
            let text = (article.title ?? "") + " " + (article.aiSummary ?? article.articleDescription ?? "")
            let duration = estimateDuration(text: text)

            chapters.append(BriefingChapter(
                title: article.title ?? "Article \(index + 1)",
                startTime: currentTime,
                duration: duration,
                article: article
            ))

            currentTime += duration
        }

        return chapters
    }

    private func estimateDuration(text: String) -> TimeInterval {
        let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
        let wordsPerSecond = 2.5 // Average speaking rate
        return Double(words) / wordsPerSecond
    }
}

// MARK: - Models

struct AudioBriefing {
    let audio: Data
    let duration: TimeInterval
    let transcript: String
    let chapters: [BriefingChapter]
    let voice: VoiceProfile
    let generatedAt: Date
}

struct BriefingChapter {
    let title: String
    let startTime: TimeInterval
    let duration: TimeInterval
    let article: NewsArticle
}

struct VoiceProfile {
    let name: String
    let awsVoiceId: String
    let googleVoiceId: String
    let azureVoiceId: String
    let ibmVoiceId: String
    let description: String

    static let professional = VoiceProfile(
        name: "Professional",
        awsVoiceId: "Matthew",
        googleVoiceId: "en-US-Neural2-J",
        azureVoiceId: "en-US-JennyNeural",
        ibmVoiceId: "en-US_MichaelV3Voice",
        description: "Clear, authoritative male voice"
    )

    static let casual = VoiceProfile(
        name: "Casual",
        awsVoiceId: "Joanna",
        googleVoiceId: "en-US-Neural2-F",
        azureVoiceId: "en-US-AriaNeural",
        ibmVoiceId: "en-US_AllisonV3Voice",
        description: "Friendly, conversational female voice"
    )

    static let british = VoiceProfile(
        name: "British",
        awsVoiceId: "Brian",
        googleVoiceId: "en-GB-Neural2-B",
        azureVoiceId: "en-GB-RyanNeural",
        ibmVoiceId: "en-GB_KateV3Voice",
        description: "British accent, professional"
    )

    static let allProfiles: [VoiceProfile] = [.professional, .casual, .british]
}

// MARK: - Errors

enum AudioError: LocalizedError {
    case invalidConfiguration
    case synthesFailed
    case decodingFailed
    case notImplemented

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            return "Audio service not properly configured"
        case .synthesFailed:
            return "Failed to generate audio"
        case .decodingFailed:
            return "Failed to decode audio data"
        case .notImplemented:
            return "This audio provider is not yet implemented"
        }
    }
}

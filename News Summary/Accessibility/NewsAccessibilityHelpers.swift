//
//  NewsAccessibilityHelpers.swift
//  News Summary
//
//  Accessibility helpers for DynamicType, VoiceOver, and article reading
//  Ensures news is accessible to all users
//  Created by Jordan Koch on 2026-01-31.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

// MARK: - Scaled Font Extension

extension Font {
    /// Creates a font that scales with Dynamic Type for news reading
    static func newsFont(size: CGFloat, weight: Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    /// Predefined scaled fonts for News Summary
    static var newsTitle: Font { .system(.title, design: .serif, weight: .bold) }
    static var newsHeadline: Font { .system(.headline, design: .default, weight: .semibold) }
    static var newsBody: Font { .system(.body, design: .serif) }
    static var newsCaption: Font { .system(.caption, design: .default) }
}

// MARK: - Accessible Article Card

struct AccessibleArticleCard: View {
    let headline: String
    let source: String
    let category: String
    let publishedDate: Date
    let isBreaking: Bool
    let action: () -> Void

    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: spacing) {
                // Breaking badge
                if isBreaking {
                    Text("BREAKING")
                        .font(.system(size: badgeFontSize, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red)
                        .cornerRadius(4)
                        .accessibilityLabel("Breaking news")
                }

                // Headline
                Text(headline)
                    .font(.newsHeadline)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 3)
                    .multilineTextAlignment(.leading)

                // Metadata row
                HStack(spacing: 8) {
                    Text(source)
                        .font(.newsCaption)
                        .foregroundColor(.cyan)

                    Text("•")
                        .foregroundColor(.secondary)

                    Text(category)
                        .font(.newsCaption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(publishedDate, style: .relative)
                        .font(.newsCaption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(padding)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(cornerRadius)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Double tap to read full article")
        .accessibilityAddTraits(.isButton)
    }

    private var spacing: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 12 : 8
    }

    private var padding: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 20 : 16
    }

    private var cornerRadius: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 16 : 12
    }

    private var badgeFontSize: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 14 : 10
    }

    private var accessibilityLabel: String {
        var label = ""
        if isBreaking {
            label += "Breaking news. "
        }
        label += "\(headline). From \(source). Category: \(category)."
        return label
    }
}

// MARK: - Accessible Category Badge

struct AccessibleCategoryBadge: View {
    let name: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(name)
                    .font(.system(size: fontSize, weight: isSelected ? .bold : .regular))

                Text("\(count)")
                    .font(.system(size: fontSize - 2, weight: .bold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(isSelected ? Color.cyan.opacity(0.3) : Color.secondary.opacity(0.1))
            .cornerRadius(cornerRadius)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(name), \(count) articles")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var fontSize: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 18 : 14
    }

    private var horizontalPadding: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 16 : 12
    }

    private var verticalPadding: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 10 : 6
    }

    private var cornerRadius: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 12 : 8
    }
}

// MARK: - Article Reader Accessibility

struct ArticleReaderView: View {
    let title: String
    let content: String
    let source: String
    let author: String?
    let publishedDate: Date

    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @State private var fontSize: CGFloat = 17

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Title
                Text(title)
                    .font(.newsTitle)
                    .accessibilityAddTraits(.isHeader)

                // Metadata
                HStack {
                    Text(source)
                        .font(.newsCaption)
                        .foregroundColor(.cyan)

                    if let author = author {
                        Text("by \(author)")
                            .font(.newsCaption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Text(publishedDate, style: .date)
                        .font(.newsCaption)
                        .foregroundColor(.secondary)
                }

                Divider()

                // Content
                Text(content)
                    .font(.system(size: adjustedFontSize, design: .serif))
                    .lineSpacing(lineSpacing)
            }
            .padding()
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Menu {
                    Button(action: decreaseFontSize) {
                        Label("Smaller Text", systemImage: "textformat.size.smaller")
                    }
                    Button(action: increaseFontSize) {
                        Label("Larger Text", systemImage: "textformat.size.larger")
                    }
                    Button(action: resetFontSize) {
                        Label("Reset Text Size", systemImage: "arrow.counterclockwise")
                    }
                } label: {
                    Image(systemName: "textformat.size")
                }
                .accessibilityLabel("Text size options")
            }
        }
    }

    private var adjustedFontSize: CGFloat {
        fontSize * dynamicTypeSize.scaleFactor
    }

    private var lineSpacing: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 8 : 4
    }

    private func increaseFontSize() {
        fontSize = min(fontSize + 2, 32)
    }

    private func decreaseFontSize() {
        fontSize = max(fontSize - 2, 12)
    }

    private func resetFontSize() {
        fontSize = 17
    }
}

// MARK: - VoiceOver Article Reader

class ArticleVoiceOverReader {
    private var isSpeaking = false

    #if os(macOS)
    private var speechSynthesizer: NSSpeechSynthesizer?
    #endif

    init() {
        #if os(macOS)
        speechSynthesizer = NSSpeechSynthesizer()
        #endif
    }

    /// Reads article content aloud for VoiceOver users
    func readArticle(title: String, source: String, content: String) {
        let fullText = "\(title). From \(source). \(content)"

        #if os(macOS)
        guard let synthesizer = speechSynthesizer else { return }

        if isSpeaking {
            synthesizer.stopSpeaking()
            isSpeaking = false
        } else {
            synthesizer.startSpeaking(fullText)
            isSpeaking = true
        }
        #endif
    }

    /// Stops reading
    func stopReading() {
        #if os(macOS)
        speechSynthesizer?.stopSpeaking()
        isSpeaking = false
        #endif
    }

    var isCurrentlySpeaking: Bool {
        return isSpeaking
    }
}

// MARK: - Accessibility Preferences

@MainActor
class NewsAccessibilityPreferences: ObservableObject {
    static let shared = NewsAccessibilityPreferences()

    @Published var preferLargerText: Bool = false {
        didSet {
            UserDefaults.standard.set(preferLargerText, forKey: "preferLargerText")
        }
    }

    @Published var preferSerifFont: Bool = true {
        didSet {
            UserDefaults.standard.set(preferSerifFont, forKey: "preferSerifFont")
        }
    }

    @Published var showBreakingNewsFirst: Bool = true {
        didSet {
            UserDefaults.standard.set(showBreakingNewsFirst, forKey: "showBreakingNewsFirst")
        }
    }

    @Published var announceBreakingNews: Bool = true {
        didSet {
            UserDefaults.standard.set(announceBreakingNews, forKey: "announceBreakingNews")
        }
    }

    private init() {
        preferLargerText = UserDefaults.standard.bool(forKey: "preferLargerText")
        let serifPref = UserDefaults.standard.object(forKey: "preferSerifFont")
        preferSerifFont = serifPref == nil ? true : UserDefaults.standard.bool(forKey: "preferSerifFont")
        let breakingPref = UserDefaults.standard.object(forKey: "showBreakingNewsFirst")
        showBreakingNewsFirst = breakingPref == nil ? true : UserDefaults.standard.bool(forKey: "showBreakingNewsFirst")
        let announcePref = UserDefaults.standard.object(forKey: "announceBreakingNews")
        announceBreakingNews = announcePref == nil ? true : UserDefaults.standard.bool(forKey: "announceBreakingNews")
    }
}

// MARK: - Dynamic Type Size Extension

extension DynamicTypeSize {
    var isAccessibilitySize: Bool {
        switch self {
        case .accessibility1, .accessibility2, .accessibility3, .accessibility4, .accessibility5:
            return true
        default:
            return false
        }
    }

    var scaleFactor: CGFloat {
        switch self {
        case .xSmall: return 0.8
        case .small: return 0.9
        case .medium: return 1.0
        case .large: return 1.1
        case .xLarge: return 1.2
        case .xxLarge: return 1.3
        case .xxxLarge: return 1.4
        case .accessibility1: return 1.6
        case .accessibility2: return 1.8
        case .accessibility3: return 2.0
        case .accessibility4: return 2.2
        case .accessibility5: return 2.4
        @unknown default: return 1.0
        }
    }
}

// MARK: - Reduce Motion Support

struct NewsReduceMotionModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    func body(content: Content) -> some View {
        content
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: UUID())
    }
}

extension View {
    func newsAccessibleAnimation() -> some View {
        modifier(NewsReduceMotionModifier())
    }
}

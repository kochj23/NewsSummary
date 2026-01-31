import SwiftUI
import Observation

//
//  ThemeManager.swift
//  News Summary
//
//  Dark/Light mode management with custom themes
//  Author: Jordan Koch
//  Date: 2026-01-26
//  Updated: 2026-01-31 - Migrated to @Observable (Swift 5.9+)
//

/// Theme manager using the modern @Observable macro
///
/// **Migration from ObservableObject:**
/// - Replaced `ObservableObject` protocol with `@Observable` macro
/// - Removed `@Published` property wrappers (automatic observation)
/// - Views should use `@State` or direct reference instead of `@StateObject`
///
/// **Requirements:** macOS 14+, iOS 17+, tvOS 17+
@Observable
@MainActor
final class ThemeManager {

    static let shared = ThemeManager()

    var currentTheme: AppTheme = .system
    var accentColor: Color = .cyan

    private init() {
        loadTheme()
    }

    func setTheme(_ theme: AppTheme) {
        currentTheme = theme
        saveTheme()
        applyTheme()
    }

    func toggleTheme() {
        switch currentTheme {
        case .light:
            setTheme(.dark)
        case .dark:
            setTheme(.oledBlack)
        case .oledBlack:
            setTheme(.system)
        case .system:
            setTheme(.light)
        }
    }

    private func applyTheme() {
        switch currentTheme {
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        case .oledBlack:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        case .system:
            NSApp.appearance = nil
        }
    }

    private func loadTheme() {
        if let themeName = UserDefaults.standard.string(forKey: "AppTheme"),
           let theme = AppTheme(rawValue: themeName) {
            currentTheme = theme
        }

        if let colorData = UserDefaults.standard.data(forKey: "AccentColor"),
           let color = try? JSONDecoder().decode(CodableColor.self, from: colorData) {
            accentColor = color.color
        }

        applyTheme()
    }

    private func saveTheme() {
        UserDefaults.standard.set(currentTheme.rawValue, forKey: "AppTheme")

        if let colorData = try? JSONEncoder().encode(CodableColor(color: accentColor)) {
            UserDefaults.standard.set(colorData, forKey: "AccentColor")
        }
    }
}

// MARK: - App Theme

enum AppTheme: String, CaseIterable, Codable {
    case light = "Light"
    case dark = "Dark"
    case oledBlack = "OLED Black"
    case system = "System"

    var icon: String {
        switch self {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .oledBlack: return "moon.stars.fill"
        case .system: return "circle.lefthalf.filled"
        }
    }

    var description: String {
        switch self {
        case .light:
            return "Light mode - Best for bright environments"
        case .dark:
            return "Dark mode - Comfortable for low light"
        case .oledBlack:
            return "True black - Perfect for OLED displays"
        case .system:
            return "Match system appearance automatically"
        }
    }
}

// MARK: - Theme Colors

struct ThemeColors {

    static func background(for theme: AppTheme) -> Color {
        switch theme {
        case .light:
            return Color(nsColor: .windowBackgroundColor)
        case .dark:
            return Color(red: 0.11, green: 0.11, blue: 0.12)
        case .oledBlack:
            return .black
        case .system:
            return Color(nsColor: .windowBackgroundColor)
        }
    }

    static func cardBackground(for theme: AppTheme) -> Color {
        switch theme {
        case .light:
            return .white
        case .dark:
            return Color(red: 0.15, green: 0.15, blue: 0.16)
        case .oledBlack:
            return Color(red: 0.05, green: 0.05, blue: 0.05)
        case .system:
            return Color(nsColor: .controlBackgroundColor)
        }
    }

    static func text(for theme: AppTheme) -> Color {
        switch theme {
        case .light:
            return .black
        case .dark, .oledBlack:
            return .white
        case .system:
            return Color(nsColor: .textColor)
        }
    }

    static func secondaryText(for theme: AppTheme) -> Color {
        switch theme {
        case .light:
            return .gray
        case .dark, .oledBlack:
            return Color(white: 0.7)
        case .system:
            return Color(nsColor: .secondaryLabelColor)
        }
    }
}

// MARK: - Codable Color (for persistence)

struct CodableColor: Codable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    init(color: Color) {
        let nsColor = NSColor(color)
        self.red = Double(nsColor.redComponent)
        self.green = Double(nsColor.greenComponent)
        self.blue = Double(nsColor.blueComponent)
        self.alpha = Double(nsColor.alphaComponent)
    }

    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }
}

// MARK: - View Extensions

extension View {
    func themedBackground() -> some View {
        self.background(ThemeColors.background(for: ThemeManager.shared.currentTheme))
    }

    func themedCard() -> some View {
        self.background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ThemeColors.cardBackground(for: ThemeManager.shared.currentTheme))
        )
    }

    func themedText() -> some View {
        self.foregroundColor(ThemeColors.text(for: ThemeManager.shared.currentTheme))
    }

    func themedSecondaryText() -> some View {
        self.foregroundColor(ThemeColors.secondaryText(for: ThemeManager.shared.currentTheme))
    }
}

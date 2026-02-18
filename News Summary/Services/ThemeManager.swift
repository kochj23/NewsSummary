import SwiftUI
import Observation

//
//  ThemeManager.swift
//  News Summary
//
//  Theme management - enforces dark glassmorphic appearance
//  Matching TopGUI and RsyncGUI design language
//  Author: Jordan Koch
//  Date: 2026-01-26
//  Updated: 2026-02-17 - Switched to glassmorphic dark-only theme
//

/// Theme manager - enforces dark appearance for glassmorphic design
@Observable
@MainActor
final class ThemeManager {

    static let shared = ThemeManager()

    var accentColor: Color = ModernColors.cyan

    private init() {
        applyTheme()
    }

    func applyTheme() {
        // Force dark appearance for glassmorphic design
        NSApp.appearance = NSAppearance(named: .darkAqua)
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

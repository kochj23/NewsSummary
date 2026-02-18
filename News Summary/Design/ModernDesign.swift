//
//  ModernDesign.swift
//  News Summary
//
//  Glassmorphic design system matching TopGUI and RsyncGUI
//  Inspired by iOS design and modern dashboard aesthetics
//
//  Created by Jordan Koch on 2026-02-17.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

// MARK: - Color Palette

struct ModernColors {
    // Dark blue gradient background (CleanMyMac style)
    static let gradientStart = Color(red: 0.08, green: 0.12, blue: 0.22) // Dark navy
    static let gradientMid = Color(red: 0.10, green: 0.15, blue: 0.28)   // Navy blue
    static let gradientEnd = Color(red: 0.12, green: 0.18, blue: 0.32)   // Lighter navy

    // Vibrant accent colors
    static let cyan = Color(red: 0.3, green: 0.85, blue: 0.95)          // Bright cyan
    static let teal = Color(red: 0.2, green: 0.8, blue: 0.8)            // Teal
    static let purple = Color(red: 0.6, green: 0.4, blue: 0.95)         // Purple
    static let orange = Color(red: 1.0, green: 0.6, blue: 0.2)          // Warm orange
    static let yellow = Color(red: 1.0, green: 0.85, blue: 0.3)         // Bright yellow
    static let pink = Color(red: 1.0, green: 0.35, blue: 0.65)          // Hot pink
    static let accent = Color(red: 0.3, green: 0.85, blue: 0.95)        // Cyan (primary)
    static let accentBlue = Color(red: 0.3, green: 0.7, blue: 1.0)      // Blue
    static let accentGreen = Color(red: 0.3, green: 0.9, blue: 0.6)     // Green
    static let accentOrange = Color(red: 1.0, green: 0.6, blue: 0.2)    // Orange
    static let accentRed = Color(red: 1.0, green: 0.3, blue: 0.4)       // Red

    // Background blob colors (vibrant for dark background)
    static let blobCyan = Color(red: 0.2, green: 0.7, blue: 0.9)
    static let blobPurple = Color(red: 0.5, green: 0.3, blue: 0.8)
    static let blobPink = Color(red: 0.9, green: 0.3, blue: 0.6)
    static let blobOrange = Color(red: 0.9, green: 0.5, blue: 0.2)

    // Status colors
    static let statusLow = Color(red: 0.3, green: 0.9, blue: 0.6)       // Bright green
    static let statusMedium = Color(red: 1.0, green: 0.85, blue: 0.3)   // Yellow
    static let statusHigh = Color(red: 1.0, green: 0.6, blue: 0.2)      // Orange
    static let statusCritical = Color(red: 1.0, green: 0.3, blue: 0.4)  // Red

    // Text colors (light for dark background)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.7)
    static let textTertiary = Color.white.opacity(0.5)

    // Glass card colors
    static let glassBackground = Color.white.opacity(0.05)
    static let glassBorder = Color.white.opacity(0.15)

    // News-specific category color mapping
    static func categoryAccent(_ category: String) -> Color {
        switch category.lowercased() {
        case "us": return accentRed
        case "world": return accentBlue
        case "local": return accentGreen
        case "business": return accentOrange
        case "technology": return cyan
        case "entertainment": return pink
        case "sports": return purple
        case "science": return Color(red: 0.4, green: 0.4, blue: 0.95)
        case "health": return teal
        default: return accent
        }
    }

    // Credibility color
    static func credibilityColor(_ score: Int) -> Color {
        if score >= 90 { return statusLow }
        if score >= 75 { return statusMedium }
        if score >= 60 { return statusHigh }
        return statusCritical
    }

    // Background gradient
    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [gradientStart, gradientMid, gradientEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Glass Card Modifier

struct GlassCard: ViewModifier {
    let prominent: Bool

    func body(content: Content) -> some View {
        content
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(ModernColors.glassBackground)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(.ultraThinMaterial)
                            .opacity(0.9)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(ModernColors.glassBorder, lineWidth: 2)
                    )
                    .shadow(color: Color.black.opacity(0.05), radius: 10, y: 5)
                    .shadow(color: Color.white.opacity(0.8), radius: 1, x: -1, y: -1)
            )
    }
}

// Compact glass card for tighter layouts (article cards, tabs)
struct CompactGlassCard: ViewModifier {
    let cornerRadius: CGFloat
    let borderColor: Color

    init(cornerRadius: CGFloat = 16, borderColor: Color = ModernColors.glassBorder) {
        self.cornerRadius = cornerRadius
        self.borderColor = borderColor
    }

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(ModernColors.glassBackground)
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(.ultraThinMaterial)
                            .opacity(0.85)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(borderColor, lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.03), radius: 6, y: 3)
            )
    }
}

extension View {
    func glassCard(prominent: Bool = false) -> some View {
        modifier(GlassCard(prominent: prominent))
    }

    func compactGlassCard(cornerRadius: CGFloat = 16, borderColor: Color = ModernColors.glassBorder) -> some View {
        modifier(CompactGlassCard(cornerRadius: cornerRadius, borderColor: borderColor))
    }
}

// MARK: - Modern Button Style

struct ModernButtonStyle: ButtonStyle {
    let color: Color
    let style: ButtonStyleType

    enum ButtonStyleType {
        case filled
        case outlined
        case destructive
        case glass
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Group {
                    if style == .glass {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.3))
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.ultraThinMaterial)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.5), lineWidth: 1.5)
                            )
                    } else if style == .filled || style == .destructive {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(configuration.isPressed ? color.opacity(0.8) : color)
                    } else {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(color, lineWidth: 2)
                    }
                }
            )
            .foregroundColor(style == .outlined ? color : (style == .glass ? ModernColors.textPrimary : .white))
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .shadow(color: color.opacity(0.3), radius: configuration.isPressed ? 5 : 8)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Modern Header

struct ModernHeader: ViewModifier {
    let size: HeaderSize

    enum HeaderSize {
        case large, medium, small

        var fontSize: CGFloat {
            switch self {
            case .large: return 32
            case .medium: return 22
            case .small: return 18
            }
        }
    }

    func body(content: Content) -> some View {
        content
            .font(.system(size: size.fontSize, weight: .bold, design: .rounded))
            .foregroundColor(ModernColors.textPrimary)
    }
}

extension View {
    func modernHeader(size: ModernHeader.HeaderSize = .large) -> some View {
        modifier(ModernHeader(size: size))
    }
}

// MARK: - Floating Blob

struct FloatingBlob: View {
    let color: Color
    let size: CGFloat
    let x: CGFloat
    let y: CGFloat
    let animation: Animation

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [color, color.opacity(0.6)],
                    center: .center,
                    startRadius: 0,
                    endRadius: size / 2
                )
            )
            .frame(width: size, height: size)
            .blur(radius: 50)
            .offset(x: x, y: y)
    }
}

// MARK: - Glassmorphic Background

struct GlassmorphicBackground: View {
    @State private var animateBlobs = false

    var body: some View {
        ZStack {
            // Base gradient
            ModernColors.backgroundGradient
                .ignoresSafeArea()

            // Large floating blobs
            FloatingBlob(
                color: ModernColors.blobCyan,
                size: 400,
                x: animateBlobs ? -100 : -150,
                y: animateBlobs ? -200 : -250,
                animation: .easeInOut(duration: 8).repeatForever(autoreverses: true)
            )

            FloatingBlob(
                color: ModernColors.blobPurple,
                size: 350,
                x: animateBlobs ? 150 : 100,
                y: animateBlobs ? -150 : -100,
                animation: .easeInOut(duration: 7).repeatForever(autoreverses: true)
            )

            FloatingBlob(
                color: ModernColors.blobPink,
                size: 450,
                x: animateBlobs ? 100 : 150,
                y: animateBlobs ? 300 : 350,
                animation: .easeInOut(duration: 9).repeatForever(autoreverses: true)
            )

            FloatingBlob(
                color: ModernColors.blobOrange,
                size: 300,
                x: animateBlobs ? -200 : -150,
                y: animateBlobs ? 250 : 300,
                animation: .easeInOut(duration: 10).repeatForever(autoreverses: true)
            )

            FloatingBlob(
                color: ModernColors.blobCyan.opacity(0.7),
                size: 250,
                x: animateBlobs ? 200 : 250,
                y: animateBlobs ? 100 : 50,
                animation: .easeInOut(duration: 6).repeatForever(autoreverses: true)
            )
        }
        .onAppear {
            withAnimation {
                animateBlobs = true
            }
        }
    }
}

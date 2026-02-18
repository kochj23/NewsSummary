//
//  BiasIndicatorView.swift
//  News Summary
//
//  Compact bias indicator badge (L/C/R) with glassmorphic styling
//  Created by Jordan Koch on 2026-01-23
//  Updated: 2026-02-17 - Glassmorphic design system
//

import SwiftUI

struct BiasIndicatorView: View {
    let bias: BiasSpectrum

    var body: some View {
        Text(bias.shortLabel)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .frame(width: 24, height: 24)
            .background(
                Circle()
                    .fill(bias.color)
                    .shadow(color: bias.color.opacity(0.4), radius: 3)
            )
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
    }
}

#Preview {
    HStack(spacing: 8) {
        BiasIndicatorView(bias: .farLeft)
        BiasIndicatorView(bias: .left)
        BiasIndicatorView(bias: .centerLeft)
        BiasIndicatorView(bias: .center)
        BiasIndicatorView(bias: .centerRight)
        BiasIndicatorView(bias: .right)
        BiasIndicatorView(bias: .farRight)
    }
    .padding()
    .background(ModernColors.backgroundGradient)
}

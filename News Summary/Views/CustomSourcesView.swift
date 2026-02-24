//
//  CustomSourcesView.swift
//  News Summary
//
//  Management UI for user-configurable RSS sources
//  Add, edit, validate, and remove custom news feeds with bias assignment
//  Created by Jordan Koch on 2026-02-24
//

import SwiftUI

struct CustomSourcesView: View {
    @ObservedObject private var sourceManager = CustomSourceManager.shared
    @State private var showAddForm = false
    @State private var editingSource: CustomNewsSource?
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            GlassmorphicBackground()

            VStack(spacing: 0) {
                headerView

                Rectangle()
                    .fill(ModernColors.glassBorder)
                    .frame(height: 1)

                if sourceManager.customSources.isEmpty {
                    emptyStateView
                } else {
                    sourceListView
                }
            }
        }
        .frame(width: 700, height: 550)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(ModernColors.cyan.opacity(0.3), lineWidth: 2)
        )
        .shadow(color: ModernColors.cyan.opacity(0.15), radius: 20)
        .sheet(isPresented: $showAddForm) {
            AddCustomSourceSheet(editingSource: nil)
        }
        .sheet(item: $editingSource) { source in
            AddCustomSourceSheet(editingSource: source)
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("CUSTOM RSS SOURCES")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(ModernColors.cyan)

                Text("\(sourceManager.customSources.count) sources configured")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(ModernColors.textTertiary)
            }

            Spacer()

            Button(action: { showAddForm = true }) {
                Label("Add Source", systemImage: "plus.circle.fill")
            }
            .buttonStyle(ModernButtonStyle(color: ModernColors.cyan, style: .filled))

            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(ModernColors.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 48))
                .foregroundColor(ModernColors.cyan.opacity(0.5))

            Text("No Custom Sources")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(ModernColors.textPrimary)

            Text("Add your own RSS feeds to get news from\nsources not included in the default list.")
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(ModernColors.textSecondary)
                .multilineTextAlignment(.center)

            Button(action: { showAddForm = true }) {
                Label("Add Your First Source", systemImage: "plus.circle.fill")
            }
            .buttonStyle(ModernButtonStyle(color: ModernColors.cyan, style: .filled))

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Source List

    private var sourceListView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(sourceManager.customSources) { source in
                    CustomSourceRow(
                        source: source,
                        onToggle: { sourceManager.toggleEnabled(source) },
                        onEdit: { editingSource = source },
                        onDelete: { sourceManager.removeSource(source) }
                    )
                }
            }
            .padding()
        }
    }
}

// MARK: - Source Row

struct CustomSourceRow: View {
    let source: CustomNewsSource
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Bias indicator
            BiasIndicatorView(bias: source.bias)

            // Source info
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(source.name)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(source.isEnabled ? ModernColors.textPrimary : ModernColors.textTertiary)
                        .lineLimit(1)

                    if !source.isEnabled {
                        Text("DISABLED")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(ModernColors.textTertiary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(ModernColors.glassBackground)
                            .cornerRadius(4)
                    }
                }

                HStack(spacing: 8) {
                    // Category
                    HStack(spacing: 3) {
                        Image(systemName: source.category.icon)
                            .font(.system(size: 10))
                        Text(source.category.displayName)
                            .font(.system(size: 11, design: .rounded))
                    }
                    .foregroundColor(source.category.color)

                    // Credibility
                    Text("\(source.credibility)%")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(ModernColors.credibilityColor(source.credibility))

                    // Article count
                    if source.articleCount > 0 {
                        Text("\(source.articleCount) articles")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(ModernColors.textTertiary)
                    }

                    // Last fetched
                    if let lastFetched = source.lastFetched {
                        Text(lastFetched, style: .relative)
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(ModernColors.textTertiary)
                    }
                }
            }

            Spacer()

            // Toggle
            Toggle("", isOn: Binding(
                get: { source.isEnabled },
                set: { _ in onToggle() }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            .controlSize(.small)

            // Edit
            Button(action: onEdit) {
                Image(systemName: "pencil.circle")
                    .font(.system(size: 18))
                    .foregroundColor(ModernColors.cyan)
            }
            .buttonStyle(.plain)

            // Delete
            Button(action: onDelete) {
                Image(systemName: "trash.circle")
                    .font(.system(size: 18))
                    .foregroundColor(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .compactGlassCard(
            cornerRadius: 12,
            borderColor: source.isEnabled ? source.category.color.opacity(0.2) : ModernColors.glassBorder
        )
        .opacity(source.isEnabled ? 1.0 : 0.6)
    }
}

// MARK: - Add/Edit Source Sheet

struct AddCustomSourceSheet: View {
    let editingSource: CustomNewsSource?
    @ObservedObject private var sourceManager = CustomSourceManager.shared
    @Environment(\.dismiss) var dismiss

    @State private var name: String = ""
    @State private var urlString: String = ""
    @State private var category: NewsCategory = .us
    @State private var bias: BiasSpectrum = .center
    @State private var credibility: Double = 70
    @State private var factuality: Double = 0.75

    @State private var isValidating = false
    @State private var validationResult: ValidationResult?

    enum ValidationResult {
        case success(Int)
        case failure(String)
    }

    var isEditing: Bool { editingSource != nil }

    var body: some View {
        ZStack {
            GlassmorphicBackground()

            VStack(spacing: 0) {
                formHeader
                Rectangle().fill(ModernColors.glassBorder).frame(height: 1)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        nameField
                        urlField
                        categoryPicker
                        biasPicker
                        credibilitySlider
                        factualitySlider
                        validationStatus
                    }
                    .padding()
                }

                Rectangle().fill(ModernColors.glassBorder).frame(height: 1)
                formActions
            }
        }
        .frame(width: 600, height: 520)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(ModernColors.cyan.opacity(0.3), lineWidth: 2)
        )
        .onAppear { populateFromEditing() }
    }

    // MARK: - Form Header

    private var formHeader: some View {
        HStack {
            Text(isEditing ? "EDIT SOURCE" : "ADD CUSTOM SOURCE")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(ModernColors.cyan)

            Spacer()

            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(ModernColors.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }

    // MARK: - Form Fields

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Source Name")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(ModernColors.textSecondary)

            TextField("e.g. The Guardian", text: $name)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 14, design: .rounded))
        }
    }

    private var urlField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("RSS Feed URL")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(ModernColors.textSecondary)

            HStack {
                TextField("https://example.com/rss/feed.xml", text: $urlString)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 14, design: .monospaced))

                Button(action: testFeed) {
                    if isValidating {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Test", systemImage: "antenna.radiowaves.left.and.right")
                    }
                }
                .buttonStyle(ModernButtonStyle(color: ModernColors.teal, style: .outlined))
                .disabled(urlString.isEmpty || isValidating)
            }
        }
    }

    private var categoryPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Category")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(ModernColors.textSecondary)

            Picker("Category", selection: $category) {
                ForEach(NewsCategory.allCases, id: \.self) { cat in
                    HStack {
                        Image(systemName: cat.icon)
                        Text(cat.displayName)
                    }
                    .tag(cat)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var biasPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Political Bias")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(ModernColors.textSecondary)

            HStack(spacing: 6) {
                ForEach(BiasSpectrum.allCases, id: \.self) { b in
                    Button(action: { bias = b }) {
                        VStack(spacing: 3) {
                            Circle()
                                .fill(b.color)
                                .frame(width: bias == b ? 28 : 22, height: bias == b ? 28 : 22)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: bias == b ? 2 : 0)
                                )
                                .shadow(color: bias == b ? b.color.opacity(0.6) : .clear, radius: 4)

                            Text(b.shortLabel)
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundColor(bias == b ? ModernColors.textPrimary : ModernColors.textTertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .compactGlassCard(cornerRadius: 12, borderColor: bias.color.opacity(0.3))
        }
    }

    private var credibilitySlider: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Credibility")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(ModernColors.textSecondary)

                Spacer()

                Text("\(Int(credibility))%")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(ModernColors.credibilityColor(Int(credibility)))
            }

            Slider(value: $credibility, in: 0...100, step: 5)
                .tint(ModernColors.credibilityColor(Int(credibility)))
        }
    }

    private var factualitySlider: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Factuality")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(ModernColors.textSecondary)

                Spacer()

                Text(String(format: "%.0f%%", factuality * 100))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(ModernColors.credibilityColor(Int(factuality * 100)))
            }

            Slider(value: $factuality, in: 0...1, step: 0.05)
                .tint(ModernColors.credibilityColor(Int(factuality * 100)))
        }
    }

    private var validationStatus: some View {
        Group {
            if let result = validationResult {
                HStack(spacing: 8) {
                    switch result {
                    case .success(let count):
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(ModernColors.accentGreen)
                        Text("Feed validated — \(count) articles found")
                            .foregroundColor(ModernColors.accentGreen)
                    case .failure(let message):
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(message)
                            .foregroundColor(.red)
                    }
                }
                .font(.system(size: 13, design: .rounded))
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Actions

    private var formActions: some View {
        HStack {
            Button("Cancel") { dismiss() }
                .buttonStyle(ModernButtonStyle(color: ModernColors.textSecondary, style: .glass))

            Spacer()

            Button(action: saveSource) {
                Label(isEditing ? "Save Changes" : "Add Source", systemImage: isEditing ? "checkmark.circle" : "plus.circle")
            }
            .buttonStyle(ModernButtonStyle(color: ModernColors.cyan, style: .filled))
            .disabled(name.isEmpty || urlString.isEmpty)
        }
        .padding()
    }

    // MARK: - Logic

    private func populateFromEditing() {
        guard let source = editingSource else { return }
        name = source.name
        urlString = source.rssURL.absoluteString
        category = source.category
        bias = source.bias
        credibility = Double(source.credibility)
        factuality = source.factuality
    }

    private func testFeed() {
        guard let url = URL(string: urlString) else {
            validationResult = .failure("Invalid URL format")
            return
        }

        isValidating = true
        validationResult = nil

        Task {
            let result = await sourceManager.validateFeed(url: url)
            isValidating = false
            if result.success {
                validationResult = .success(result.articleCount)
            } else {
                validationResult = .failure("No articles found. Check the URL is a valid RSS feed.")
            }
        }
    }

    private func saveSource() {
        guard let url = URL(string: urlString) else { return }

        if let existing = editingSource {
            var updated = existing
            updated.name = name
            updated.rssURL = url
            updated.category = category
            updated.bias = bias
            updated.credibility = Int(credibility)
            updated.factuality = factuality
            sourceManager.updateSource(updated)
        } else {
            // Check for duplicates
            if sourceManager.isDuplicateURL(url) {
                validationResult = .failure("This feed URL is already registered.")
                return
            }

            sourceManager.addSource(
                name: name,
                rssURL: url,
                category: category,
                bias: bias,
                credibility: Int(credibility),
                factuality: factuality
            )
        }

        dismiss()
    }
}

import SwiftUI
import AppKit

//
//  KeyboardShortcutManager.swift
//  News Summary
//
//  Keyboard shortcut handling for power users
//  Author: Jordan Koch
//  Date: 2026-01-26
//

struct KeyboardShortcuts {

    // MARK: - Commands

    static let search = KeyEquivalent("k")
    static let bookmark = KeyEquivalent("b")
    static let newCollection = KeyEquivalent("n")
    static let refresh = KeyEquivalent("r")
    static let export = KeyEquivalent("e")
    static let toggleTheme = KeyEquivalent("t")
    static let nextArticle = KeyEquivalent("]")
    static let previousArticle = KeyEquivalent("[")
    static let focusMode = KeyEquivalent("f")
    static let compareView = KeyEquivalent("c")

    // MARK: - Modifiers

    static let command: EventModifiers = .command
    static let commandShift: EventModifiers = [.command, .shift]
    static let commandOption: EventModifiers = [.command, .option]
}

// MARK: - Keyboard Shortcut View Modifier

struct KeyboardShortcutView<Content: View>: View {
    let content: Content
    @Binding var showSearch: Bool
    @Binding var showBookmark: Bool
    let onRefresh: () -> Void
    let onExport: () -> Void
    let onToggleTheme: () -> Void

    init(
        showSearch: Binding<Bool>,
        showBookmark: Binding<Bool>,
        onRefresh: @escaping () -> Void,
        onExport: @escaping () -> Void,
        onToggleTheme: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self._showSearch = showSearch
        self._showBookmark = showBookmark
        self.onRefresh = onRefresh
        self.onExport = onExport
        self.onToggleTheme = onToggleTheme
        self.content = content()
    }

    var body: some View {
        content
            .background(KeyboardHandler(
                showSearch: $showSearch,
                showBookmark: $showBookmark,
                onRefresh: onRefresh,
                onExport: onExport,
                onToggleTheme: onToggleTheme
            ))
    }
}

// MARK: - Keyboard Handler

struct KeyboardHandler: NSViewRepresentable {
    @Binding var showSearch: Bool
    @Binding var showBookmark: Bool
    let onRefresh: () -> Void
    let onExport: () -> Void
    let onToggleTheme: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = KeyboardHandlerView()
        view.showSearch = $showSearch
        view.showBookmark = $showBookmark
        view.onRefresh = onRefresh
        view.onExport = onExport
        view.onToggleTheme = onToggleTheme

        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

class KeyboardHandlerView: NSView {
    var showSearch: Binding<Bool>?
    var showBookmark: Binding<Bool>?
    var onRefresh: (() -> Void)?
    var onExport: (() -> Void)?
    var onToggleTheme: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags

        // Command key combinations
        if flags.contains(.command) {
            switch event.charactersIgnoringModifiers {
            case "k":
                showSearch?.wrappedValue = true
                return
            case "b":
                showBookmark?.wrappedValue = true
                return
            case "r":
                onRefresh?()
                return
            case "e":
                onExport?()
                return
            case "t":
                onToggleTheme?()
                return
            default:
                break
            }
        }

        // Command+Shift combinations
        if flags.contains(.command) && flags.contains(.shift) {
            switch event.charactersIgnoringModifiers {
            case "f":
                // Focus mode
                NotificationCenter.default.post(name: .toggleFocusMode, object: nil)
                return
            case "c":
                // Compare view
                NotificationCenter.default.post(name: .openCompareView, object: nil)
                return
            default:
                break
            }
        }

        super.keyDown(with: event)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let toggleFocusMode = Notification.Name("toggleFocusMode")
    static let openCompareView = Notification.Name("openCompareView")
}

// MARK: - SwiftUI Extensions

extension View {
    func keyboardShortcuts(
        showSearch: Binding<Bool>,
        showBookmark: Binding<Bool>,
        onRefresh: @escaping () -> Void,
        onExport: @escaping () -> Void,
        onToggleTheme: @escaping () -> Void
    ) -> some View {
        KeyboardShortcutView(
            showSearch: showSearch,
            showBookmark: showBookmark,
            onRefresh: onRefresh,
            onExport: onExport,
            onToggleTheme: onToggleTheme
        ) {
            self
        }
    }
}

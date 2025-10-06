# CodexTUI

CodexTUI is a Swift package for building composable terminal user interfaces (TUIs) that feel modern while still embracing the expressiveness of classic ANSI terminals. It layers ergonomic UI primitives on top of reliable input/output streams, letting you quickly assemble menus, status bars, overlays, and scrollable text panes that react to keyboard events in real time.

## Why CodexTUI?

Designing fluid TUIs in Swift traditionally requires juggling terminal control sequences, low-level input handling, and complex layout math. CodexTUI consolidates those responsibilities into clear abstractions:

- **Declarative components** such as `Box`, `List`, `Button`, and `Text` form the foundation for larger experiences.
- **Menu and status bars** deliver application chrome with keyboard-activated menu items and dynamic status indicators.
- **Modal overlays** (message boxes, dropdown menus, selection lists, and text entry prompts) capture user intent without leaking keystrokes to the rest of the interface.
- **Scrollable text buffers** make it simple to connect terminal streams or logs to interactive panes.
- **Smart drawing logic** minimizes flicker by only redrawing what has actually changed, even when the terminal is resized.

Together these features offer an ergonomic path to shipping full applications or enhancing existing command-line tools with richer interactivity.

## Package Layout

```
Sources/
├── CodexTUI/        // Core UI primitives, layout helpers, and rendering logic
├── TerminalInput/   // Abstractions around keyboard input, key chords, and focus management
└── TerminalOutput/  // Terminal drawing helpers, color/state tracking, and diffing
Tests/
└── CodexTUITests/   // Unit and integration coverage for layout, rendering, and input handling
```

Each component is designed to be small and composable so the framework resembles a fluent DSL while remaining easy to extend.

## Installation

Add CodexTUI to your project via Swift Package Manager by editing your `Package.swift`:

```swift
// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "YourApp",
    platforms: [
        .macOS(.v11)
    ],
    dependencies: [
        .package(url: "https://github.com/your-org/CodexTUI.git", branch: "main")
    ],
    targets: [
        .target(
            name: "YourApp",
            dependencies: [
                .product(name: "CodexTUI", package: "CodexTUI")
            ]
        )
    ]
)
```

Then import the framework where you build your TUI:

```swift
import CodexTUI
```

## Key Concepts

- **Layout primitives** define rectangular regions and handle bounds computation, enabling alignment, padding, and flexible sizing without manually tracking coordinates.
- **Event routing** centralizes keyboard processing so that modal overlays, focused controls, and background panes receive the right events at the right time.
- **Rendering pipeline** collects draw commands, diffs them against the previous frame, and sends only the necessary updates to the terminal, ensuring smooth UI refreshes.
- **Resize awareness** listens for `SIGWINCH` events and recalculates layout before scheduling a redraw.

Understanding these pillars will help you diagnose layout issues, extend widgets, and integrate CodexTUI with other terminal data sources.

## Quick Start Demo

The following minimal example shows how to wire up a main screen with a menu bar, status bar, and scrollable log window. It also demonstrates how to open a modal message box via a keyboard shortcut.

```swift
import CodexTUI
import Foundation

final class DemoController {
    private let app: Application
    private let logBuffer = ScrollBuffer()

    init() {
        app = Application(
            menuBar: MenuBar(items: [
                MenuItem(key: "F", title: "File", alignment: .leading) {
                    MessageBox(
                        title: "File",
                        message: ["New", "Open", "Save"],
                        buttons: ["Close"]
                    )
                }
            ]),
            statusBar: StatusBar(items: [
                StatusItem(text: "Press Ctrl+Q to quit", alignment: .leading),
                StatusItem(text: DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short), alignment: .trailing)
            ]),
            content: SplitView(
                orientation: .vertical,
                leading: TextView(title: "Activity", buffer: logBuffer),
                trailing: TextView(title: "Details", buffer: ScrollBuffer())
            )
        )

        app.bind(key: .control("q")) { [weak self] in self?.app.stop() }
        app.bind(key: .function(2)) { [weak self] in self?.showInfoBox() }
    }

    func run() {
        logBuffer.append("CodexTUI demo started")
        app.run()
    }

    private func showInfoBox() {
        app.present(
            MessageBox(
                title: "CodexTUI",
                message: ["Build expressive TUIs in Swift."],
                buttons: ["OK"]
            )
        )
    }
}

DemoController().run()
```

This sample demonstrates:

- Declaring menu and status bars with alignment-aware items.
- Connecting keyboard accelerators to application actions.
- Displaying modal overlays that capture input focus.
- Streaming text into scrollable buffers for live output.

## Documentation & Further Reading

- Explore the [`Sources/CodexTUI`](Sources/CodexTUI) directory for the full set of widgets and layout primitives.
- Check [`Tests/CodexTUITests`](Tests/CodexTUITests) for usage patterns and reference assertions when extending functionality.
- Review [`STYLERULES.md`](STYLERULES.md) to align with the project's code style when contributing.
- Browse the open issues and discussions to learn about ongoing development priorities and architectural decisions.

## Contributing

Contributions are welcome! Please open issues for bugs or feature requests, fork the repository, and submit pull requests. Remember to run the test suite and follow the style rules outlined above.

## License

CodexTUI is released under the MIT License. See [LICENSE](LICENSE) for details.

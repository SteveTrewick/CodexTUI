# CodexTUI

CodexTUI is a Swift package for building composable terminal user interfaces (TUIs) that feel modern while still embracing the expressiveness of classic ANSI terminals. It layers ergonomic UI primitives on top of reliable input/output streams, letting you quickly assemble menus, status bars, overlays, and scrollable text panes that react to keyboard events in real time.

# AI Notice - added by repo owner
This is an experimental package under development with GPT Codex, it probbaly doesn't work yet and AFAICT some of this README (which it wrote) is wrong

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

The following minimal example shows how to compose a scene with a menu bar, status bar, and scrolling text buffer using the core CodexTUI types. It also demonstrates how to drive the terminal directly via `TerminalDriver`.

```swift
import CodexTUI
import Dispatch
import Foundation
import TerminalInput

final class DemoApplication {
  private let driver    : TerminalDriver
  private let logBuffer : TextBuffer
  private let waitGroup : DispatchSemaphore

  private static let timestampFormatter : DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
  }()

  init () {
    let theme = Theme.codex

    logBuffer = TextBuffer(
      identifier    : FocusIdentifier("log"),
      lines         : [
        "CodexTUI quick start",
        "Press any key to log it.",
        "Press ESC to exit."
      ],
      style         : theme.contentDefault,
      highlightStyle: theme.highlight,
      isInteractive : true
    )

    waitGroup = DispatchSemaphore(value: 0)

    let menuBar = MenuBar(
      items            : [
        MenuItem(title: "File", activationKey: MenuActivationKey(character: "f"), alignment: .leading, isHighlighted: true),
        MenuItem(title: "Help", activationKey: MenuActivationKey(character: "h"), alignment: .trailing)
      ],
      style            : theme.menuBar,
      highlightStyle   : theme.highlight,
      dimHighlightStyle: theme.dimHighlight
    )

    let statusBar = StatusBar(
      items: [
        StatusItem(text: "ESC closes the demo"),
        StatusItem(text: DemoApplication.timestamp(), alignment: .trailing)
      ],
      style: theme.statusBar
    )

    let focusChain = FocusChain()
    focusChain.register(node: logBuffer.focusNode())

    let configuration = SceneConfiguration(
      theme       : theme,
      environment : EnvironmentValues(contentInsets: EdgeInsets(top: 1, leading: 2, bottom: 1, trailing: 2))
    )

    let scene = Scene.standard(
      menuBar     : menuBar,
      content     : AnyWidget(logBuffer),
      statusBar   : statusBar,
      configuration: configuration,
      focusChain  : focusChain
    )

    driver = CodexTUI.makeDriver(scene: scene)

    driver.onKeyEvent = { [weak self] token in
      self?.handle(token: token)
    }
  }

  func run () {
    driver.start()
    waitGroup.wait()
  }

  private func handle ( token: TerminalInput.Token ) {
    switch token {
      case .escape                  :
        driver.stop()
        waitGroup.signal()

      case .text(let string)                   :
        guard string.count == 1, let character = string.first else { return }
        logBuffer.append(line: "Key pressed: \(character)")
        driver.redraw()

      default                       :
        break
    }
  }

  private static func timestamp () -> String {
    return timestampFormatter.string(from: Date())
  }
}

DemoApplication().run()
```

This sample demonstrates:

- Instantiating `MenuBar` and `StatusBar` with the active theme's colour pairs.
- Registering a focusable `TextBuffer` and embedding it inside a standard `Scene`.
- Bootstrapping a `TerminalDriver` using `CodexTUI.makeDriver(scene:)`.
- Responding to keyboard events manually, including triggering redraws and graceful shutdown.
- Keeping the process alive with a `DispatchSemaphore` until the user exits.

## Building and Running CodexTUIDemo

The repository ships with an executable target, `CodexTUIDemo`, that assembles the widgets above into a fully working sample app. You can build and run it directly from the command line:

1. Build the executable (use `-c release` for an optimized binary):

   ```sh
   swift build --product CodexTUIDemo
   # or
   swift build -c release --product CodexTUIDemo
   ```

2. Launch the demo in a terminal that supports raw keyboard input and ANSI colours:

   ```sh
   swift run CodexTUIDemo
   # or run the release binary
   .build/release/CodexTUIDemo
   ```

3. Interact with the interface:
   - Press any key to append log entries to the scroll buffer.
   - Use the highlighted accelerator keys to activate menu items.
   - Press `ESC` to exit cleanly.

Running inside a full-featured terminal (Terminal.app, iTerm2, or a modern Linux terminal emulator) ensures the demo can switch the terminal into raw mode, display colours, and respond to window-resize events properly.

## Documentation & Further Reading

- Explore the [`Sources/CodexTUI`](Sources/CodexTUI) directory for the full set of widgets and layout primitives.
- Check [`Tests/CodexTUITests`](Tests/CodexTUITests) for usage patterns and reference assertions when extending functionality.
- Review [`STYLERULES.md`](STYLERULES.md) to align with the project's code style when contributing.
- Browse the open issues and discussions to learn about ongoing development priorities and architectural decisions.

## Contributing

Contributions are welcome! Please open issues for bugs or feature requests, fork the repository, and submit pull requests. Remember to run the test suite and follow the style rules outlined above.

## License

CodexTUI is released under the MIT License. See [LICENSE](LICENSE) for details.

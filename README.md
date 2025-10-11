# CodexTUI

CodexTUI is a Swift package for building composable terminal user interfaces (TUIs) that feel modern while still embracing the expressiveness of classic ANSI terminals. It layers ergonomic UI primitives on top of reliable input/output streams, letting you quickly assemble menus, status bars, overlays, and scrollable text panes that react to keyboard events in real time.

# AI Notice - added by repo owner
This is an experimental package under development with GPT Codex, it probbaly doesn't work yet and AFAICT some of this README (which it wrote) is wrong

## Why CodexTUI?

Designing fluid TUIs in Swift traditionally requires juggling terminal control sequences, low-level input handling, and complex layout math. CodexTUI consolidates those responsibilities into clear abstractions:

- **Declarative components** such as `MenuBar`, `SelectionList`, `StatusBar`, `Text`, `Box`, and `Overlay` form the foundation for larger experiences.
- **Menu and status bars** deliver application chrome with keyboard-activated menu items and dynamic status indicators.
- **Modal overlays** (message boxes, dropdown menus, selection lists, and text entry prompts) capture user intent without leaking keystrokes to the rest of the interface.
- **Scrollable text buffers** make it simple to connect terminal streams or logs to interactive panes.
- **Text IO channels** bridge focused text buffers to serial ports, pseudo terminals, or other UTF-8
  streams while preserving CodexTUI's redraw discipline.
- **Smart drawing logic** minimizes flicker by only redrawing what has actually changed, even when the terminal is resized.

Together these features offer an ergonomic path to shipping full applications or enhancing existing command-line tools with richer interactivity.

## Package Layout

```
Sources/
├── CodexTUI/        // Core UI primitives, layout helpers, and rendering logic
└── CodexTUIDemo/    // Executable target showcasing CodexTUI features end-to-end
Tests/
└── CodexTUITests/   // Unit and integration coverage for layout, rendering, and input handling
```

`TerminalInput` and `TerminalOutput` are integrated via Swift Package Manager dependencies as declared in `Package.swift`.

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

The following example wires together the core CodexTUI widgets, attaches a `TextBuffer` to a `TextIOChannel`, and lets the `TextIOController` route keyboard text into the simulated channel. This mirrors the behaviour of the `CodexTUIDemo` target.

```swift
import CodexTUI
import Foundation
import Dispatch
import TerminalInput

final class DemoApplication {
  private let driver           : TerminalDriver
  private let logBuffer        : TextBuffer
  private let textIOController : TextIOController
  private let logChannel       : FileHandleTextIOChannel
  private let channelWriter    : FileHandle
  private let channelQueue     : DispatchQueue

  init () {
    let theme = Theme.codex

    logBuffer = TextBuffer(
      identifier    : FocusIdentifier("log"),
      lines         : [
        "CodexTUI quick start",
        "Press ESC to exit.",
        "Type to echo through the channel."
      ],
      style         : theme.contentDefault,
      highlightStyle: theme.highlight,
      isInteractive : true
    )

    let pipe = Pipe()
    channelWriter = pipe.fileHandleForWriting
    logChannel    = FileHandleTextIOChannel(
      readHandle : pipe.fileHandleForReading,
      writeHandle: pipe.fileHandleForWriting
    )
    logBuffer.attach(channel: logChannel)
    channelQueue = DispatchQueue(label: "Demo.Channel")

    let focusChain = FocusChain()
    focusChain.register(node: logBuffer.focusNode())

    let scene = Scene.standard(
      content    : AnyWidget(logBuffer),
      configuration: SceneConfiguration(theme: theme),
      focusChain : focusChain
    )

    textIOController = TextIOController(scene: scene, buffers: [logBuffer])

    driver = CodexTUI.makeDriver(scene: scene)
    driver.textIOController = textIOController

    driver.onKeyEvent = { [weak self] token in
      self?.handle(token: token)
    }
  }

  func run () {
    logChannel.start()
    seedDemoChannel()

    driver.start()

    let runLoop = RunLoop.current

    while driver.state != .stopped {
      _ = runLoop.run(mode: .default, before: Date(timeIntervalSinceNow: 0.1))
    }

    logChannel.stop()
  }

  private func handle ( token: TerminalInput.Token ) {
    if case .escape = token {
      driver.stop()
    }
  }

  private func seedDemoChannel () {
    let messages = [
      "Connecting to simulated device...",
      "Connection established.",
      "Try typing to see echoed text."
    ]

    for (index, message) in messages.enumerated() {
      channelQueue.asyncAfter(deadline: .now() + .milliseconds(350 * index)) { [weak self] in
        self?.writeToChannel("\(message)\n")
      }
    }
  }

  private func writeToChannel ( _ text: String ) {
    guard let data = text.data(using: .utf8) else { return }
    channelWriter.write(data)
  }
}

DemoApplication().run()
```

This sample demonstrates:

- Attaching a `TextBuffer` to a `TextIOChannel` via `attach(channel:)` so it streams decoded UTF-8
  fragments.
- Registering the buffer with `TextIOController`, then assigning the controller to
  `TerminalDriver.textIOController` so keyboard text reaches the active channel.
- Seeding the channel with background messages while allowing user input to echo through the same
  file handle.
- Keeping the process alive by pumping the current `RunLoop` until the driver reports `.stopped`.

## Binding Text Buffers to Live Text IO

1. Create or obtain an object that conforms to `TextIOChannel`.
2. Call `attach(channel:lineSeparator:)` on the `TextBuffer` you want to stream into. The buffer will
   append fragments and request redraws whenever data arrives.
3. Register the buffer with a `TextIOController` and assign the controller to
   `TerminalDriver.textIOController`. When the buffer has focus, `.text` tokens are forwarded to the
   channel.
4. Start the channel (for `FileHandleTextIOChannel` this sets up the `DispatchSourceRead`).

`FileHandleTextIOChannel` is a ready-made adapter for serial ports, pseudo terminals, or other
`FileHandle` based streams. It reads inbound bytes on a background queue, decodes them as UTF-8, and
delivers fragments to the buffer.

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

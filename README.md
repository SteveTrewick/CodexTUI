# CodexTUI

CodexTUI is a Swift package for building composable terminal user interfaces (TUIs) that feel modern while still embracing the expressiveness of classic ANSI terminals. It layers ergonomic UI primitives on top of reliable input/output streams, letting you quickly assemble menus, status bars, overlays, and scrollable text panes that react to keyboard events in real time.

# AI Notice - added by repo owner
This is an experimental package under development with GPT Codex, it probbaly doesn't work yet and AFAICT some of this README (which it wrote) is wrong

## Why CodexTUI?

Designing fluid TUIs in Swift traditionally requires juggling terminal control sequences, low-level input handling, and complex layout math. CodexTUI consolidates those responsibilities into clear abstractions:

- **Declarative components** such as `MenuBar`, `SelectionList`, `StatusBar`, `Text`, `Box`, and `Overlay` form the foundation for larger experiences.
- **Menu and status bars** deliver application chrome with keyboard-activated menu items and dynamic status indicators.
- **CodexApp builder** wires menus, status bars, overlays, focusables, and the terminal driver from declarative definitions so applications stay concise.
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

## Declarative Layout DSL

CodexTUI now ships with a Swift result builder dedicated to widgets. Containers such as `VStack`, `HStack`, `Split`, `Padding`, `Spacer`, and `OverlayStack` automatically compute child bounds and propagate `LayoutContext` so you rarely touch `BoxBounds` directly. Composable widgets declare a `body` assembled with these containers:

```swift
struct StatusPanel : ComposableWidget {
  var theme : Theme

  var body : some Widget {
    OverlayStack {
      Box(style: theme.windowChrome)
      Padding(top: 1, leading: 2, bottom: 1, trailing: 2) {
        VStack(spacing: 1) {
          Label("CodexTUI", style: theme.contentDefault, alignment: .center)
          Label("Declarative layout is now built-in.", style: theme.contentDefault)
        }
      }
    }
  }
}
```

Because containers understand the available space they forward appropriately sized contexts to each child, keeping focus snapshots, themes, and environment values consistent without manual plumbing.

## Quick Start Demo

`CodexApp` bundles the runtime controllers and driver wiring so you can concentrate on declarative layout and overlay definitions. The builder accepts menu bars, status bars, focusable text buffers, and overlay requests and returns a ready-to-run application object:

```swift
import CodexTUI
import Foundation
import Dispatch

final class DemoApplication {
  private let logBuffer : TextBuffer
  private let pipe      : Pipe
  private let channel   : FileHandleTextIOChannel
  private let app       : CodexApp

  init () {
    let theme = Theme.codex

    logBuffer = TextBuffer(
      identifier    : FocusIdentifier("log"),
      lines         : ["CodexTUI quick start"],
      style         : theme.contentDefault,
      highlightStyle: theme.highlight,
      isInteractive : true
    )

    pipe = Pipe()
    channel = FileHandleTextIOChannel(
      readHandle : pipe.fileHandleForReading,
      writeHandle: pipe.fileHandleForWriting
    )
    logBuffer.attach(channel: channel)

    let environment = EnvironmentValues(
      menuBarHeight : 1,
      statusBarHeight: 1,
      contentInsets : EdgeInsets(top: 1, leading: 2, bottom: 1, trailing: 2)
    )
    let configuration = SceneConfiguration(
      theme        : theme,
      environment  : environment,
      showMenuBar  : true,
      showStatusBar: true
    )

    let builder = CodexApp.Builder(configuration: configuration)
    builder.setContent(
      OverlayStack {
        Box(style: theme.windowChrome)
        Padding(top: 1, leading: 2, bottom: 1, trailing: 2) {
          logBuffer
        }
      }
    )
    builder.statusBar    = StatusBar {
      StatusItem(text: "ESC Exit", alignment: .leading)
    }
    builder.menuBar      = MenuBar { }
    builder.addTextBuffer(logBuffer)
    builder.initialFocus = logBuffer.focusIdentifier

    app = builder.build()
    app.onUnhandledKey = { [weak self] token in
      if case .escape = token { self?.shutdown() }
    }
  }

  func run () {
    app.start()
    channel.start()

    app.overlays.messageBox(
      CodexApp.MessageBoxRequest(
        title        : "CodexTUI",
        messageLines : ["Type to echo through the channel."],
        buttons      : [MessageBoxButton(text: "Dismiss")]
      )
    )
  }

  private func shutdown () {
    channel.stop()
    app.stop()
  }
}
```

`CodexApp.OverlayPresenter` also exposes `selectionList` and `textEntryBox` helpers, allowing menu actions and background tasks to present overlays declaratively without touching controller APIs or calling `driver.redraw()` manually.

## Runtime Controllers

CodexTUI's runtime controllers encapsulate the behaviour behind menus, modal overlays, and interactive text so you can wire them into a scene without duplicating state machines. Each controller lives in `Sources/CodexTUI/Runtime/`:

- [`MenuController`](Sources/CodexTUI/Runtime/MenuController.swift) orchestrates menu bar focus, overlay creation, and keyboard routing while remembering the previously focused widget.【F:Sources/CodexTUI/Runtime/MenuController.swift†L4-L140】
- [`MessageBoxController`](Sources/CodexTUI/Runtime/MessageBoxController.swift) presents `MessageBox` overlays, tracks the highlighted button, and restores focus and overlays after dismissal.【F:Sources/CodexTUI/Runtime/MessageBoxController.swift†L4-L199】
- [`SelectionListController`](Sources/CodexTUI/Runtime/SelectionListController.swift) renders scrollable `SelectionList` overlays, handles arrow-key navigation, and keeps the user's place when the viewport changes.【F:Sources/CodexTUI/Runtime/SelectionListController.swift†L4-L188】
- [`TextEntryBoxController`](Sources/CodexTUI/Runtime/TextEntryBoxController.swift) powers modal text prompts by managing caret edits, button activation, and live redraw requests.【F:Sources/CodexTUI/Runtime/TextEntryBoxController.swift†L4-L244】
- [`TextIOController`](Sources/CodexTUI/Runtime/TextIOController.swift) delivers keyboard `.text` tokens to the focused interactive buffer and schedules redraws whenever a registered buffer reports new output.【F:Sources/CodexTUI/Runtime/TextIOController.swift†L4-L53】

`CodexApp` constructs these controllers behind the scenes and assigns them to `TerminalDriver`, so menu bars, modal overlays, and text IO react immediately without additional boilerplate.【F:Sources/CodexTUI/Runtime/CodexApp.swift†L173-L218】 The controllers remain public; advanced callers can access them through the `CodexApp` instance or instantiate their own copies when building bespoke runtimes.

If you ever need to wire things manually, the implementation in `CodexApp` demonstrates the correct order: build the `Scene`, create each controller with shared bounds, assign them to the driver, and rely on the driver's resize pipeline to keep everything in sync.【F:Sources/CodexTUI/Runtime/CodexApp.swift†L133-L218】【F:Sources/CodexTUI/Runtime/TerminalDriver.swift†L32-L154】

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

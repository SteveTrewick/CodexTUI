import Foundation
import Dispatch
import CodexTUI

private struct DemoWorkspace : ComposableWidget {
  var theme     : Theme
  var logBuffer : TextBuffer

  var body : some Widget {
    Padding(top: 1, leading: 2, bottom: 1, trailing: 2) {
      Split(axis: .horizontal, firstSize: .fixed(36), secondSize: .flexible) {
        Panel(
          title    : "Interactive Features",
          bodyLines: [
            "• Press ⌥D to open the Demo menu.",
            "• Choose an overlay to present it immediately.",
            "• Type in the log panel to send text to the channel.",
            "• Use TAB inside overlays to move between controls.",
            "• Press ESC to dismiss overlays or exit the demo."
          ],
          theme: theme
        )
      } second: {
        Split(axis: .vertical, firstSize: .proportion(0.55), secondSize: .flexible) {
          OverlayStack {
            Box(style: theme.windowChrome)
            Padding(top: 1, leading: 2, bottom: 1, trailing: 2) {
              VStack(spacing: 1) {
                Label("Live Text IO", style: highlightedHeaderStyle(), alignment: .center)
                Label("Typed keys echo here via the TextIOController.", style: theme.contentDefault)
                logBuffer
              }
            }
          }
        } second: {
          Panel(
            title    : "Quick Reference",
            bodyLines: [
              "• Command Palette… opens a selection list.",
              "• Compose Message… shows the text entry dialog.",
              "• About CodexTUI presents a message box.",
              "• Background tasks append to the log automatically.",
              "• Quit Demo stops the TerminalDriver."
            ],
            theme: theme
          )
        }
      }
    }
  }

  private func highlightedHeaderStyle () -> ColorPair {
    var style = theme.highlight
    style.style.insert(.bold)
    return style
  }
}

final class DemoApplication {
  private var theme                  : Theme
  private let logBuffer              : TextBuffer
  private let app                    : CodexApp
  private let textChannel            : FileHandleTextIOChannel
  private let channelPipe            : Pipe
  private var backgroundTimer        : DispatchSourceTimer?
  private var backgroundMessages     : [String]
  private var backgroundMessageIndex : Int

  init () {
    theme                  = Theme.codex
    logBuffer              = TextBuffer(identifier: FocusIdentifier("log"), lines: [], scrollOffset: 0, style: theme.contentDefault, highlightStyle: theme.highlight, isInteractive: true)
    backgroundMessages     = DemoApplication.defaultBackgroundMessages()
    backgroundMessageIndex = 0
    channelPipe            = Pipe()

    textChannel = FileHandleTextIOChannel(
      readHandle : channelPipe.fileHandleForReading,
      writeHandle: channelPipe.fileHandleForWriting
    )
    logBuffer.attach(channel: textChannel)

    let environment   = EnvironmentValues(menuBarHeight: 1, statusBarHeight: 1, contentInsets: EdgeInsets(top: 1, leading: 2, bottom: 1, trailing: 2))
    let configuration = SceneConfiguration(theme: theme, environment: environment, showMenuBar: true, showStatusBar: true)
    let builder       = CodexApp.Builder(configuration: configuration, runtimeConfiguration: RuntimeConfiguration())

    builder.setContent(DemoWorkspace(theme: theme, logBuffer: logBuffer))
    builder.statusBar      = DemoApplication.makeStatusBar(theme: theme)
    builder.menuBar        = DemoApplication.makePlaceholderMenuBar(theme: theme)
    builder.addTextBuffer(logBuffer)
    builder.initialFocus = logBuffer.focusIdentifier

    app = builder.build()
    backgroundTimer = nil

    app.onUnhandledKey = { [weak self] token in self?.handleUnhandled(token: token) }
    app.updateMenuBar(makeMenuBar())
  }

  func run () {
    app.start()
    textChannel.start()
    app.focus(identifier: logBuffer.focusIdentifier)
    emitIntroductoryMessages()
    startBackgroundMessages()
    presentWelcomeMessage()

    while app.state != .stopped {
      _ = RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
    }
  }

  private func makeMenuBar () -> MenuBar {
    var items = [MenuItem]()

    items.append(
      MenuItem(
        title         : "Demo",
        activationKey : .meta(.alt("d")),
        alignment     : .leading,
        isHighlighted : false,
        isOpen        : false,
        entries       : [
          MenuItem.Entry(title: "Show Welcome", acceleratorHint: "↩", action: { [weak self] in self?.presentWelcomeMessage() }),
          MenuItem.Entry(title: "Command Palette…", acceleratorHint: "⌥P", action: { [weak self] in self?.presentCommandPalette() }),
          MenuItem.Entry(title: "Compose Message…", acceleratorHint: "⌥M", action: { [weak self] in self?.promptForCustomMessage() }),
          MenuItem.Entry(title: "Quit Demo", acceleratorHint: "ESC", action: { [weak self] in self?.shutdown() })
        ]
      )
    )

    items.append(
      MenuItem(
        title         : "Overlays",
        activationKey : .meta(.alt("o")),
        alignment     : .leading,
        isHighlighted : false,
        isOpen        : false,
        entries       : [
          MenuItem.Entry(title: "Message Box", acceleratorHint: "↩", action: { [weak self] in self?.presentWelcomeMessage() }),
          MenuItem.Entry(title: "Selection List", acceleratorHint: "⌥L", action: { [weak self] in self?.presentCommandPalette() }),
          MenuItem.Entry(title: "Text Entry", acceleratorHint: "⌥T", action: { [weak self] in self?.promptForCustomMessage() })
        ]
      )
    )

    items.append(
      MenuItem(
        title         : "Help",
        activationKey : .meta(.alt("h")),
        alignment     : .trailing,
        isHighlighted : false,
        isOpen        : false,
        entries       : [
          MenuItem.Entry(title: "About CodexTUI", acceleratorHint: "↩", action: { [weak self] in self?.presentAboutDialog() }),
          MenuItem.Entry(title: "View Tips", acceleratorHint: "⌥I", action: { [weak self] in self?.presentTipsMessage() })
        ]
      )
    )

    return MenuBar(items: items, style: theme.menuBar, highlightStyle: theme.highlight, dimHighlightStyle: theme.dimHighlight)
  }

  private static func makeStatusBar ( theme: Theme ) -> StatusBar {
    let items = [
      StatusItem(text: "ESC Exit", alignment: .leading),
      StatusItem(text: "⌥D Demo Menu", alignment: .leading),
      StatusItem(text: "CodexTUIDemo", alignment: .trailing)
    ]
    return StatusBar(items: items, style: theme.statusBar)
  }

  private static func makePlaceholderMenuBar ( theme: Theme ) -> MenuBar {
    return MenuBar(items: [], style: theme.menuBar, highlightStyle: theme.highlight, dimHighlightStyle: theme.dimHighlight)
  }

  private static func defaultBackgroundMessages () -> [String] {
    return [
      "CodexTUI: Setting up terminal surfaces…",
      "Tip: Use Command Palette… to browse demo commands.",
      "TextEntryBoxController listens for raw text tokens.",
      "SelectionList overlays keep focus suspended while open.",
      "MessageBox buttons react to arrow keys and accelerators.",
      "StatusBar shows simple alignment between leading and trailing items." 
    ]
  }

  private func emitIntroductoryMessages () {
    appendLog("CodexTUIDemo ready. Type to stream text into the buffer.")
    appendLog("Visit the Demo menu (⌥D) to open overlays and dialogs.")
  }

  private func startBackgroundMessages () {
    guard backgroundTimer == nil else { return }

    let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
    timer.schedule(deadline: .now() + .seconds(3), repeating: .seconds(4))
    timer.setEventHandler { [weak self] in
      self?.emitBackgroundMessage()
    }

    backgroundTimer = timer
    timer.resume()
  }

  private func emitBackgroundMessage () {
    guard backgroundMessages.isEmpty == false else { return }

    let message = backgroundMessages[backgroundMessageIndex % backgroundMessages.count]
    backgroundMessageIndex += 1
    appendLog(message)
  }

  private func appendLog ( _ text: String ) {
    let line = text.hasSuffix("\n") ? text : text + "\n"
    textChannel.send(line)
  }

  private func presentWelcomeMessage () {
    let buttons = [
      MessageBoxButton(text: "Dismiss"),
      MessageBoxButton(text: "Open Commands", handler: { [weak self] in self?.presentCommandPalette() })
    ]

    let request = CodexApp.MessageBoxRequest(
      title        : "CodexTUI Showcase",
      messageLines : [
        "This demo stitches together menus, overlays and live text IO.",
        "Use the Demo menu or keyboard shortcuts to explore each feature."
      ],
      buttons      : buttons
    )
    app.overlays.messageBox(request)
  }

  private func presentCommandPalette () {
    let entries = [
      SelectionListEntry(title: "Insert timestamp", acceleratorHint: "⌘T", action: { [weak self] in self?.insertTimestamp() }),
      SelectionListEntry(title: "Compose custom message…", acceleratorHint: "↩", action: { [weak self] in self?.promptForCustomMessage() }),
      SelectionListEntry(title: "Show About dialog", acceleratorHint: "⌘I", action: { [weak self] in self?.presentAboutDialog() }),
      SelectionListEntry(title: "Clear log", acceleratorHint: "⌘K", action: { [weak self] in self?.clearLog() })
    ]

    let request = CodexApp.SelectionListRequest(
      title          : "Command Palette",
      entries        : entries,
      selectionIndex : 0
    )
    app.overlays.selectionList(request)
  }

  private func promptForCustomMessage () {
    let buttons = [
      TextEntryBoxButton(text: "Send", activationKey: .RETURN, handler: { [weak self] text in self?.handleCustomMessage(text) }),
      TextEntryBoxButton(text: "Cancel")
    ]

    let request = CodexApp.TextEntryBoxRequest(
      title   : "Compose Message",
      prompt  : "Type a line to append to the log",
      text    : "",
      buttons : buttons
    )
    app.overlays.textEntryBox(request)
  }

  private func handleCustomMessage ( _ text: String ) {
    guard text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else { return }
    appendLog("User: \(text)")
  }

  private func presentAboutDialog () {
    let buttons = [
      MessageBoxButton(text: "OK"),
      MessageBoxButton(text: "Docs", handler: { [weak self] in self?.presentTipsMessage() })
    ]

    let request = CodexApp.MessageBoxRequest(
      title        : "About CodexTUI",
      messageLines : [
        "CodexTUI delivers a composable Swift DSL for ANSI terminals.",
        "This sample wires together menu bars, overlays and text IO."
      ],
      buttons      : buttons
    )
    app.overlays.messageBox(request)
  }

  private func presentTipsMessage () {
    let buttons = [MessageBoxButton(text: "Close")]

    let request = CodexApp.MessageBoxRequest(
      title        : "Try These",
      messageLines : [
        "• Move between menu items with ← and →.",
        "• Scroll the selection list with ↑ and ↓.",
        "• Type while the log has focus to stream characters."
      ],
      buttons      : buttons
    )
    app.overlays.messageBox(request)
  }

  private func insertTimestamp () {
    let formatter = ISO8601DateFormatter()
    let timestamp = formatter.string(from: Date())
    appendLog("Timestamp: \(timestamp)")
  }

  private func clearLog () {
    logBuffer.lines.removeAll()
    appendLog("Log cleared.")
  }

  private func handleUnhandled ( token: TerminalInput.Token ) {
    switch token {
      case .escape : shutdown()
      default      : break
    }
  }

  private func emitShutdownMessage () {
    appendLog("Stopping CodexTUIDemo…")
  }

  private func shutdown () {
    guard app.state != .stopped else { return }
    emitShutdownMessage()
    backgroundTimer?.cancel()
    backgroundTimer = nil
    textChannel.stop()
    app.stop()
  }
}

let demo = DemoApplication()
demo.run()

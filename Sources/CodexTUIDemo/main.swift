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
                Spacer(minLength: 1)
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
  private var theme                    : Theme
  private let focusChain               : FocusChain
  private let logBuffer                : TextBuffer
  private let scene                    : Scene
  private let driver                   : TerminalDriver
  private let textChannel              : FileHandleTextIOChannel
  private let textIOController         : TextIOController
  private let messageBoxController     : MessageBoxController
  private let selectionListController  : SelectionListController
  private let textEntryBoxController   : TextEntryBoxController
  private let menuController           : MenuController
  private let channelPipe              : Pipe
  private var menuBar                  : MenuBar
  private var statusBar                : StatusBar
  private var contentWidget            : AnyWidget
  private var backgroundTimer          : DispatchSourceTimer?
  private var backgroundMessages       : [String]
  private var backgroundMessageIndex   : Int
  private var viewportBounds           : BoxBounds

  init () {
    theme                  = Theme.codex
    focusChain             = FocusChain()
    logBuffer              = TextBuffer(identifier: FocusIdentifier("log"), lines: [], scrollOffset: 0, style: theme.contentDefault, highlightStyle: theme.highlight, isInteractive: true)
    contentWidget          = AnyWidget(DemoWorkspace(theme: theme, logBuffer: logBuffer))
    statusBar              = DemoApplication.makeStatusBar(theme: theme)
    menuBar                = DemoApplication.makePlaceholderMenuBar(theme: theme)
    backgroundMessages     = DemoApplication.defaultBackgroundMessages()
    backgroundMessageIndex = 0
    viewportBounds         = RuntimeConfiguration().initialBounds
    channelPipe            = Pipe()

    let environment = EnvironmentValues(menuBarHeight: 1, statusBarHeight: 1, contentInsets: EdgeInsets(top: 1, leading: 2, bottom: 1, trailing: 2))
    let configuration = SceneConfiguration(theme: theme, environment: environment, showMenuBar: true, showStatusBar: true)

    scene = Scene.standard(menuBar: menuBar, content: contentWidget, statusBar: statusBar, configuration: configuration, focusChain: focusChain)

    textChannel            = FileHandleTextIOChannel(readHandle: channelPipe.fileHandleForReading, writeHandle: channelPipe.fileHandleForWriting)
    driver                 = CodexTUI.makeDriver(scene: scene)
    textIOController       = TextIOController(scene: scene, buffers: [logBuffer])
    messageBoxController   = MessageBoxController(scene: scene, viewportBounds: viewportBounds)
    selectionListController = SelectionListController(scene: scene, viewportBounds: viewportBounds)
    textEntryBoxController = TextEntryBoxController(scene: scene, viewportBounds: viewportBounds, startWidth: 28)
    menuController         = MenuController(scene: scene, menuBar: menuBar, content: contentWidget, statusBar: statusBar, viewportBounds: viewportBounds)
    backgroundTimer        = nil

    focusChain.register(node: logBuffer.focusNode())
    scene.registerFocusable(logBuffer)
    logBuffer.attach(channel: textChannel)

    menuBar = makeMenuBar()
    menuController.menuBar = menuBar

    driver.menuController          = menuController
    driver.messageBoxController    = messageBoxController
    driver.selectionListController = selectionListController
    driver.textEntryBoxController  = textEntryBoxController
    driver.textIOController        = textIOController

    driver.onResize = { [weak self] bounds in
      self?.handleResize(bounds: bounds)
    }

    driver.onKeyEvent = { [weak self] token in
      self?.handleUnhandled(token: token)
    }
  }

  func run () {
    driver.start()
    textChannel.start()
    scene.focusChain.focus(identifier: logBuffer.focusIdentifier)
    emitIntroductoryMessages()
    startBackgroundMessages()
    presentWelcomeMessage()

    while driver.state != .stopped {
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

    messageBoxController.present(
      title                : "CodexTUI Showcase",
      messageLines         : [
        "This demo stitches together menus, overlays and live text IO.",
        "Use the Demo menu or keyboard shortcuts to explore each feature." ],
      buttons              : buttons
    )
    driver.redraw()
  }

  private func presentCommandPalette () {
    let entries = [
      SelectionListEntry(title: "Insert timestamp", acceleratorHint: "⌘T", action: { [weak self] in self?.insertTimestamp() }),
      SelectionListEntry(title: "Compose custom message…", acceleratorHint: "↩", action: { [weak self] in self?.promptForCustomMessage() }),
      SelectionListEntry(title: "Show About dialog", acceleratorHint: "⌘I", action: { [weak self] in self?.presentAboutDialog() }),
      SelectionListEntry(title: "Clear log", acceleratorHint: "⌘K", action: { [weak self] in self?.clearLog() })
    ]

    selectionListController.present(
      title          : "Command Palette",
      entries        : entries,
      selectionIndex : 0
    )
    driver.redraw()
  }

  private func promptForCustomMessage () {
    let buttons = [
      TextEntryBoxButton(text: "Send", activationKey: .RETURN, handler: { [weak self] text in self?.handleCustomMessage(text) }),
      TextEntryBoxButton(text: "Cancel")
    ]

    textEntryBoxController.present(
      title   : "Compose Message",
      prompt  : "Type a line to append to the log",
      text    : "",
      buttons : buttons
    )
    driver.redraw()
  }

  private func handleCustomMessage ( _ text: String ) {
    guard text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else { return }
    appendLog("User: \(text)")
    driver.redraw()
  }

  private func presentAboutDialog () {
    let buttons = [
      MessageBoxButton(text: "OK"),
      MessageBoxButton(text: "Docs", handler: { [weak self] in self?.presentTipsMessage() })
    ]

    messageBoxController.present(
      title        : "About CodexTUI",
      messageLines : [
        "CodexTUI delivers a composable Swift DSL for ANSI terminals.",
        "This sample wires together menu bars, overlays and text IO."
      ],
      buttons      : buttons
    )
    driver.redraw()
  }

  private func presentTipsMessage () {
    let buttons = [MessageBoxButton(text: "Close")]

    messageBoxController.present(
      title        : "Try These",
      messageLines : [
        "• Move between menu items with ← and →.",
        "• Scroll the selection list with ↑ and ↓.",
        "• Type while the log has focus to stream characters." ],
      buttons      : buttons
    )
    driver.redraw()
  }

  private func insertTimestamp () {
    let formatter = ISO8601DateFormatter()
    let timestamp = formatter.string(from: Date())
    appendLog("Timestamp: \(timestamp)")
    driver.redraw()
  }

  private func clearLog () {
    logBuffer.lines.removeAll()
    appendLog("Log cleared.")
    driver.redraw()
  }

  private func handleResize ( bounds: BoxBounds ) {
    viewportBounds = bounds
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
    guard driver.state != .stopped else { return }
    emitShutdownMessage()
    backgroundTimer?.cancel()
    backgroundTimer = nil
    textChannel.stop()
    driver.stop()
  }
}

let demo = DemoApplication()
demo.run()

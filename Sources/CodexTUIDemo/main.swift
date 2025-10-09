import CodexTUI
import Foundation
import Dispatch
import TerminalInput

/// Minimal interactive application that wires together controllers to showcase CodexTUI features.
final class DemoApplication {
  private let driver                 : TerminalDriver
  private let logBuffer              : TextBuffer
  private let menuController         : MenuController
  private let messageBoxController   : MessageBoxController
  private let textEntryBoxController : TextEntryBoxController
  private let textIOController       : TextIOController
  private let logChannel             : FileHandleTextIOChannel
  private let channelWriter          : FileHandle
  private let channelQueue           : DispatchQueue

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
        "Press ESC to exit.",
        "Alt+F opens the File menu."
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
    channelQueue = DispatchQueue(label: "CodexTUIDemo.Channel")

    let initialMenuBar = MenuBar(
      items : [
        MenuItem(
          title         : "File",
          activationKey : .meta(.alt("f")),
          alignment     : .leading,
          isHighlighted : true
        ),
        MenuItem(
          title         : "Help",
          activationKey : .meta(.alt("h")),
          alignment     : .trailing,
          isHighlighted : true
        )
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

    let contentWidget = AnyWidget(logBuffer)

    let scene = Scene.standard(
      menuBar     : initialMenuBar,
      content     : contentWidget,
      statusBar   : statusBar,
      configuration: configuration,
      focusChain  : focusChain
    )

    let runtimeConfiguration = RuntimeConfiguration()

    menuController = MenuController(
      scene          : scene,
      menuBar        : initialMenuBar,
      content        : contentWidget,
      statusBar      : statusBar,
      viewportBounds : runtimeConfiguration.initialBounds
    )

    messageBoxController = MessageBoxController(
      scene          : scene,
      viewportBounds : runtimeConfiguration.initialBounds
    )

    textEntryBoxController = TextEntryBoxController(
      scene          : scene,
      viewportBounds : runtimeConfiguration.initialBounds
    )

    textIOController = TextIOController(
      scene  : scene,
      buffers: [logBuffer]
    )

    driver = CodexTUI.makeDriver(scene: scene, configuration: runtimeConfiguration)
    driver.menuController        = menuController
    driver.messageBoxController  = messageBoxController
    driver.textEntryBoxController = textEntryBoxController
    driver.textIOController      = textIOController

    driver.onKeyEvent = { [weak self] token in
      self?.handle(token: token)
    }

    configureMenuActions()
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
    switch token {
      case .escape        :
        driver.stop()

      default                       :
        break
    }
  }

  private static func timestamp () -> String {
    return timestampFormatter.string(from: Date())
  }

  private func configureMenuActions () {
    var menu = menuController.menuBar

    if let fileIndex = menu.items.firstIndex(where: { $0.title == "File" }) {
      menu.items[fileIndex].entries = [
        MenuItem.Entry(
          title          : "Log Timestamp",
          acceleratorHint: "Ctrl+T",
          action         : { [weak self] in self?.logTimestampEntry() }
        ),
        MenuItem.Entry(
          title          : "Log Custom Message",
          acceleratorHint: "Ctrl+L",
          action         : { [weak self] in self?.promptForLogEntry() }
        ),
        MenuItem.Entry(
          title          : "Clear Log",
          acceleratorHint: "Ctrl+K",
          action         : { [weak self] in self?.clearLog() }
        ),
        MenuItem.Entry(
          title          : "Quit Demo",
          acceleratorHint: "Esc",
          action         : { [weak self] in self?.quitDemo() }
        )
      ]
    }

    if let helpIndex = menu.items.firstIndex(where: { $0.title == "Help" }) {
      menu.items[helpIndex].entries = [
        MenuItem.Entry(
          title          : "About CodexTUI",
          acceleratorHint: "Ctrl+/",
          action         : { [weak self] in self?.showAboutMessage() }
        )
      ]
    }

    menuController.menuBar = menu
  }

  private func logTimestampEntry () {
    logBuffer.append(line: "Timestamp: \(DemoApplication.timestamp())")
  }

  private func promptForLogEntry () {
    let pair = ColorPair(foreground: Theme.defaultContent.foreground, background: Theme.defaultContent.background, style: [.dim] )
    
    textEntryBoxController.present(
      title   : "Log Custom Message",
      prompt  : "Enter text to append to the log.",
      buttons : [
        TextEntryBoxButton(
          text    : "Save",
          handler : { [weak self] text in
            guard let self = self else { return }
            self.logBuffer.append(line: text)
            self.driver.redraw()
          }
        ),
        TextEntryBoxButton(
          text    : "Cancel",
          handler : { [weak self] _ in
            self?.driver.redraw()
          }
        )
      ],
      promptStyleOverride: pair
      
    )
  }

  private func clearLog () {
    logBuffer.lines.removeAll()
    logBuffer.scrollOffset = 0
    logBuffer.append(line: "Log cleared")
    logBuffer.attach(channel: logChannel)
  }

  private func quitDemo () {
    driver.stop()
  }

  private func showAboutMessage () {
    messageBoxController.present(
      title       : "About CodexTUI",
      messageLines: [
        "CodexTUI is a Swift terminal UI toolkit.",
        "Navigate menus with arrows and Return."
      ],
      buttons     : [
        MessageBoxButton(text: "OK"),
        MessageBoxButton(text: "NO")

      ],
      titleStyleOverride   : Theme.defaultWindowChrome,
      messageStyleOverrides: []
    )
  }

  private func seedDemoChannel () {
    let messages = [
      "Connecting to simulated serial device...",
      "Connection established.",
      "Type to echo text through the channel.",
      "Menu > File > Log Timestamp writes directly to the buffer."
    ]

    for (index, message) in messages.enumerated() {
      channelQueue.asyncAfter(deadline: .now() + .milliseconds(400 * index)) { [weak self] in
        self?.writeToChannel("\(message)\n")
      }
    }
  }

  private func writeToChannel ( _ text: String ) {
    guard let data = text.data(using: .utf8) else { return }
    channelWriter.write(data)
  }
}

let application = DemoApplication()
application.run()

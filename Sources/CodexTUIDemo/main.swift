import CodexTUI
import Foundation
import TerminalInput

final class DemoApplication {
  private let driver    : TerminalDriver
  private let logBuffer : TextBuffer
  private let menuBar   : MenuBar

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

    menuBar = MenuBar(
      items : [
          MenuItem ( title: "File",
                     activationKey: .meta(.alt("f")),
                     alignment    : .leading,
                     isHighlighted: true
          ),
          MenuItem ( title: "Help",
                     activationKey: .meta(.alt("h")),
                     alignment    : .trailing,
                     isHighlighted: true
                   
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

    let runLoop = RunLoop.current

    while driver.state != .stopped {
      _ = runLoop.run(mode: .default, before: Date(timeIntervalSinceNow: 0.1))
    }
  }

  private func handle ( token: TerminalInput.Token ) {
    if let item = menuBar.items.first(where: { $0.matches(token: token) }) {
      logBuffer.append(line: "Activated menu item: \(item.title)")
      driver.redraw()
      return
    }

    switch token {
      case .escape        :
        driver.stop()

      case .text(let string)                   :
        guard string.count == 1, let character = string.first else { break }
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

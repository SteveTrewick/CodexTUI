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
        MenuItem(title: "File", activationKey: .TAB, alignment: .leading, isHighlighted: true),
        MenuItem(title: "Help", activationKey: .RETURN, alignment: .trailing)
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

    driver.onKeyEvent = { [weak self] event in
      self?.handle(event: event)
    }
  }

  func run () {
    driver.start()
    waitGroup.wait()
  }

  private func handle ( event: KeyEvent ) {
    switch event.key {
      case .meta(.escape)           :
        driver.stop()
        waitGroup.signal()

      case .character(let character)           :
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

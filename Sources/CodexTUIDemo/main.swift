import CodexTUI
import Foundation
import Dispatch
import TerminalInput

struct ThemeOption {
  var name  : String
  var theme : Theme
}

struct ShowcaseWorkspace : Widget {
  var logBuffer    : TextBuffer
  var theme        : Theme
  var instructions : [String]

  func layout ( in context: LayoutContext ) -> WidgetLayoutResult {
    let rootBounds = context.bounds
    let interior   = rootBounds.inset(by: context.environment.contentInsets)

    guard interior.width > 0 && interior.height > 0 else {
      return WidgetLayoutResult(bounds: rootBounds)
    }

    var children = [WidgetLayoutResult]()

    let childEnvironment = EnvironmentValues(
      menuBarHeight   : context.environment.menuBarHeight,
      statusBarHeight : context.environment.statusBarHeight,
      contentInsets   : EdgeInsets()
    )

    let hasSidePanel = interior.width >= 40
    let gutter       = hasSidePanel ? 2 : 0
    let desiredPanel = hasSidePanel ? max(24, min(interior.width / 3, 36)) : 0

    var logWidth      = interior.width - desiredPanel - gutter
    var panelWidth    = desiredPanel

    if logWidth < 24 {
      logWidth   = interior.width
      panelWidth = 0
    }

    logWidth   = max(1, logWidth)
    panelWidth = max(0, panelWidth)

    let logBounds = BoxBounds(
      row    : interior.row,
      column : interior.column,
      width  : logWidth,
      height : interior.height
    )

    let logContext = LayoutContext(
      bounds      : logBounds,
      theme       : context.theme,
      focus       : context.focus,
      environment : childEnvironment
    )

    children.append(logBuffer.layout(in: logContext))

    if panelWidth > 0 {
      let panelColumn = logBounds.column + logBounds.width + gutter
      let panelBounds = BoxBounds(
        row    : interior.row,
        column : panelColumn,
        width  : panelWidth,
        height : interior.height
      )

      let panelContext = LayoutContext(
        bounds      : panelBounds,
        theme       : context.theme,
        focus       : context.focus,
        environment : childEnvironment
      )

      let border = Box(bounds: panelBounds, style: theme.windowChrome)
      children.append(border.layout(in: panelContext))

      let titleStyle : ColorPair = {
        var style = theme.contentDefault
        style.style.insert(.bold)
        return style
      }()

      let bodyStyle = theme.contentDefault
      let insetRow  = panelBounds.row + 1
      let insetCol  = panelBounds.column + 2
      let maxRow    = panelBounds.maxRow - 1
      let usableWidth = max(0, panelBounds.width - 4)

      if insetRow <= maxRow {
        let title = Text("CodexTUI Showcase", origin: (row: insetRow, column: insetCol), style: titleStyle)
        children.append(title.layout(in: panelContext))
      }

      var currentRow = insetRow + 2

      for line in instructions {
        guard currentRow <= maxRow else { break }
        let clamped = String(line.prefix(usableWidth))
        let text    = Text(clamped, origin: (row: currentRow, column: insetCol), style: bodyStyle)
        children.append(text.layout(in: panelContext))
        currentRow += 1
      }
    }

    return WidgetLayoutResult(bounds: rootBounds, children: children)
  }
}

final class ShowcaseApplication {
  private let scene                : Scene
  private let runtimeConfiguration : RuntimeConfiguration
  private let driver               : TerminalDriver
  private let logBuffer            : TextBuffer
  private let logChannel           : FileHandleTextIOChannel
  private let channelWriter        : FileHandle
  private let channelQueue         : DispatchQueue
  private let instructions         : [String]
  private let themes               : [ThemeOption]

  private var activeTheme              : ThemeOption
  private var workspace                : ShowcaseWorkspace
  private var menuBar                  : MenuBar
  private var statusBar                : StatusBar
  private var menuController           : MenuController
  private var messageBoxController     : MessageBoxController
  private var selectionListController  : SelectionListController
  private var textEntryBoxController   : TextEntryBoxController
  private var textIOController         : TextIOController
  private var viewportBounds           : BoxBounds

  private static let timestampFormatter : DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
  }()

  init () {
    instructions = [
      "Use Alt+F to open File actions.",
      "Alt+V exposes the theme picker.",
      "Type in the log buffer to echo via TextIO.",
      "Open Help to see styled message boxes.",
      "ESC closes overlays and exits the demo."
    ]

    let midnight = ThemeOption(
      name  : "Midnight",
      theme : Theme(
        menuBar        : ColorPair(foreground: .cyan, background: .black, style: [.bold]),
        statusBar      : ColorPair(foreground: .black, background: .cyan, style: []),
        windowChrome   : ColorPair(foreground: .cyan, background: .black, style: [.bold]),
        contentDefault : ColorPair(foreground: .white, background: .black),
        highlight      : ColorPair(foreground: .black, background: .cyan, style: [.bold]),
        dimHighlight   : ColorPair(foreground: .black, background: .cyan, style: [.dim])
      )
    )

    let daybreak = ThemeOption(
      name  : "Daybreak",
      theme : Theme(
        menuBar        : ColorPair(foreground: .blue, background: .white, style: [.bold]),
        statusBar      : ColorPair(foreground: .black, background: .white, style: []),
        windowChrome   : ColorPair(foreground: .blue, background: .white, style: [.bold]),
        contentDefault : ColorPair(foreground: .black, background: .white),
        highlight      : ColorPair(foreground: .white, background: .blue, style: [.bold]),
        dimHighlight   : ColorPair(foreground: .blue, background: .white, style: [.dim])
      )
    )

    let neon = ThemeOption(
      name  : "Neon",
      theme : Theme(
        menuBar        : ColorPair(foreground: .magenta, background: .black, style: [.bold]),
        statusBar      : ColorPair(foreground: .black, background: .magenta, style: []),
        windowChrome   : ColorPair(foreground: .magenta, background: .black, style: [.bold]),
        contentDefault : ColorPair(foreground: .green, background: .black),
        highlight      : ColorPair(foreground: .black, background: .green, style: [.bold]),
        dimHighlight   : ColorPair(foreground: .black, background: .green, style: [.dim])
      )
    )

    themes      = [midnight, daybreak, neon]
    activeTheme = midnight

    logBuffer = TextBuffer(
      identifier     : FocusIdentifier("showcase.log"),
      lines          : [
        "CodexTUI showcase", 
        "Press ESC to exit.",
        "Type to echo through the log channel.",
        "Use the menus to explore widgets."
      ],
      style          : midnight.theme.contentDefault,
      highlightStyle : midnight.theme.highlight,
      isInteractive  : true
    )

    let pipe = Pipe()
    channelWriter = pipe.fileHandleForWriting
    logChannel    = FileHandleTextIOChannel(
      readHandle : pipe.fileHandleForReading,
      writeHandle: pipe.fileHandleForWriting
    )
    logBuffer.attach(channel: logChannel)
    channelQueue = DispatchQueue(label: "CodexTUIDemo.ShowcaseChannel")

    workspace = ShowcaseWorkspace(
      logBuffer    : logBuffer,
      theme        : midnight.theme,
      instructions : instructions
    )

    runtimeConfiguration = RuntimeConfiguration()
    viewportBounds       = runtimeConfiguration.initialBounds

    let focusChain = FocusChain()
    focusChain.register(node: logBuffer.focusNode())

    let configuration = SceneConfiguration(
      theme       : midnight.theme,
      environment : EnvironmentValues(contentInsets: EdgeInsets(top: 1, leading: 2, bottom: 1, trailing: 2))
    )

    menuBar   = MenuBar(items: [], style: midnight.theme.menuBar, highlightStyle: midnight.theme.highlight, dimHighlightStyle: midnight.theme.dimHighlight)
    statusBar = ShowcaseApplication.makeStatusBar(for: midnight)

    scene = Scene.standard(
      menuBar      : menuBar,
      content      : AnyWidget(workspace),
      statusBar    : statusBar,
      configuration: configuration,
      focusChain   : focusChain
    )

    menuController = MenuController(
      scene          : scene,
      menuBar        : menuBar,
      content        : AnyWidget(workspace),
      statusBar      : statusBar,
      viewportBounds : viewportBounds
    )

    messageBoxController = MessageBoxController(
      scene          : scene,
      viewportBounds : viewportBounds
    )

    selectionListController = SelectionListController(
      scene          : scene,
      viewportBounds : viewportBounds
    )

    textEntryBoxController = TextEntryBoxController(
      scene          : scene,
      viewportBounds : viewportBounds
    )

    textIOController = TextIOController(
      scene  : scene,
      buffers: [logBuffer]
    )
    textIOController.register(buffer: logBuffer)

    driver = CodexTUI.makeDriver(scene: scene, configuration: runtimeConfiguration)

    driver.menuController          = menuController
    driver.messageBoxController    = messageBoxController
    driver.selectionListController = selectionListController
    driver.textEntryBoxController  = textEntryBoxController
    driver.textIOController        = textIOController

    driver.onKeyEvent = { [weak self] token in
      self?.handleKeyEvent(token)
    }

    driver.onResize = { [weak self] bounds in
      self?.updateViewport(bounds: bounds)
    }

    applyTheme(midnight)
  }

  func run () {
    logChannel.start()
    seedDemoMessages()

    driver.start()

    let runLoop = RunLoop.current
    while driver.state != .stopped {
      _ = runLoop.run(mode: .default, before: Date(timeIntervalSinceNow: 0.1))
    }

    logChannel.stop()
  }

  private func applyTheme ( _ option: ThemeOption ) {
    activeTheme = option
    scene.configuration.theme = option.theme

    logBuffer.style          = option.theme.contentDefault
    logBuffer.highlightStyle = option.theme.highlight

    workspace = ShowcaseWorkspace(
      logBuffer    : logBuffer,
      theme        : option.theme,
      instructions : instructions
    )

    statusBar = ShowcaseApplication.makeStatusBar(for: option)
    menuBar   = buildMenuBar(for: option)

    let contentWidget = AnyWidget(workspace)

    menuController = MenuController(
      scene          : scene,
      menuBar        : menuBar,
      content        : contentWidget,
      statusBar      : statusBar,
      viewportBounds : viewportBounds
    )

    driver.menuController = menuController
    driver.redraw()
  }

  private func buildMenuBar ( for option: ThemeOption ) -> MenuBar {
    var fileItem = MenuItem(
      title         : "File",
      activationKey : .meta(.alt("f")),
      alignment     : .leading,
      isHighlighted : true
    )

    fileItem.entries = [
      MenuItem.Entry(
        title          : "Log Timestamp",
        acceleratorHint: "Ctrl+T",
        action         : { [weak self] in self?.logTimestamp() }
      ),
      MenuItem.Entry(
        title          : "Log Custom Message",
        acceleratorHint: "Ctrl+L",
        action         : { [weak self] in self?.presentLogEntryPrompt() }
      ),
      MenuItem.Entry(
        title          : "Clear Log",
        acceleratorHint: "Ctrl+K",
        action         : { [weak self] in self?.clearLog() }
      ),
      MenuItem.Entry(
        title          : "Quit",
        acceleratorHint: "Esc",
        action         : { [weak self] in self?.quit() }
      )
    ]

    var viewItem = MenuItem(
      title         : "View",
      activationKey : .meta(.alt("v")),
      alignment     : .leading,
      isHighlighted : true
    )

    viewItem.entries = [
      MenuItem.Entry(
        title          : "Choose Theme",
        acceleratorHint: "Ctrl+Shift+T",
        action         : { [weak self] in self?.presentThemePicker() }
      )
    ]

    var toolingItem = MenuItem(
      title         : "Tools",
      activationKey : .meta(.alt("t")),
      alignment     : .leading,
      isHighlighted : true
    )

    toolingItem.entries = [
      MenuItem.Entry(
        title          : "Simulate Channel Output",
        acceleratorHint: "Ctrl+O",
        action         : { [weak self] in self?.simulateToolingOutput() }
      )
    ]

    var helpItem = MenuItem(
      title         : "Help",
      activationKey : .meta(.alt("h")),
      alignment     : .trailing,
      isHighlighted : true
    )

    helpItem.entries = [
      MenuItem.Entry(
        title          : "About CodexTUI",
        acceleratorHint: "Ctrl+/",
        action         : { [weak self] in self?.presentAboutDialog() }
      )
    ]

    return MenuBar(
      items             : [fileItem, viewItem, toolingItem, helpItem],
      style             : option.theme.menuBar,
      highlightStyle    : option.theme.highlight,
      dimHighlightStyle : option.theme.dimHighlight
    )
  }

  private func presentThemePicker () {
    let selectionIndex = themes.firstIndex(where: { $0.name == activeTheme.name }) ?? 0
    let entries = themes.enumerated().map { index, option -> SelectionListEntry in
      let hint = index == selectionIndex ? "(Active)" : nil
      return SelectionListEntry(
        title           : option.name,
        acceleratorHint : hint,
        action          : { [weak self] in
          self?.selectionListController.dismiss()
          self?.applyTheme(option)
        }
      )
    }

    selectionListController.present(
      title                  : "Choose Theme",
      entries                : entries,
      selectionIndex         : selectionIndex,
      titleStyleOverride     : activeTheme.theme.windowChrome,
      contentStyleOverride   : activeTheme.theme.contentDefault,
      highlightStyleOverride : activeTheme.theme.highlight,
      borderStyleOverride    : activeTheme.theme.windowChrome
    )

    driver.redraw()
  }

  private func presentAboutDialog () {
    let theme        = activeTheme.theme
    var accent       = theme.highlight
    accent.style.insert(.italic)

    let buttons = [
      MessageBoxButton(text: "Visit Repo", handler: { [weak self] in
        self?.appendLog("Pretend browser opened...")
        self?.driver.redraw()
      }),
      MessageBoxButton(text: "Close", handler: { [weak self] in
        self?.driver.redraw()
      })
    ]

    messageBoxController.present(
      title                 : "CodexTUI Showcase",
      messageLines          : [
        "Explore menus, overlays and text IO.",
        "Themes demonstrate dynamic styling.",
        "Focus stays within the active modal."
      ],
      buttons               : buttons,
      titleStyleOverride    : theme.windowChrome,
      messageStyleOverrides : [theme.contentDefault, accent, theme.contentDefault],
      buttonStyleOverride   : theme.menuBar
    )

    driver.redraw()
  }

  private func presentLogEntryPrompt () {
    let theme  = activeTheme.theme
    var prompt = theme.contentDefault
    prompt.style.insert(.dim)

    textEntryBoxController.present(
      title                : "Log Custom Message",
      prompt               : "Enter text to append to the log.",
      buttons              : [
        TextEntryBoxButton(text: "Save", handler: { [weak self] text in
          guard let self = self else { return }
          self.appendLog(text)
          self.driver.redraw()
        }),
        TextEntryBoxButton(text: "Cancel", activationKey: .TAB, handler: { [weak self] _ in
          self?.driver.redraw()
        })
      ],
      titleStyleOverride   : theme.windowChrome,
      promptStyleOverride  : prompt,
      buttonStyleOverride  : theme.menuBar
    )

    driver.redraw()
  }

  private func logTimestamp () {
    appendLog("Timestamp: \(ShowcaseApplication.timestampFormatter.string(from: Date()))")
    driver.redraw()
  }

  private func simulateToolingOutput () {
    channelQueue.asyncAfter(deadline: .now() + .milliseconds(200)) { [weak self] in
      self?.writeToChannel("[Tooling] Background task completed.\n")
    }
  }

  private func clearLog () {
    logBuffer.lines.removeAll()
    logBuffer.scrollOffset = 0
    appendLog("Log cleared")
    logBuffer.attach(channel: logChannel)
    driver.redraw()
  }

  private func quit () {
    driver.stop()
  }

  private func handleKeyEvent ( _ token: TerminalInput.Token ) {
    switch token {
      case .escape :
        driver.stop()

      default :
        appendLog("Unhandled token: \(describe(token: token))")
        driver.redraw()
    }
  }

  private func appendLog ( _ line: String ) {
    guard line.isEmpty == false else { return }
    logBuffer.append(line: line)
  }

  private func describe ( token: TerminalInput.Token ) -> String {
    switch token {
      case .text(let string)    : return "text(\(string))"
      case .control(let key)    : return "control(\(key))"
      case .cursor(let key)     : return "cursor(\(key))"
      case .function(let key)   : return "function(\(key))"
      case .meta(let key)       : return "meta(\(key))"
      case .response            : return "response"
      case .ansi                : return "ansi-sequence"
      case .mouse               : return "mouse"
      case .escape              : return "escape"
    }
  }

  private func seedDemoMessages () {
    let messages = [
      "Connecting to simulated terminal...",
      "Connection established.",
      "Keyboard input echoes into the log buffer.",
      "Open Tools to simulate channel output."
    ]

    for (index, message) in messages.enumerated() {
      channelQueue.asyncAfter(deadline: .now() + .milliseconds(400 * index)) { [weak self] in
        self?.writeToChannel("\(message)\n")
      }
    }
  }

  private func updateViewport ( bounds: BoxBounds ) {
    viewportBounds = bounds
    menuController.update(viewportBounds: bounds)
    messageBoxController.update(viewportBounds: bounds)
    selectionListController.update(viewportBounds: bounds)
    textEntryBoxController.update(viewportBounds: bounds)
  }

  private func writeToChannel ( _ text: String ) {
    guard let data = text.data(using: .utf8) else { return }
    channelWriter.write(data)
  }

  private static func makeStatusBar ( for option: ThemeOption ) -> StatusBar {
    return StatusBar(
      items : [
        StatusItem(text: "ESC exits"),
        StatusItem(text: "Theme: \(option.name)", alignment: .trailing)
      ],
      style : option.theme.statusBar
    )
  }
}

let application = ShowcaseApplication()
application.run()

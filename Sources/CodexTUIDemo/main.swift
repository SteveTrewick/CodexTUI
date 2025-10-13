import CodexTUI
import Foundation
import Dispatch
import TerminalInput

//  The demo stitches together the main subsystems offered by the framework. The
//  ShowcaseApplication builds a Scene graph composed of a menu bar, a
//  scrollable log buffer and a status bar, then binds them to the input and
//  overlay controllers required to react to keyboard events and modal UI.
//  Detailed comments below document how each piece is constructed and wired.

struct ThemeOption {
  var name  : String
  var theme : Theme
}

//  ShowcaseWorkspace is the root Widget rendered inside the demo Scene. It
//  embeds a TextBuffer for log output and draws a side panel of instructions
//  that explains how to interact with the demo.
struct ShowcaseWorkspace : Widget {
  var logBuffer    : TextBuffer
  var theme        : Theme
  var instructions : [String]

  //  Layout orchestrates a two column view when there is enough terminal
  //  width: the log buffer on the left and the instruction panel on the right.
  //  When the terminal is too narrow only the log buffer is shown. Every
  //  WidgetLayoutResult produced here becomes a child node of the Scene's
  //  content tree.
  func layout ( in context: LayoutContext ) -> WidgetLayoutResult {
    let insets       = context.environment.contentInsets
    let paddedBounds = context.bounds.inset(by: insets)
    let hasInterior  = paddedBounds.width > 0 && paddedBounds.height > 0

    guard hasInterior else { return WidgetLayoutResult(bounds: context.bounds) }

    let hasSidePanel = paddedBounds.width >= 40
    let gutter       = hasSidePanel ? 2 : 0
    let desiredPanel = hasSidePanel ? max(24, min(paddedBounds.width / 3, 36)) : 0

    var logWidth   = paddedBounds.width - desiredPanel - gutter
    var panelWidth = desiredPanel

    if logWidth < 24 {
      logWidth   = paddedBounds.width
      panelWidth = 0
    }

    logWidth   = max(1, logWidth)
    panelWidth = max(0, panelWidth)

    let environmentReset : (inout EnvironmentValues) -> Void = { values in
      values.contentInsets = EdgeInsets()
    }

    let panelWidget = Panel(title: "CodexTUI Showcase", bodyLines: instructions, theme: theme)

    let content = Padding(
      top      : insets.top,
      leading  : insets.leading,
      bottom   : insets.bottom,
      trailing : insets.trailing
    ) {
      if panelWidth > 0 {
        Split(
          axis      : .horizontal,
          firstSize : .fixed(logWidth),
          secondSize: .fixed(panelWidth + gutter),
          first     : {
            EnvironmentScope(applying: environmentReset) { logBuffer }
          },
          second    : {
            Padding(leading: gutter) {
              EnvironmentScope(applying: environmentReset) { panelWidget }
            }
          }
        )
      } else {
        EnvironmentScope(applying: environmentReset) { logBuffer }
      }
    }

    return content.layout(in: context)
  }
}

//  ShowcaseApplication owns the Scene, controllers and runtime resources that
//  bring the showcase to life. The initializer assembles the UI tree, configures
//  overlay controllers, wires up TextIO, and connects the driver callbacks so
//  keyboard and resize events propagate through the demo.
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
    //  Static instructions displayed in the side panel to guide the user.
    instructions = [
      "Use Alt+F to open File actions.",
      "Alt+V exposes the theme picker.",
      "Type in the log buffer to echo via TextIO.",
      "Open Help to see styled message boxes.",
      "ESC closes overlays and exits the demo."
    ]

    //  The demo ships with three built-in themes. Each ThemeOption packages the
    //  styling information needed to recolor the menu bar, content, highlights
    //  and window chrome. The active theme can be switched at runtime through
    //  the View menu.
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

    //  The log buffer is the interactive, scrollable text area that occupies
    //  most of the window. It is registered with the focus chain so keyboard
    //  input is directed to it when no modal overlays are visible.
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

    //  A Pipe connects the TextIO channel to the buffer. Background jobs write
    //  into the pipe while the buffer listens on the read end, allowing
    //  asynchronous messages to appear in the log.
    let pipe = Pipe()
    channelWriter = pipe.fileHandleForWriting
    logChannel    = FileHandleTextIOChannel(
      readHandle : pipe.fileHandleForReading,
      writeHandle: pipe.fileHandleForWriting
    )
    logBuffer.attach(channel: logChannel)
    channelQueue = DispatchQueue(label: "CodexTUIDemo.ShowcaseChannel")

    //  Assemble the root content widget with the log buffer and instructional
    //  copy. The Theme is threaded through so the side panel can pick up
    //  window chrome colors when it draws.
    workspace = ShowcaseWorkspace(
      logBuffer    : logBuffer,
      theme        : midnight.theme,
      instructions : instructions
    )

    //  RuntimeConfiguration seeds the terminal bounds and other driver level
    //  settings, such as the minimum redraw interval.
    runtimeConfiguration = RuntimeConfiguration()
    viewportBounds       = runtimeConfiguration.initialBounds

    //  The focus chain manages which widget receives keyboard focus. Only the
    //  log buffer participates in focus for this demo, but registering it keeps
    //  the code consistent with how larger apps orchestrate focus.
    let focusChain = FocusChain()
    focusChain.register(node: logBuffer.focusNode())

    //  SceneConfiguration captures the default theme and layout environment.
    //  Here we apply padding around the content so the window chrome does not
    //  press against the terminal edges.
    let configuration = SceneConfiguration(
      theme       : midnight.theme,
      environment : EnvironmentValues(contentInsets: EdgeInsets(top: 1, leading: 2, bottom: 1, trailing: 2))
    )

    menuBar   = MenuBar(items: [], style: midnight.theme.menuBar, highlightStyle: midnight.theme.highlight, dimHighlightStyle: midnight.theme.dimHighlight)
    statusBar = ShowcaseApplication.makeStatusBar(for: midnight)

    //  The scene aggregates the menu bar, content widget and status bar. This
    //  becomes the root node rendered by the driver, which orchestrates drawing
    //  only the regions that change after each update.
    scene = Scene.standard(
      menuBar      : menuBar,
      content      : AnyWidget(workspace),
      statusBar    : statusBar,
      configuration: configuration,
      focusChain   : focusChain
    )

    //  Controllers coordinate interactions for their respective overlays and
    //  widgets. The menu controller navigates the menu hierarchy and updates the
    //  scene when menu overlays open or close.
    menuController = MenuController(
      scene          : scene,
      menuBar        : menuBar,
      content        : AnyWidget(workspace),
      statusBar      : statusBar,
      viewportBounds : viewportBounds
    )

    //  Handles presentation of modal message boxes triggered from the menu.
    messageBoxController = MessageBoxController(
      scene          : scene,
      viewportBounds : viewportBounds
    )

    //  Presents selection lists such as the theme picker, anchored within the
    //  current viewport bounds.
    selectionListController = SelectionListController(
      scene          : scene,
      viewportBounds : viewportBounds
    )

    //  Manages single-line text entry overlays, used by the "Log Custom
    //  Message" action.
    textEntryBoxController = TextEntryBoxController(
      scene          : scene,
      viewportBounds : viewportBounds
    )

    //  TextIOController forwards terminal input events to interactive buffers.
    //  Registering the log buffer enables live echo of user keystrokes.
    textIOController = TextIOController(
      scene  : scene,
      buffers: [logBuffer]
    )
    textIOController.register(buffer: logBuffer)

    //  The driver ties the scene graph to the TerminalInput/Output backends. It
    //  is responsible for polling keyboard events, reacting to resize signals
    //  and redrawing the screen diff.
    driver = CodexTUI.makeDriver(scene: scene, configuration: runtimeConfiguration)

    driver.menuController          = menuController
    driver.messageBoxController    = messageBoxController
    driver.selectionListController = selectionListController
    driver.textEntryBoxController  = textEntryBoxController
    driver.textIOController        = textIOController

    //  Forward key presses and resize events into instance methods so the demo
    //  can update state and request redraws.
    driver.onKeyEvent = { [weak self] token in
      self?.handleKeyEvent(token)
    }

    driver.onResize = { [weak self] bounds in
      self?.updateViewport(bounds: bounds)
    }

    //  The initial theme is applied last so every component picks up the color
    //  palette that matches the selected option.
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

  //  Rebuilds the theme-dependent pieces (widgets and controllers) whenever the
  //  user selects a new ThemeOption.
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

    //  A fresh menu controller is created so the new menu bar uses the updated
    //  color palette and viewport bounds.
    menuController = MenuController(
      scene          : scene,
      menuBar        : menuBar,
      content        : contentWidget,
      statusBar      : statusBar,
      viewportBounds : viewportBounds
    )

    //  Update the driver references so future events target the rebuilt
    //  controllers, then request a redraw to show the refreshed styling.
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

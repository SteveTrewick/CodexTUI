import CodexTUI
import Dispatch
import Foundation

// MARK: - Menu Bar

enum MenuItemAlignment {
  case leading
  case trailing
}

struct MenuItem {
  var key       : Character
  var title     : String
  var alignment : MenuItemAlignment
  var action    : (() -> MessageBox)?

  init ( key: Character, title: String, alignment: MenuItemAlignment = .leading, action: (() -> MessageBox)? = nil ) {
    self.key       = key
    self.title     = title
    self.alignment = alignment
    self.action    = action
  }
}

struct MenuBar : Widget {
  var items : [MenuItem]

  init ( items: [MenuItem] ) {
    self.items = items
  }

  func layout ( in context: LayoutContext ) -> WidgetLayoutResult {
    let row         = context.bounds.row
    var commands    = [RenderCommand]()
    var leftColumn  = context.bounds.column
    var rightColumn = context.bounds.maxCol

    for item in items where item.alignment == .leading {
      commands.append(contentsOf: render(item: item, row: row, column: leftColumn, theme: context.theme))
      leftColumn += item.title.count + 2
    }

    for item in items.reversed() where item.alignment == .trailing {
      rightColumn -= item.title.count
      commands.append(contentsOf: render(item: item, row: row, column: rightColumn, theme: context.theme))
      rightColumn -= 2
    }

    return WidgetLayoutResult(bounds: context.bounds, commands: commands)
  }

  private func render ( item: MenuItem, row: Int, column: Int, theme: Theme ) -> [RenderCommand] {
    var commands = [RenderCommand]()
    let highlightIndex = highlightOffset(in: item.title, key: item.key)

    for (index, character) in item.title.enumerated() {
      let attributes : ColorPair
      if index == highlightIndex {
        attributes = theme.highlight
      } else {
        attributes = theme.menuBar
      }

      commands.append(
        RenderCommand(
          row   : row,
          column: column + index,
          tile  : SurfaceTile(
            character : character,
            attributes: attributes
          )
        )
      )
    }

    return commands
  }

  private func highlightOffset ( in title: String, key: Character ) -> Int {
    let uppercaseKey = Character(String(key).uppercased())
    for (index, character) in title.enumerated() {
      let candidate = Character(String(character).uppercased())
      if candidate == uppercaseKey { return index }
    }
    return 0
  }
}

// MARK: - Status Bar

enum StatusItemAlignment {
  case leading
  case trailing
}

struct StatusItem {
  var text      : String
  var alignment : StatusItemAlignment

  init ( text: String, alignment: StatusItemAlignment = .leading ) {
    self.text      = text
    self.alignment = alignment
  }
}

struct StatusBar : Widget {
  var items : [StatusItem]

  init ( items: [StatusItem] ) {
    self.items = items
  }

  func layout ( in context: LayoutContext ) -> WidgetLayoutResult {
    let row         = context.bounds.maxRow
    var commands    = [RenderCommand]()
    var leftColumn  = context.bounds.column
    var rightColumn = context.bounds.maxCol

    for item in items where item.alignment == .leading {
      commands.append(contentsOf: render(item: item, row: row, column: leftColumn, theme: context.theme))
      leftColumn += item.text.count + 1
    }

    for item in items.reversed() where item.alignment == .trailing {
      rightColumn -= item.text.count
      commands.append(contentsOf: render(item: item, row: row, column: rightColumn, theme: context.theme))
      rightColumn -= 1
    }

    return WidgetLayoutResult(bounds: context.bounds, commands: commands)
  }

  private func render ( item: StatusItem, row: Int, column: Int, theme: Theme ) -> [RenderCommand] {
    var commands = [RenderCommand]()

    for (offset, character) in item.text.enumerated() {
      commands.append(
        RenderCommand(
          row   : row,
          column: column + offset,
          tile  : SurfaceTile(
            character : character,
            attributes: theme.statusBar
          )
        )
      )
    }

    return commands
  }
}

// MARK: - Scroll Buffer and Text View

final class ScrollBuffer {
  private(set) var lines        : [String]
  var scrollOffset              : Int

  init ( lines: [String] = [], scrollOffset: Int = 0 ) {
    self.lines        = lines
    self.scrollOffset = scrollOffset
  }

  func append ( _ line: String ) {
    lines.append(line)
  }
}

struct TextView : Widget {
  var title  : String
  var buffer : ScrollBuffer

  init ( title: String, buffer: ScrollBuffer ) {
    self.title  = title
    self.buffer = buffer
  }

  func layout ( in context: LayoutContext ) -> WidgetLayoutResult {
    let bounds        = context.bounds
    let chrome        = Box(bounds: bounds, style: context.theme.windowChrome)
    let chromeContext = LayoutContext(bounds: bounds, theme: context.theme, focus: context.focus, environment: context.environment)
    let chromeLayout  = chrome.layout(in: chromeContext)
    var commands      = chromeLayout.commands

    let titleOrigin = (row: bounds.row, column: min(bounds.maxCol, bounds.column + 2))
    let titleWidget = Text(" \(title) ", origin: titleOrigin, style: context.theme.highlight)
    commands.append(contentsOf: titleWidget.layout(in: chromeContext).commands)

    let contentBounds = bounds.inset(by: EdgeInsets(top: 1, leading: 1, bottom: 1, trailing: 1))
    let visibleLines  = max(0, contentBounds.height)
    let startLine     = max(0, min(buffer.lines.count - visibleLines, buffer.scrollOffset))

    for rowOffset in 0..<visibleLines {
      let lineIndex = startLine + rowOffset
      guard lineIndex < buffer.lines.count else { break }
      let line = buffer.lines[lineIndex]

      for (columnOffset, character) in line.enumerated() where columnOffset < contentBounds.width {
        commands.append(
          RenderCommand(
            row   : contentBounds.row + rowOffset,
            column: contentBounds.column + columnOffset,
            tile  : SurfaceTile(
              character : character,
              attributes: context.theme.contentDefault
            )
          )
        )
      }
    }

    return WidgetLayoutResult(bounds: bounds, commands: commands)
  }
}

// MARK: - Split View

struct SplitView : Widget {
  enum Orientation {
    case vertical
    case horizontal
  }

  var orientation : Orientation
  var leading     : AnyWidget
  var trailing    : AnyWidget

  init <Leading: Widget, Trailing: Widget> ( orientation: Orientation, leading: Leading, trailing: Trailing ) {
    self.orientation = orientation
    self.leading     = AnyWidget(leading)
    self.trailing    = AnyWidget(trailing)
  }

  func layout ( in context: LayoutContext ) -> WidgetLayoutResult {
    var children = [WidgetLayoutResult]()

    switch orientation {
      case .vertical:
        let totalWidth    = max(0, context.bounds.width)
        let leadingWidth  = max(0, totalWidth / 2)
        let trailingWidth = max(0, totalWidth - leadingWidth)

        let leadingBounds  = BoxBounds(row: context.bounds.row, column: context.bounds.column, width: leadingWidth, height: context.bounds.height)
        let trailingBounds = BoxBounds(row: context.bounds.row, column: context.bounds.column + leadingWidth, width: trailingWidth, height: context.bounds.height)

        let leadingContext  = LayoutContext(bounds: leadingBounds, theme: context.theme, focus: context.focus, environment: context.environment)
        let trailingContext = LayoutContext(bounds: trailingBounds, theme: context.theme, focus: context.focus, environment: context.environment)

        children.append(leading.layout(in: leadingContext))
        children.append(trailing.layout(in: trailingContext))

      case .horizontal:
        let totalHeight    = max(0, context.bounds.height)
        let leadingHeight  = max(0, totalHeight / 2)
        let trailingHeight = max(0, totalHeight - leadingHeight)

        let leadingBounds  = BoxBounds(row: context.bounds.row, column: context.bounds.column, width: context.bounds.width, height: leadingHeight)
        let trailingBounds = BoxBounds(row: context.bounds.row + leadingHeight, column: context.bounds.column, width: context.bounds.width, height: trailingHeight)

        let leadingContext  = LayoutContext(bounds: leadingBounds, theme: context.theme, focus: context.focus, environment: context.environment)
        let trailingContext = LayoutContext(bounds: trailingBounds, theme: context.theme, focus: context.focus, environment: context.environment)

        children.append(leading.layout(in: leadingContext))
        children.append(trailing.layout(in: trailingContext))
    }

    return WidgetLayoutResult(bounds: context.bounds, children: children)
  }
}

// MARK: - Message Box

struct MessageBox : Widget {
  var title   : String
  var message : [String]
  var buttons : [String]

  init ( title: String, message: [String], buttons: [String] ) {
    self.title   = title
    self.message = message
    self.buttons = buttons
  }

  func layout ( in context: LayoutContext ) -> WidgetLayoutResult {
    let container    = context.bounds
    let messageWidth = message.map { $0.count }.max() ?? 0
    let buttonLine   = buttons.map { "[\($0)]" }.joined(separator: "  ")
    let titleWidth   = title.count + 2
    let contentWidth = max(messageWidth, buttonLine.count, titleWidth)
    let boxWidth     = max(12, min(container.width, contentWidth + 4))
    var boxHeight    = message.count + 4

    if buttons.isEmpty == false {
      boxHeight += 2
    }

    boxHeight = max(5, min(container.height, boxHeight))

    let rawBounds  = BoxBounds(row: container.row, column: container.column, width: boxWidth, height: boxHeight)
    let boxBounds  = rawBounds.aligned(horizontal: .center, vertical: .center, inside: container)
    let box        = Box(bounds: boxBounds, style: context.theme.windowChrome)
    let boxContext = LayoutContext(bounds: boxBounds, theme: context.theme, focus: context.focus, environment: context.environment)
    let boxLayout  = box.layout(in: boxContext)

    var commands = boxLayout.commands

    let titleOrigin = (row: boxBounds.row, column: min(boxBounds.maxCol - title.count + 1, boxBounds.column + 2))
    let titleWidget = Text(" \(title) ", origin: titleOrigin, style: context.theme.highlight)
    commands.append(contentsOf: titleWidget.layout(in: boxContext).commands)

    for (index, line) in message.enumerated() {
      let row         = boxBounds.row + 2 + index
      let clampedLine = String(line.prefix(max(0, boxBounds.width - 4)))
      let startColumn = boxBounds.column + 2

      for (offset, character) in clampedLine.enumerated() {
        commands.append(
          RenderCommand(
            row   : row,
            column: startColumn + offset,
            tile  : SurfaceTile(
              character : character,
              attributes: context.theme.contentDefault
            )
          )
        )
      }
    }

    if buttons.isEmpty == false {
      let row         = boxBounds.maxRow - 1
      let labels      = buttons.map { "[\($0)]" }
      let line        = labels.joined(separator: "  ")
      let clampedLine = String(line.prefix(max(0, boxBounds.width - 4)))
      let startColumn = boxBounds.column + max(2, (boxBounds.width - clampedLine.count) / 2 + 1)

      for (offset, character) in clampedLine.enumerated() {
        commands.append(
          RenderCommand(
            row   : row,
            column: startColumn + offset,
            tile  : SurfaceTile(
              character : character,
              attributes: context.theme.highlight
            )
          )
        )
      }
    }

    return WidgetLayoutResult(bounds: container, commands: commands)
  }
}

// MARK: - Application View

struct ApplicationView : Widget {
  var menuBar   : MenuBar?
  var content   : AnyWidget
  var statusBar : StatusBar?

  init ( menuBar: MenuBar? = nil, content: AnyWidget, statusBar: StatusBar? = nil ) {
    self.menuBar   = menuBar
    self.content   = content
    self.statusBar = statusBar
  }

  func layout ( in context: LayoutContext ) -> WidgetLayoutResult {
    var children      = [WidgetLayoutResult]()
    let rootBounds    = context.bounds
    var contentTop    = rootBounds.row
    var contentBottom = rootBounds.maxRow

    if let menuBar = menuBar {
      let menuBounds  = BoxBounds(row: rootBounds.row, column: rootBounds.column, width: rootBounds.width, height: 1)
      let menuContext = LayoutContext(bounds: menuBounds, theme: context.theme, focus: context.focus, environment: context.environment)
      children.append(menuBar.layout(in: menuContext))
      contentTop += 1
    }

    if let statusBar = statusBar {
      let statusBounds  = BoxBounds(row: rootBounds.maxRow, column: rootBounds.column, width: rootBounds.width, height: 1)
      let statusContext = LayoutContext(bounds: statusBounds, theme: context.theme, focus: context.focus, environment: context.environment)
      children.append(statusBar.layout(in: statusContext))
      contentBottom -= 1
    }

    if contentBottom < contentTop {
      contentBottom = contentTop
    }

    let contentHeight  = max(0, contentBottom - contentTop + 1)
    let contentBounds  = BoxBounds(row: contentTop, column: rootBounds.column, width: rootBounds.width, height: contentHeight)
    let contentContext = LayoutContext(bounds: contentBounds, theme: context.theme, focus: context.focus, environment: context.environment)
    children.append(content.layout(in: contentContext))

    return WidgetLayoutResult(bounds: rootBounds, children: children)
  }
}

// MARK: - Application Runtime

final class Application {
  enum Key {
    case control(Character)
    case function(Int)
  }

  private struct KeyBinding {
    var key     : Key
    var handler : () -> Void

    func matches ( event: KeyEvent ) -> Bool {
      switch key {
        case .control(let character):
          guard case .control(let control) = event.key else { return false }
          return KeyBinding.matches(control: control, character: character)

        case .function(let number):
          guard case .function(let function) = event.key else { return false }
          switch function {
            case .f(let value):
              return value == number
            default:
              return false
          }
      }
    }

    private static func matches ( control: TerminalInput.ControlKey, character: Character ) -> Bool {
      guard let scalar = String(character).uppercased().unicodeScalars.first else { return false }
      let value = scalar.value
      guard value >= 65 && value <= 90 else { return false }
      let controlByte = UInt8(value - 64)
      guard let expected = TerminalInput.ControlKey(byte: controlByte) else { return false }
      return expected == control
    }
  }

  private var theme       : Theme
  private var rootView    : ApplicationView
  private var scene       : Scene
  private var driver      : TerminalDriver
  private var keyBindings : [KeyBinding]
  private var overlays    : [AnyWidget]

  init ( menuBar: MenuBar? = nil, statusBar: StatusBar? = nil, content: SplitView, theme: Theme = .codex ) {
    self.theme       = theme
    self.rootView    = ApplicationView(menuBar: menuBar, content: AnyWidget(content), statusBar: statusBar)
    self.scene       = Scene(configuration: SceneConfiguration(theme: theme), rootWidget: AnyWidget(rootView))
    self.driver      = CodexTUI.makeDriver(scene: scene)
    self.keyBindings = []
    self.overlays    = []

    driver.onKeyEvent = { [weak self] event in
      self?.handle(keyEvent: event)
    }
  }

  func run () {
    driver.start()
    dispatchMain()
  }

  func stop () {
    driver.stop()
    exit(EXIT_SUCCESS)
  }

  func bind ( key: Key, handler: @escaping () -> Void ) {
    keyBindings.append(KeyBinding(key: key, handler: handler))
  }

  func present ( _ overlay: MessageBox ) {
    overlays = [AnyWidget(overlay)]
    scene.overlays = overlays
    driver.redraw()
  }

  private func dismissOverlays () {
    overlays.removeAll()
    scene.overlays = overlays
    driver.redraw()
  }

  private func handle ( keyEvent: KeyEvent ) {
    if overlays.isEmpty == false {
      if shouldDismissOverlay(for: keyEvent) {
        dismissOverlays()
        return
      }
    }

    for binding in keyBindings where binding.matches(event: keyEvent) {
      binding.handler()
      return
    }
  }

  private func shouldDismissOverlay ( for event: KeyEvent ) -> Bool {
    switch event.key {
      case .control(let control) where control == .RETURN:
        return true
      case .meta(let meta) where meta == .escape:
        return true
      default:
        return false
    }
  }
}

import Foundation
import TerminalInput

public struct MessageBoxButton {
  public let text          : String
  public let activationKey : TerminalInput.ControlKey
  public let handler       : (() -> Void)?

  public init ( text: String, activationKey: TerminalInput.ControlKey = .RETURN, handler: (() -> Void)? = nil ) {
    self.text          = text
    self.activationKey = activationKey
    self.handler       = handler
  }
}

// Renders a bordered message dialog with centred text and button row highlighting.
public struct MessageBox : Widget {
  public var title             : String
  public var messageLines      : [String]
  public var buttons           : [MessageBoxButton]
  public var activeButtonIndex : Int
  public var titleStyle        : ColorPair
  public var contentStyle      : ColorPair
  public var buttonStyle       : ColorPair
  public var highlightStyle    : ColorPair
  public var borderStyle       : ColorPair

  public init (
    title: String,
    messageLines: [String],
    buttons: [MessageBoxButton],
    activeButtonIndex: Int = 0,
    titleStyle: ColorPair,
    contentStyle: ColorPair,
    buttonStyle: ColorPair,
    highlightStyle: ColorPair,
    borderStyle: ColorPair
  ) {
    self.title             = title
    self.messageLines      = messageLines
    self.buttons           = buttons
    self.activeButtonIndex = activeButtonIndex
    self.titleStyle        = titleStyle
    self.contentStyle      = contentStyle
    self.buttonStyle       = buttonStyle
    self.highlightStyle    = highlightStyle
    self.borderStyle       = borderStyle
  }

  public func layout ( in context: LayoutContext ) -> WidgetLayoutResult {
    let surface = ModalDialogSurface.layout(
      in               : context,
      contentStyle     : contentStyle,
      borderStyle      : borderStyle,
      buttonTitles     : buttons.map { $0.text },
      activeButtonIndex: activeButtonIndex,
      buttonStyle      : buttonStyle,
      highlightStyle   : highlightStyle
    )

    var commands = surface.result.commands
    let children = surface.result.children
    let interior = surface.interior

    if interior.width <= 0 || interior.height <= 0 {
      return WidgetLayoutResult(bounds: context.bounds, commands: commands, children: children)
    }

    var currentRow = interior.row

    if title.isEmpty == false {
      renderCentered(text: title, row: currentRow, bounds: interior, style: titleStyle, commands: &commands)
      currentRow = min(currentRow + 1, interior.maxRow)
    }

    for line in messageLines {
      guard currentRow <= interior.maxRow else { break }
      renderCentered(text: line, row: currentRow, bounds: interior, style: contentStyle, commands: &commands)
      currentRow += 1
    }

    return WidgetLayoutResult(bounds: context.bounds, commands: commands, children: children)
  }

  private func renderCentered ( text: String, row: Int, bounds: BoxBounds, style: ColorPair, commands: inout [RenderCommand] ) {
    guard bounds.width > 0 else { return }
    let usableText = text.prefix(bounds.width)
    let offset     = max(0, (bounds.width - usableText.count) / 2)
    let start      = bounds.column + offset

    for (index, character) in usableText.enumerated() {
      commands.append(
        RenderCommand(
          row   : row,
          column: start + index,
          tile  : SurfaceTile(
            character : character,
            attributes: style
          )
        )
      )
    }
  }
}

public extension MessageBox {
  static func preferredSize ( title: String, messageLines: [String], buttons: [MessageBoxButton] ) -> (width: Int, height: Int) {
    let contentWidths = [title.count] + messageLines.map { $0.count }
    let maxContent    = contentWidths.max() ?? 0
    var contentHeight = 0
    if title.isEmpty == false { contentHeight += 1 }
    contentHeight += messageLines.count

    return ModalDialogSurface.preferredSize(
      contentWidth : maxContent,
      contentHeight: contentHeight,
      buttonTitles : buttons.map { $0.text }
    )
  }

  static func centeredBounds ( title: String, messageLines: [String], buttons: [MessageBoxButton], in container: BoxBounds ) -> BoxBounds {
    let contentWidths = [title.count] + messageLines.map { $0.count }
    let maxContent    = contentWidths.max() ?? 0
    var contentHeight = 0
    if title.isEmpty == false { contentHeight += 1 }
    contentHeight += messageLines.count

    return ModalDialogSurface.centeredBounds(
      contentWidth : maxContent,
      contentHeight: contentHeight,
      buttonTitles : buttons.map { $0.text },
      in           : container
    )
  }
}

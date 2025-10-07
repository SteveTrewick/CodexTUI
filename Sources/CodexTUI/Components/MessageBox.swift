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
  public var messageLineStyles : [ColorPair?]
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
    messageLineStyles: [ColorPair?] = [],
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
    self.messageLineStyles = messageLineStyles
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

    var commands  = surface.result.commands
    let children  = surface.result.children
    let interior  = surface.interior
    let buttonRow = surface.buttonRow ?? interior.maxRow

    if interior.width <= 0 || interior.height <= 0 {
      return WidgetLayoutResult(bounds: context.bounds, commands: commands, children: children)
    }

    if title.isEmpty == false {
      renderCentered(text: title, row: interior.row, bounds: interior, style: titleStyle, commands: &commands)
    }

    let contentTop    = title.isEmpty ? interior.row : interior.row + 1
    let clampedTop    = min(contentTop, interior.maxRow)
    let contentBottom = buttons.isEmpty ? interior.maxRow : min(interior.maxRow, buttonRow - 1)
    let contentHeight = contentBottom - clampedTop + 1

    if contentHeight > 0 && interior.width > 0 {
      let contentBounds   = BoxBounds(row: clampedTop, column: interior.column, width: interior.width, height: contentHeight)
      let contentInterior = contentBounds.inset(by: EdgeInsets(top: 1, leading: 1, bottom: 1, trailing: 1))

      if contentInterior.height > 0 && contentInterior.width > 0 {
        let contentBox      = Box(bounds: contentBounds, style: borderStyle)
        let contentCommands = contentBox.layout(in: context).commands
        commands.append(contentsOf: contentCommands)

        var currentRow = contentInterior.row

        for (index, line) in messageLines.enumerated() {
          guard currentRow <= contentInterior.maxRow else { break }
          let style = styleForMessageLine(at: index)
          renderCentered(text: line, row: currentRow, bounds: contentInterior, style: style, commands: &commands)
          currentRow += 1
        }
      }
    }

    return WidgetLayoutResult(bounds: context.bounds, commands: commands, children: children)
  }

  private func styleForMessageLine ( at index: Int ) -> ColorPair {
    guard messageLineStyles.isEmpty == false else { return contentStyle }
    guard index < messageLineStyles.count else { return contentStyle }
    return messageLineStyles[index] ?? contentStyle
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
    let maxContent    = (contentWidths.max() ?? 0) + 2
    var contentHeight = 0
    if title.isEmpty == false { contentHeight += 1 }
    contentHeight += messageLines.count
    contentHeight += 2

    return ModalDialogSurface.preferredSize(
      contentWidth : maxContent,
      contentHeight: contentHeight,
      buttonTitles : buttons.map { $0.text }
    )
  }

  static func centeredBounds ( title: String, messageLines: [String], buttons: [MessageBoxButton], in container: BoxBounds ) -> BoxBounds {
    let contentWidths = [title.count] + messageLines.map { $0.count }
    let maxContent    = (contentWidths.max() ?? 0) + 2
    var contentHeight = 0
    if title.isEmpty == false { contentHeight += 1 }
    contentHeight += messageLines.count
    contentHeight += 2

    return ModalDialogSurface.centeredBounds(
      contentWidth : maxContent,
      contentHeight: contentHeight,
      buttonTitles : buttons.map { $0.text },
      in           : container
    )
  }
}

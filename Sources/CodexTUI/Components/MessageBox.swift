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
  public var contentStyle      : ColorPair
  public var buttonStyle       : ColorPair
  public var highlightStyle    : ColorPair
  public var borderStyle       : ColorPair

  public init (
    title: String,
    messageLines: [String],
    buttons: [MessageBoxButton],
    activeButtonIndex: Int = 0,
    contentStyle: ColorPair,
    buttonStyle: ColorPair,
    highlightStyle: ColorPair,
    borderStyle: ColorPair
  ) {
    self.title             = title
    self.messageLines      = messageLines
    self.buttons           = buttons
    self.activeButtonIndex = activeButtonIndex
    self.contentStyle      = contentStyle
    self.buttonStyle       = buttonStyle
    self.highlightStyle    = highlightStyle
    self.borderStyle       = borderStyle
  }

  public func layout ( in context: LayoutContext ) -> WidgetLayoutResult {
    let bounds        = context.bounds
    let box           = Box(bounds: bounds, style: borderStyle)
    let boxLayout     = box.layout(in: context)
    var commands      = boxLayout.commands
    let children      = boxLayout.children
    let interior      = bounds.inset(by: EdgeInsets(top: 1, leading: 1, bottom: 1, trailing: 1))

    if interior.width <= 0 || interior.height <= 0 {
      return WidgetLayoutResult(bounds: bounds, commands: commands, children: children)
    }

    for row in interior.row...interior.maxRow {
      for column in interior.column...interior.maxCol {
        commands.append(
          RenderCommand(
            row   : row,
            column: column,
            tile  : SurfaceTile(
              character : " ",
              attributes: contentStyle
            )
          )
        )
      }
    }

    var currentRow = interior.row

    if title.isEmpty == false {
      renderCentered(text: title, row: currentRow, bounds: interior, style: highlightStyle, commands: &commands)
      currentRow = min(currentRow + 1, interior.maxRow)
    }

    for line in messageLines {
      guard currentRow <= interior.maxRow else { break }
      renderCentered(text: line, row: currentRow, bounds: interior, style: contentStyle, commands: &commands)
      currentRow += 1
    }

    if buttons.isEmpty == false {
      let buttonRow = interior.maxRow
      renderButtons(row: buttonRow, bounds: interior, commands: &commands)
    }

    return WidgetLayoutResult(bounds: bounds, commands: commands, children: children)
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

  private func renderButtons ( row: Int, bounds: BoxBounds, commands: inout [RenderCommand] ) {
    guard bounds.width > 0 else { return }
    var buttonStrings = [String]()
    buttonStrings.reserveCapacity(buttons.count)

    for button in buttons {
      let padded = " \(button.text) "
      buttonStrings.append(String(padded.prefix(bounds.width)))
    }

    let totalWidth = buttonStrings.reduce(0) { $0 + $1.count } + max(0, buttons.count - 1)
    let offset     = max(0, (bounds.width - totalWidth) / 2)
    var column     = bounds.column + offset
    let maxIndex   = max(0, buttons.count - 1)
    let highlight  = max(0, min(activeButtonIndex, maxIndex))

    for (index, string) in buttonStrings.enumerated() {
      let attributes = index == highlight ? highlightStyle : buttonStyle
      for character in string {
        guard column <= bounds.maxCol else { break }
        commands.append(
          RenderCommand(
            row   : row,
            column: column,
            tile  : SurfaceTile(
              character : character,
              attributes: attributes
            )
          )
        )
        column += 1
      }

      if index < buttonStrings.count - 1 {
        if column <= bounds.maxCol {
          commands.append(
            RenderCommand(
              row   : row,
              column: column,
              tile  : SurfaceTile(
                character : " ",
                attributes: contentStyle
              )
            )
          )
        }
        column += 1
      }
    }
  }
}

public extension MessageBox {
  static func preferredSize ( title: String, messageLines: [String], buttons: [MessageBoxButton] ) -> (width: Int, height: Int) {
    let contentWidths = [title.count] + messageLines.map { $0.count }
    let maxContent    = contentWidths.max() ?? 0

    let buttonWidths  = buttons.map { $0.text.count + 2 }
    let buttonTotal   = buttonWidths.reduce(0, +) + max(0, buttons.count - 1)
    let interiorWidth = max(maxContent, buttonTotal)
    let width         = max(8, interiorWidth + 2)

    var interiorHeight = 0
    if title.isEmpty == false { interiorHeight += 1 }
    interiorHeight += messageLines.count
    if buttons.isEmpty == false {
      if interiorHeight == 0 { interiorHeight = 1 }
      interiorHeight += 1
      interiorHeight += 1
    }

    let height = max(4, interiorHeight + 2)
    return (width, height)
  }

  static func centeredBounds ( title: String, messageLines: [String], buttons: [MessageBoxButton], in container: BoxBounds ) -> BoxBounds {
    let size   = preferredSize(title: title, messageLines: messageLines, buttons: buttons)
    let width  = min(size.width, container.width)
    let height = min(size.height, container.height)
    let bounds = BoxBounds(row: 1, column: 1, width: width, height: height)
    return bounds.aligned(horizontal: .center, vertical: .center, inside: container)
  }
}

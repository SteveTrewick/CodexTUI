import Foundation

public enum StatusItemAlignment {
  case leading
  case trailing
}

// Simple descriptor used to render text segments inside the status bar.
public struct StatusItem : Equatable {
  public var text      : String
  public var alignment : StatusItemAlignment

  public init ( text: String, alignment: StatusItemAlignment = .leading ) {
    self.text      = text
    self.alignment = alignment
  }
}

// Renders a single line status bar with left/right aligned segments.
public struct StatusBar : Widget {
  public var items : [StatusItem]
  public var style : ColorPair

  public init ( items: [StatusItem], style: ColorPair ) {
    self.items = items
    self.style = style
  }

  public func layout ( in context: LayoutContext ) -> WidgetLayoutResult {
    var commands = [RenderCommand]()
    let row      = context.bounds.maxRow

    var leftColumn  = context.bounds.column
    var rightColumn = context.bounds.maxCol

    // Leading items push characters from the left edge.
    for item in items where item.alignment == .leading {
      commands.append(contentsOf: render(item: item, row: row, column: leftColumn))
      leftColumn += item.text.count + 1
    }

    // Trailing items render in reverse order to avoid overlapping as we walk from right to left.
    for item in items.reversed() where item.alignment == .trailing {
      rightColumn -= item.text.count
      commands.append(contentsOf: render(item: item, row: row, column: rightColumn))
      rightColumn -= 1
    }

    return WidgetLayoutResult(bounds: BoxBounds(row: row, column: context.bounds.column, width: context.bounds.width, height: 1), commands: commands)
  }

  private func render ( item: StatusItem, row: Int, column: Int ) -> [RenderCommand] {
    var commands = [RenderCommand]()

    for (offset, character) in item.text.enumerated() {
      commands.append(
        RenderCommand(
          row   : row,
          column: column + offset,
          tile  : SurfaceTile(
            character : character,
            attributes: style
          )
        )
      )
    }

    return commands
  }
}

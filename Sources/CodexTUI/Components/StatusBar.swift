import Foundation

/// Alignment strategy controlling where a status bar item is rendered. Leading items expand from the
/// left edge while trailing items pack tightly against the right edge.
public enum StatusItemAlignment {
  case leading
  case trailing
}

/// Describes a single textual segment in the status bar along with its alignment policy.
public struct StatusItem : Equatable {
  public var text      : String
  public var alignment : StatusItemAlignment

  public init ( text: String, alignment: StatusItemAlignment = .leading ) {
    self.text      = text
    self.alignment = alignment
  }
}

/// Widget that renders a single-line status bar with left and right aligned segments. The
/// implementation mirrors the menu bar so menus and status bars feel visually consistent.
public struct StatusBar : Widget {
  public var items : [StatusItem]
  public var style : ColorPair

  public init ( items: [StatusItem], style: ColorPair ) {
    self.items = items
    self.style = style
  }

  /// Renders the status bar along the bottom edge of the provided bounds. The function first clears
  /// the row with the default style, then streams leading items from the left and trailing items from
  /// the right, adjusting cursors as it goes. Processing the trailing items in reverse ensures their
  /// text never overlaps despite not precomputing widths up front.
  public func layout ( in context: LayoutContext ) -> WidgetLayoutResult {
    let row          = context.bounds.maxRow
    let startColumn  = context.bounds.column
    let endColumn    = context.bounds.maxCol
    var commands     = [RenderCommand]()
    var leftColumn   = startColumn
    var rightColumn  = context.bounds.maxCol + 1

    if startColumn <= endColumn {
      for column in startColumn...endColumn {
        commands.append(
          RenderCommand(
            row   : row,
            column: column,
            tile  : SurfaceTile(
              character : " ",
              attributes: style
            )
          )
        )
      }
    }

    // Leading items push characters from the left edge.
    for item in items where item.alignment == .leading {
      commands.append(contentsOf: render(item: item, row: row, column: leftColumn))
      leftColumn += item.text.count + 1
    }

    // Trailing items render in reverse order to avoid overlapping as we walk from right to left.
    for item in items.reversed() where item.alignment == .trailing {
      let start = rightColumn - item.text.count
      commands.append(contentsOf: render(item: item, row: row, column: start))
      rightColumn = start - 1
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

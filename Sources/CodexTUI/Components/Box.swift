import Foundation

// Draws a rectangular border using box drawing characters.
public struct Box : Widget {
  public var bounds : BoxBounds
  public var style  : ColorPair

  public init ( bounds: BoxBounds, style: ColorPair = ColorPair() ) {
    self.bounds  = bounds
    self.style   = style
  }

  public func layout ( in context: LayoutContext ) -> WidgetLayoutResult {
    var commands = [RenderCommand]()

    // First paint the horizontal edges. The helper produces junction characters when the
    // box overlaps with other boxes on the same tile which keeps the ASCII art tidy.
    for column in bounds.column...(bounds.column + bounds.width - 1) {
      commands.append(
        RenderCommand(
          row   : bounds.row,
          column: column,
          tile  : SurfaceTile(
            character : horizontalLine(for: column),
            attributes: style
          )
        )
      )
      commands.append(
        RenderCommand(
          row   : bounds.maxRow,
          column: column,
          tile  : SurfaceTile(
            character : horizontalLine(for: column),
            attributes: style
          )
        )
      )
    }

    // Then paint the vertical edges, again substituting junction characters at the corners.
    for row in bounds.row...(bounds.row + bounds.height - 1) {
      commands.append(
        RenderCommand(
          row   : row,
          column: bounds.column,
          tile  : SurfaceTile(
            character : verticalLine(for: row),
            attributes: style
          )
        )
      )
      commands.append(
        RenderCommand(
          row   : row,
          column: bounds.maxCol,
          tile  : SurfaceTile(
            character : verticalLine(for: row),
            attributes: style
          )
        )
      )
    }

    // Finally emit explicit corner glyphs to ensure consistent visuals regardless of the
    // characters chosen by the horizontal/vertical helpers.
    commands.append(
      RenderCommand(
        row   : bounds.row,
        column: bounds.column,
        tile  : SurfaceTile(
          character : "┌",
          attributes: style
        )
      )
    )
    commands.append(
      RenderCommand(
        row   : bounds.row,
        column: bounds.maxCol,
        tile  : SurfaceTile(
          character : "┐",
          attributes: style
        )
      )
    )
    commands.append(
      RenderCommand(
        row   : bounds.maxRow,
        column: bounds.column,
        tile  : SurfaceTile(
          character : "└",
          attributes: style
        )
      )
    )
    commands.append(
      RenderCommand(
        row   : bounds.maxRow,
        column: bounds.maxCol,
        tile  : SurfaceTile(
          character : "┘",
          attributes: style
        )
      )
    )

    return WidgetLayoutResult(bounds: bounds, commands: commands)
  }

  // Chooses an appropriate character for the top/bottom edges.
  private func horizontalLine ( for column: Int ) -> Character {
    if column == bounds.column || column == bounds.maxCol { return "┼" }
    return "─"
  }

  // Chooses an appropriate character for the left/right edges.
  private func verticalLine ( for row: Int ) -> Character {
    if row == bounds.row || row == bounds.maxRow { return "┼" }
    return "│"
  }
}

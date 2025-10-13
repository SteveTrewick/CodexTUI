import Foundation

/// Primitive widget that paints an ANSI box border. The type is used both directly by scenes and
/// as a building block for higher-level surfaces such as modal dialogs or selection lists.
public struct Box : Widget {
  public var explicitBounds : BoxBounds?
  public var style          : ColorPair

  public init ( bounds: BoxBounds, style: ColorPair = ColorPair() ) {
    self.explicitBounds = bounds
    self.style          = style
  }

  public init ( style: ColorPair = ColorPair() ) {
    self.explicitBounds = nil
    self.style          = style
  }

  /// Produces the render commands required to trace the four edges of the box. The routine walks
  /// horizontally first to fill the top and bottom edges, then vertically to cover the sides. Each
  /// loop appends `RenderCommand` values describing the character and styling for a cell so the
  /// renderer can correctly resolve junctions when multiple boxes overlap. Corner glyphs are added
  /// explicitly at the end to ensure the final appearance is deterministic regardless of the helper
  /// character decisions.
  public func layout ( in context: LayoutContext ) -> WidgetLayoutResult {
    let bounds = explicitBounds ?? context.bounds

    guard bounds.width > 0 && bounds.height > 0 else {
      return WidgetLayoutResult(bounds: bounds)
    }

    var commands = [RenderCommand]()

    // First paint the horizontal edges. The helper produces junction characters when the
    // box overlaps with other boxes on the same tile which keeps the ASCII art tidy.
    for column in bounds.column...(bounds.column + bounds.width - 1) {
      commands.append(
        RenderCommand(
          row   : bounds.row,
          column: column,
          tile  : SurfaceTile(
            character : horizontalLine(for: column, in: bounds),
            attributes: style
          )
        )
      )
      commands.append(
        RenderCommand(
          row   : bounds.maxRow,
          column: column,
          tile  : SurfaceTile(
            character : horizontalLine(for: column, in: bounds),
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
            character : verticalLine(for: row, in: bounds),
            attributes: style
          )
        )
      )
      commands.append(
        RenderCommand(
          row   : row,
          column: bounds.maxCol,
          tile  : SurfaceTile(
            character : verticalLine(for: row, in: bounds),
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
  private func horizontalLine ( for column: Int, in bounds: BoxBounds ) -> Character {
    if column == bounds.column || column == bounds.maxCol { return "┼" }
    return "─"
  }

  // Chooses an appropriate character for the left/right edges.
  private func verticalLine ( for row: Int, in bounds: BoxBounds ) -> Character {
    if row == bounds.row || row == bounds.maxRow { return "┼" }
    return "│"
  }
}

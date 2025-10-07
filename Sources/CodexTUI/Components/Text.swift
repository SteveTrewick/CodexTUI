import Foundation

/// Minimal widget that renders an immutable string starting at a fixed origin. It is typically used
/// for labels inside other composite widgets.
public struct Text : Widget {
  public var content : String
  public var origin  : (row: Int, column: Int)
  public var style   : ColorPair

  public init ( _ content: String, origin: (row: Int, column: Int), style: ColorPair = ColorPair() ) {
    self.content  = content
    self.origin   = origin
    self.style    = style
  }

  /// Emits a render command for each character in the string. The bounds are derived from the
  /// configured origin and the string length so parent widgets can include the text when computing
  /// their own sizes or hit testing logic.
  public func layout ( in context: LayoutContext ) -> WidgetLayoutResult {
    let bounds = BoxBounds(row: origin.row, column: origin.column, width: content.count, height: 1)
    var commands = [RenderCommand]()
    commands.reserveCapacity(content.count)

    // Emit a command for every character so the renderer can treat the text like any other widget output.
    for (offset, character) in content.enumerated() {
      commands.append(
        RenderCommand(
          row   : origin.row,
          column: origin.column + offset,
          tile  : SurfaceTile(
            character : character,
            attributes: style
          )
        )
      )
    }

    return WidgetLayoutResult(bounds: bounds, commands: commands)
  }
}

import Foundation

public struct Text : Widget {
  public var content : String
  public var origin  : (row: Int, column: Int)
  public var style   : ColorPair

  public init ( _ content: String, origin: (row: Int, column: Int), style: ColorPair = ColorPair() ) {
    self.content  = content
    self.origin   = origin
    self.style    = style
  }

  public func layout ( in context: LayoutContext ) -> WidgetLayoutResult {
    let bounds = BoxBounds(row: origin.row, column: origin.column, width: content.count, height: 1)
    var commands = [RenderCommand]()
    commands.reserveCapacity(content.count)

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

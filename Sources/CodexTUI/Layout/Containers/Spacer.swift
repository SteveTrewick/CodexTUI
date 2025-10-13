import Foundation

public struct Spacer : Widget {
  public var minLength : Int

  public init ( minLength: Int = 0 ) {
    self.minLength = minLength
  }

  public func layout ( in context: LayoutContext ) -> WidgetLayoutResult {
    let height = max(minLength, context.bounds.height)
    let bounds = BoxBounds(
      row    : context.bounds.row,
      column : context.bounds.column,
      width  : context.bounds.width,
      height : height
    )

    return WidgetLayoutResult(bounds: bounds)
  }
}

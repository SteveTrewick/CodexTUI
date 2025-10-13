import Foundation

public struct VStack : Widget {
  public var spacing  : Int
  public var children : [AnyWidget]

  public init ( spacing: Int = 0, @WidgetBuilder content: () -> [AnyWidget] ) {
    self.spacing  = spacing
    self.children = content()
  }

  public func layout ( in context: LayoutContext ) -> WidgetLayoutResult {
    guard context.bounds.height > 0 else {
      return WidgetLayoutResult(bounds: context.bounds)
    }

    var cursorRow = context.bounds.row
    let maxRow    = context.bounds.maxRow
    var layouts   = [WidgetLayoutResult]()
    layouts.reserveCapacity(children.count)

    for (index, child) in children.enumerated() {
      guard cursorRow <= maxRow else { break }

      let remainingHeight = max(0, maxRow - cursorRow + 1)
      guard remainingHeight > 0 else { break }

      let childBounds = BoxBounds(
        row    : cursorRow,
        column : context.bounds.column,
        width  : context.bounds.width,
        height : remainingHeight
      )

      var childContext = context
      childContext.bounds = childBounds

      let layout = child.layout(in: childContext)
      layouts.append(layout)

      let consumedHeight = layout.bounds.height
      let nextRow        = layout.bounds.maxRow + 1

      if consumedHeight <= 0 {
        cursorRow = min(maxRow + 1, cursorRow + 1)
      } else {
        let proposed = max(cursorRow + consumedHeight, nextRow)
        cursorRow    = min(maxRow + 1, proposed)
      }

      if index < children.count - 1 {
        cursorRow = min(maxRow + 1, cursorRow + spacing)
      }
    }

    return WidgetLayoutResult(bounds: context.bounds, children: layouts)
  }
}

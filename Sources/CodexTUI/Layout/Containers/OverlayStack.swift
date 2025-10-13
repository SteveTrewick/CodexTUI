import Foundation

public struct OverlayStack : Widget {
  public var children : [AnyWidget]

  public init ( @WidgetBuilder _ content: () -> [AnyWidget] ) {
    self.children = content()
  }

  public init ( children: [AnyWidget] ) {
    self.children = children
  }

  public func layout ( in context: LayoutContext ) -> WidgetLayoutResult {
    var layouts = [WidgetLayoutResult]()
    layouts.reserveCapacity(children.count)

    for child in children {
      layouts.append(child.layout(in: context))
    }

    return WidgetLayoutResult(bounds: context.bounds, children: layouts)
  }
}

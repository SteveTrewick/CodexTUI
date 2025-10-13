import Foundation

public protocol ComposableWidget : Widget {
  associatedtype Body : Widget
  var body : Body { get }
}

public extension ComposableWidget {
  func layout ( in context: LayoutContext ) -> WidgetLayoutResult {
    return body.layout(in: context)
  }
}

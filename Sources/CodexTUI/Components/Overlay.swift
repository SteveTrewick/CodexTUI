import Foundation

/// Widget that places its child at explicit bounds regardless of the parent layout flow. Scenes use
/// it to present overlays such as modals or floating tooltips while reusing the existing widget
/// infrastructure.
public struct Overlay : Widget {
  public var content : AnyWidget
  public var bounds  : BoxBounds

  public init ( bounds: BoxBounds, content: AnyWidget ) {
    self.bounds  = bounds
    self.content = content
  }

  /// Forwards layout to the wrapped content using the overlay's fixed bounds. Because overlays live
  /// in a separate coordinate space from their parent, we synthesise a new `LayoutContext` that
  /// preserves the theme, focus snapshot and environment so the child renders consistently with the
  /// rest of the scene.
  public func layout ( in context: LayoutContext ) -> WidgetLayoutResult {
    let childContext = LayoutContext(bounds: bounds, theme: context.theme, focus: context.focus, environment: context.environment)
    let childLayout  = content.layout(in: childContext)
    return WidgetLayoutResult(bounds: bounds, commands: childLayout.commands, children: childLayout.children)
  }
}

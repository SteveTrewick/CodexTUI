import Foundation

/// Atomic instruction describing how to mutate a single tile on the backing surface. Widgets emit
/// a stream of commands during layout and the renderer later applies them to the framebuffer.
public struct RenderCommand : Equatable {
  public var row    : Int
  public var column : Int
  public var tile   : SurfaceTile

  public init ( row: Int, column: Int, tile: SurfaceTile ) {
    self.row    = row
    self.column = column
    self.tile   = tile
  }
}

/// Output of a widget layout pass. It captures the widget's occupied bounds, the commands required
/// to draw its content and the layout results of any nested child widgets so the render order can be
/// preserved.
public struct WidgetLayoutResult {
  public var bounds   : BoxBounds
  public var commands : [RenderCommand]
  public var children : [WidgetLayoutResult]

  public init ( bounds: BoxBounds, commands: [RenderCommand] = [], children: [WidgetLayoutResult] = [] ) {
    self.bounds   = bounds
    self.commands = commands
    self.children = children
  }

  /// Recursively collects the commands produced by the widget and its children, returning them in
  /// depth-first order so parents always render before descendants. This mirrors the natural paint
  /// order of immediate mode rendering.
  public func flattenedCommands () -> [RenderCommand] {
    var combined = commands

    for child in children {
      combined.append(contentsOf: child.flattenedCommands())
    }

    return combined
  }
}

/// Core protocol adopted by every renderable component. Implementations receive a `LayoutContext`
/// describing their available space and return a `WidgetLayoutResult` detailing the commands required
/// to draw themselves.
public protocol Widget {
  func layout ( in context: LayoutContext ) -> WidgetLayoutResult
}

public extension Widget {
  func eraseToAnyWidget () -> AnyWidget {
    return AnyWidget(self)
  }
}

/// Type eraser that allows heterogeneous widget hierarchies. It stores the layout closure of the
/// underlying widget and forwards invocations without exposing the concrete type to callers.
public struct AnyWidget : Widget {
  private let layoutClosure : (LayoutContext) -> WidgetLayoutResult

  public init <Wrapped: Widget> ( _ wrapped: Wrapped ) {
    self.layoutClosure = wrapped.layout(in:)
  }

  /// Forwards the layout request to the wrapped widget. Using a stored closure keeps the type eraser
  /// lightweight while still allowing the protocol requirement to be satisfied.
  public func layout ( in context: LayoutContext ) -> WidgetLayoutResult {
    return layoutClosure(context)
  }
}

/// Protocol adopted by widgets that participate in focus traversal. The additional requirements make
/// it possible for the focus chain to register, enable and identify interactive elements.
public protocol FocusableWidget : Widget {
  var focusIdentifier : FocusIdentifier { get }
  func focusNode () -> FocusNode
}

/// Protocol adopted by widgets that can present overlay widgets such as modal dialogs. Returning an
/// array allows the runtime to render multiple overlays in front of the base scene content.
public protocol OverlayPresentingWidget : Widget {
  var presentedOverlays : [AnyWidget] { get }
}

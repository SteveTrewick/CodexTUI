import Foundation

// Atomic instruction describing a single tile mutation on the surface.
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

// Layout output produced by widgets, including their own commands and any nested child layouts.
public struct WidgetLayoutResult {
  public var bounds   : BoxBounds
  public var commands : [RenderCommand]
  public var children : [WidgetLayoutResult]

  public init ( bounds: BoxBounds, commands: [RenderCommand] = [], children: [WidgetLayoutResult] = [] ) {
    self.bounds   = bounds
    self.commands = commands
    self.children = children
  }

  // Recursively collects all commands from the subtree preserving draw order.
  public func flattenedCommands () -> [RenderCommand] {
    var combined = commands

    for child in children {
      combined.append(contentsOf: child.flattenedCommands())
    }

    return combined
  }
}

// Core protocol implemented by all renderable components.
public protocol Widget {
  func layout ( in context: LayoutContext ) -> WidgetLayoutResult
}

// Type erasure that allows heterogeneous widget trees.
public struct AnyWidget : Widget {
  private let layoutClosure : (LayoutContext) -> WidgetLayoutResult

  public init <Wrapped: Widget> ( _ wrapped: Wrapped ) {
    self.layoutClosure = wrapped.layout(in:)
  }

  public func layout ( in context: LayoutContext ) -> WidgetLayoutResult {
    return layoutClosure(context)
  }
}

// Protocol for widgets that participate in the focus chain.
public protocol FocusableWidget : Widget {
  var focusIdentifier : FocusIdentifier { get }
  func focusNode () -> FocusNode
}

// Protocol adopted by widgets capable of presenting overlays.
public protocol OverlayPresentingWidget : Widget {
  var presentedOverlays : [AnyWidget] { get }
}

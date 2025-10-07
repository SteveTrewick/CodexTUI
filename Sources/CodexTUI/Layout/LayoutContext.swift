import Foundation

/// Bundles the information a widget requires to perform layout: its assigned bounds, the active
/// theme palette, the focus snapshot and any auxiliary environment values derived from the
/// surrounding scene. Passing a single value keeps the layout signatures terse while still
/// conveying everything a widget needs to make sizing and styling decisions.
public struct LayoutContext {
  public var bounds       : BoxBounds
  public var theme        : Theme
  public var focus        : FocusChain.Snapshot
  public var environment  : EnvironmentValues

  /// Creates a context for a specific widget. The environment defaults mirror the standard
  /// scene configuration so most widgets can opt-in to additional values only when necessary.
  public init ( bounds: BoxBounds, theme: Theme, focus: FocusChain.Snapshot, environment: EnvironmentValues = EnvironmentValues() ) {
    self.bounds      = bounds
    self.theme       = theme
    self.focus       = focus
    self.environment = environment
  }
}

/// Extra knobs surfaced to layout routines that describe global chrome such as menu/status bar
/// heights and any content padding the scaffold applies. The container updates these values when
/// composing nested contexts so children can react without recomputing their ancestors' state.
public struct EnvironmentValues {
  public var menuBarHeight   : Int
  public var statusBarHeight : Int
  public var contentInsets   : EdgeInsets

  /// Constructs a new collection of environment values. Default arguments provide sensible
  /// platform-friendly values so callers only override the properties that are relevant to the
  /// current subtree.
  public init ( menuBarHeight: Int = 1, statusBarHeight: Int = 1, contentInsets: EdgeInsets = EdgeInsets() ) {
    self.menuBarHeight   = menuBarHeight
    self.statusBarHeight = statusBarHeight
    self.contentInsets   = contentInsets
  }
}

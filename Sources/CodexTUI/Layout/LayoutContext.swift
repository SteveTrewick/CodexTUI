import Foundation

// Captures the contextual information widgets require to calculate geometry and styling.
public struct LayoutContext {
  public var bounds       : BoxBounds
  public var theme        : Theme
  public var focus        : FocusChain.Snapshot
  public var environment  : EnvironmentValues

  public init ( bounds: BoxBounds, theme: Theme, focus: FocusChain.Snapshot, environment: EnvironmentValues = EnvironmentValues() ) {
    self.bounds      = bounds
    self.theme       = theme
    self.focus       = focus
    self.environment = environment
  }
}

// Additional environmental values surfaced to widgets during layout.
public struct EnvironmentValues {
  public var menuBarHeight   : Int
  public var statusBarHeight : Int
  public var contentInsets   : EdgeInsets

  public init ( menuBarHeight: Int = 1, statusBarHeight: Int = 1, contentInsets: EdgeInsets = EdgeInsets() ) {
    self.menuBarHeight   = menuBarHeight
    self.statusBarHeight = statusBarHeight
    self.contentInsets   = contentInsets
  }
}

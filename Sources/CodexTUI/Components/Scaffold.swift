import Foundation

/// Composite widget that arranges an optional menu bar, primary content region and optional status
/// bar into a vertical stack. It provides the canonical scene layout used by the demo and runtime.
public struct Scaffold : Widget {
  public var menuBar   : MenuBar?
  public var content   : AnyWidget
  public var statusBar : StatusBar?

  public init ( menuBar: MenuBar? = nil, content: AnyWidget, statusBar: StatusBar? = nil ) {
    self.menuBar   = menuBar
    self.content   = content
    self.statusBar = statusBar
  }

  /// Splits the available bounds into up to three vertical slices. The routine reserves the first row
  /// for the menu bar when present, the last row for the status bar, then assigns the remaining space
  /// to the content widget. Each child receives its own `LayoutContext` so environment information such
  /// as theme and focus snapshot flow naturally through the tree.
  public func layout ( in context: LayoutContext ) -> WidgetLayoutResult {
    let menuHeight   = menuBar == nil ? 0 : context.environment.menuBarHeight
    let statusHeight = statusBar == nil ? 0 : context.environment.statusBarHeight

    let structure = Split(
      axis      : .vertical,
      firstSize : .fixed(menuHeight),
      secondSize: .flexible,
      first     : {
        if let menuBar = menuBar {
          menuBar
        } else if menuHeight > 0 {
          Spacer(minLength: menuHeight)
        }
      },
      second    : {
        Split(
          axis      : .vertical,
          firstSize : .flexible,
          secondSize: .fixed(statusHeight),
          first     : { content },
          second    : {
            if let statusBar = statusBar {
              statusBar
            } else if statusHeight > 0 {
              Spacer(minLength: statusHeight)
            }
          }
        )
      }
    )

    return structure.layout(in: context)
  }
}

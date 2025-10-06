import Foundation
import TerminalOutput

public struct SceneConfiguration {
  public var theme        : Theme
  public var environment  : EnvironmentValues
  public var showMenuBar  : Bool
  public var showStatusBar: Bool

  public init ( theme: Theme = .codex, environment: EnvironmentValues = EnvironmentValues(), showMenuBar: Bool = true, showStatusBar: Bool = true ) {
    self.theme         = theme
    self.environment   = environment
    self.showMenuBar   = showMenuBar
    self.showStatusBar = showStatusBar
  }
}

public final class Scene {
  public var configuration : SceneConfiguration
  public var focusChain    : FocusChain
  public var rootWidget    : AnyWidget
  public var overlays      : [AnyWidget]

  public init ( configuration: SceneConfiguration = SceneConfiguration(), focusChain: FocusChain = FocusChain(), rootWidget: AnyWidget, overlays: [AnyWidget] = [] ) {
    self.configuration = configuration
    self.focusChain    = focusChain
    self.rootWidget    = rootWidget
    self.overlays      = overlays
  }

  public func registerFocusable ( _ widget: FocusableWidget ) {
    focusChain.register(node: widget.focusNode())
  }

  public func layoutContext ( for bounds: BoxBounds ) -> LayoutContext {
    return LayoutContext(bounds: bounds, theme: configuration.theme, focus: focusChain.snapshot(), environment: configuration.environment)
  }

  public func render ( into surface: inout Surface, bounds: BoxBounds ) -> [AnsiSequence] {
    surface.beginFrame()
    surface.resize(
      width  : bounds.width,
      height : bounds.height
    )
    surface.clear()

    let context     = layoutContext(for: bounds)
    let rootLayout  = rootWidget.layout(in: context)
    var allCommands = rootLayout.flattenedCommands()

    for overlay in overlays {
      let overlayLayout = overlay.layout(in: context)
      allCommands.append(contentsOf: overlayLayout.flattenedCommands())
    }

    for command in allCommands {
      surface.set(
        tile   : command.tile,
        atRow  : command.row,
        column : command.column
      )
    }

    let changes = surface.diff()
    return SurfaceRenderer.sequences(for: changes)
  }
}

public extension Scene {
  static func standard ( menuBar: MenuBar? = nil, content: AnyWidget, statusBar: StatusBar? = nil, configuration: SceneConfiguration = SceneConfiguration(), focusChain: FocusChain = FocusChain(), overlays: [AnyWidget] = [] ) -> Scene {
    let scaffold    = Scaffold(menuBar: menuBar, content: content, statusBar: statusBar)
    let rootWidget  = AnyWidget(scaffold)
    let scene       = Scene(configuration: configuration, focusChain: focusChain, rootWidget: rootWidget, overlays: overlays)
    return scene
  }
}

import Foundation
import TerminalOutput

/// Configuration that shapes how a scene should be rendered and styled. It captures the theme, the
/// layout environment and whether standard chrome such as the menu and status bars should be shown.
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

/// Root object describing a hierarchy of widgets and overlays that can be rendered by the terminal
/// driver. The scene owns the focus chain, current configuration and the widget tree entry point.
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

  /// Registers a focusable widget with the scene-wide focus chain so it participates in keyboard
  /// traversal.
  public func registerFocusable ( _ widget: FocusableWidget ) {
    focusChain.register(node: widget.focusNode())
  }

  /// Generates a `LayoutContext` bound to the provided viewport, capturing the current focus snapshot,
  /// theme and environment. Widgets use this context when calculating their geometry.
  public func layoutContext ( for bounds: BoxBounds ) -> LayoutContext {
    return LayoutContext(bounds: bounds, theme: configuration.theme, focus: focusChain.snapshot(), environment: configuration.environment)
  }

  /// Materialises the widget hierarchy into render commands and forwards the resulting surface changes
  /// as terminal sequences. The method clears and resizes the surface, asks the root widget and any
  /// overlays to produce their layout results, writes the commands into the framebuffer and finally
  /// converts the diff into ANSI sequences suitable for terminal output.
  public func render ( into surface: inout Surface, bounds: BoxBounds ) -> [AnsiSequence] {
    surface.beginFrame()
    surface.resize(
      width  : bounds.width,
      height : bounds.height
    )

    let defaultAttributes = configuration.theme.contentDefault
    let defaultTile       = SurfaceTile(character: " ", attributes: defaultAttributes)

    surface.clear(with: defaultTile)

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
  /// Convenience factory that assembles a scene containing the standard scaffold layout. Callers can
  /// supply optional menu and status bars alongside the body content and overlays while still reusing
  /// the default focus chain and configuration values.
  static func standard ( menuBar: MenuBar? = nil, content: AnyWidget, statusBar: StatusBar? = nil, configuration: SceneConfiguration = SceneConfiguration(), focusChain: FocusChain = FocusChain(), overlays: [AnyWidget] = [] ) -> Scene {
    let scaffold    = Scaffold(menuBar: menuBar, content: content, statusBar: statusBar)
    let rootWidget  = AnyWidget(scaffold)
    let scene       = Scene(configuration: configuration, focusChain: focusChain, rootWidget: rootWidget, overlays: overlays)
    return scene
  }
}

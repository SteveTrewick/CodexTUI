import Foundation
import TerminalOutput

// Couples optional foreground/background colours with a text style.
public struct ColorPair : Equatable {
  public var foreground : TerminalOutput.Color?
  public var background : TerminalOutput.Color?
  public var style      : TerminalOutput.TextStyle

  public init ( foreground: TerminalOutput.Color? = nil, background: TerminalOutput.Color? = nil, style: TerminalOutput.TextStyle = .none ) {
    self.foreground = foreground
    self.background = background
    self.style      = style
  }
}

public func == ( lhs: ColorPair, rhs: ColorPair ) -> Bool {
  let foregroundEqual = lhs.foreground?.index == rhs.foreground?.index
  let backgroundEqual = lhs.background?.index == rhs.background?.index
  return foregroundEqual && backgroundEqual && lhs.style == rhs.style
}

// Groups a collection of related colour pairs for widgets to consume.
public struct Theme : Equatable {
  public var menuBar        : ColorPair
  public var statusBar      : ColorPair
  public var windowChrome   : ColorPair
  public var contentDefault : ColorPair
  public var highlight      : ColorPair
  public var dimHighlight   : ColorPair

  public init (
    menuBar: ColorPair = Theme.defaultMenuBar,
    statusBar: ColorPair = Theme.defaultStatusBar,
    windowChrome: ColorPair = Theme.defaultWindowChrome,
    contentDefault: ColorPair = Theme.defaultContent,
    highlight: ColorPair = Theme.defaultHighlight,
    dimHighlight: ColorPair = Theme.defaultDimHighlight
  ) {
    self.menuBar        = menuBar
    self.statusBar      = statusBar
    self.windowChrome   = windowChrome
    self.contentDefault = contentDefault
    self.highlight      = highlight
    self.dimHighlight   = dimHighlight
  }
}

public extension Theme {
  static let codex : Theme = Theme()

  static let defaultMenuBar      : ColorPair = ColorPair(foreground: .black, background: .white, style: [])
  static let defaultStatusBar    : ColorPair = ColorPair(foreground: .black, background: .white, style: [])
  static let defaultWindowChrome : ColorPair = ColorPair(foreground: .white, background: .black)
  static let defaultContent      : ColorPair = ColorPair(foreground: .white, background: .black)
  static let defaultHighlight    : ColorPair = ColorPair(foreground: .black, background: .white,  style: [.bold])
  static let defaultDimHighlight : ColorPair = ColorPair(foreground: .black, background: .white,  style: [.dim])
}

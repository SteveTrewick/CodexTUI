import Foundation
import TerminalInput

public struct KeyEvent : Equatable {
  public var key       : Key
  public var modifiers : KeyModifiers

  public init ( key: Key, modifiers: KeyModifiers = [] ) {
    self.key       = key
    self.modifiers = modifiers
  }
}

public enum Key : Equatable {
  case character(Character)
  case control(TerminalInput.ControlKey)
  case cursor(TerminalInput.CursorKey)
  case function(TerminalInput.FunctionKey)
  case meta(TerminalInput.MetaKey)
}

public struct KeyModifiers : OptionSet, Equatable {
  public let rawValue : UInt8

  public init ( rawValue: UInt8 ) {
    self.rawValue = rawValue
  }

  public static let control : KeyModifiers = KeyModifiers(rawValue: 1 << 0)
  public static let option  : KeyModifiers = KeyModifiers(rawValue: 1 << 1)
  public static let shift   : KeyModifiers = KeyModifiers(rawValue: 1 << 2)
}

public extension KeyEvent {
  static func from ( token: TerminalInput.Token ) -> KeyEvent? {
    switch token {
      case .text(let string) where string.count == 1:
        guard let character = string.first else { return nil }
        return KeyEvent(key: .character(character))

      case .control(let control):
        return KeyEvent(key: .control(control))

      case .cursor(let cursor):
        return KeyEvent(key: .cursor(cursor))

      case .function(let function):
        return KeyEvent(key: .function(function))

      case .meta(let meta):
        return KeyEvent(key: .meta(meta), modifiers: [.option])

      default:
        return nil
    }
  }
}

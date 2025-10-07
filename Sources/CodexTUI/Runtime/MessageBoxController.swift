import Foundation
import TerminalInput

public final class MessageBoxController {
  private struct State {
    var title               : String
    var messageLines        : [String]
    var buttons             : [MessageBoxButton]
    var activeIndex         : Int
    var titleStyleOverride  : ColorPair?
    var messageStyleOverrides: [ColorPair?]?
    var buttonStyleOverride : ColorPair?
  }

  public private(set) var scene           : Scene
  public private(set) var isPresenting    : Bool
  public private(set) var activeButton    : Int?
  public private(set) var currentBounds   : BoxBounds?

  private var storedOverlays  : [AnyWidget]?
  private var previousFocus   : FocusIdentifier?
  private var viewportBounds  : BoxBounds
  private var state           : State?

  public init ( scene: Scene, viewportBounds: BoxBounds = BoxBounds(row: 1, column: 1, width: 80, height: 24) ) {
    self.scene          = scene
    self.viewportBounds = viewportBounds
    self.storedOverlays = nil
    self.previousFocus  = nil
    self.state          = nil
    self.isPresenting   = false
    self.activeButton   = nil
    self.currentBounds  = nil
  }

  public func present (
    title: String,
    messageLines: [String],
    buttons: [MessageBoxButton],
    titleStyleOverride: ColorPair? = nil,
    messageStyleOverrides: [ColorPair?]? = nil,
    buttonStyleOverride: ColorPair? = nil
  ) {
    guard buttons.isEmpty == false else { return }

    if storedOverlays == nil {
      storedOverlays = scene.overlays
    }

    previousFocus = scene.focusChain.active

    let newState = State(
      title             : title,
      messageLines      : messageLines,
      buttons           : buttons,
      activeIndex       : 0,
      titleStyleOverride: titleStyleOverride,
      messageStyleOverrides: messageStyleOverrides,
      buttonStyleOverride: buttonStyleOverride
    )
    presentState(newState)
  }

  public func dismiss () {
    guard isPresenting else { return }

    if let base = storedOverlays {
      scene.overlays = base
    } else {
      scene.overlays.removeAll()
    }

    storedOverlays = nil
    state          = nil
    currentBounds  = nil
    isPresenting   = false
    activeButton   = nil

    if let focus = previousFocus {
      scene.focusChain.focus(identifier: focus)
    }

    previousFocus = nil
  }

  public func update ( viewportBounds: BoxBounds ) {
    self.viewportBounds = viewportBounds
    guard let state = state, isPresenting else { return }
    presentState(state)
  }

  @discardableResult
  public func handle ( token: TerminalInput.Token ) -> Bool {
    guard isPresenting, var state = state else { return false }

    switch token {
      case .escape :
        dismiss()
        return true

      case .control(let key) :
        switch key {
          case .TAB :
            state.activeIndex = nextIndex(from: state.activeIndex, buttons: state.buttons)
            presentState(state)
            return true

          case .RETURN :
            activateButton(at: state.activeIndex)
            return true

          default :
            if let index = state.buttons.firstIndex(where: { $0.activationKey == key }) {
              activateButton(at: index)
              return true
            }
        }

      case .cursor(let key) :
        switch key {
          case .left :
            state.activeIndex = previousIndex(from: state.activeIndex, buttons: state.buttons)
            presentState(state)
            return true
          case .right :
            state.activeIndex = nextIndex(from: state.activeIndex, buttons: state.buttons)
            presentState(state)
            return true
          default :
            break
        }

      default :
        break
    }

    self.state = state
    return true
  }

  private func presentState ( _ state: State ) {
    var state   = state
    if state.buttons.isEmpty {
      state.activeIndex = 0
    } else {
      let maxIndex = state.buttons.count - 1
      state.activeIndex = max(0, min(state.activeIndex, maxIndex))
    }

    let bounds       = MessageBox.centeredBounds(title: state.title, messageLines: state.messageLines, buttons: state.buttons, in: viewportBounds)
    let theme        = scene.configuration.theme
    let buttonStyle  = state.buttonStyleOverride ?? theme.menuBar
    var titleStyle   = theme.contentDefault
    titleStyle.style.insert(.bold)
    if let override = state.titleStyleOverride { titleStyle = override }
    let messageLineStyles: [ColorPair?]
    if let overrides = state.messageStyleOverrides {
      messageLineStyles = state.messageLines.enumerated().map { index, _ in
        guard index < overrides.count else { return nil }
        return overrides[index]
      }
    } else {
      messageLineStyles = []
    }
    let widget = MessageBox(
      title             : state.title,
      messageLines      : state.messageLines,
      messageLineStyles : messageLineStyles,
      buttons           : state.buttons,
      activeButtonIndex : state.activeIndex,
      titleStyle        : titleStyle,
      contentStyle      : theme.contentDefault,
      buttonStyle       : buttonStyle,
      highlightStyle    : theme.highlight,
      borderStyle       : theme.windowChrome
    )

    let overlay = Overlay(
      bounds  : bounds,
      content : AnyWidget(widget)
    )

    scene.overlays = (storedOverlays ?? []) + [AnyWidget(overlay)]
    currentBounds  = bounds
    activeButton   = state.activeIndex
    self.state     = State(
      title             : state.title,
      messageLines      : state.messageLines,
      buttons           : state.buttons,
      activeIndex       : state.activeIndex,
      titleStyleOverride: state.titleStyleOverride,
      messageStyleOverrides: state.messageStyleOverrides,
      buttonStyleOverride: state.buttonStyleOverride
    )
    isPresenting   = true
  }

  private func activateButton ( at index: Int ) {
    guard let state = state else { return }
    guard state.buttons.indices.contains(index) else { return }

    let handler = state.buttons[index].handler
    dismiss()
    handler?()
  }

  private func nextIndex ( from index: Int, buttons: [MessageBoxButton] ) -> Int {
    guard buttons.isEmpty == false else { return index }
    let count = buttons.count
    return (index + 1 + count) % count
  }

  private func previousIndex ( from index: Int, buttons: [MessageBoxButton] ) -> Int {
    guard buttons.isEmpty == false else { return index }
    let count = buttons.count
    return (index - 1 + count) % count
  }
}

import Foundation
import TerminalInput

public final class TextEntryBoxController {
  private struct State {
    var title        : String
    var prompt       : String?
    var buttons      : [TextEntryBoxButton]
    var activeIndex  : Int
    var text         : String
    var caret        : Int
  }

  public private(set) var scene         : Scene
  public private(set) var isPresenting  : Bool
  public private(set) var activeButton  : Int?
  public private(set) var currentBounds : BoxBounds?
  public private(set) var currentText   : String
  public private(set) var caretIndex    : Int

  private var storedOverlays : [AnyWidget]?
  private var previousFocus  : FocusIdentifier?
  private var viewportBounds : BoxBounds
  private var startWidth     : Int
  private var state          : State?

  public init ( scene: Scene, viewportBounds: BoxBounds = BoxBounds(row: 1, column: 1, width: 80, height: 24), startWidth: Int? = nil ) {
    self.scene          = scene
    self.viewportBounds = viewportBounds
    self.startWidth     = max(1, startWidth ?? 1)
    self.storedOverlays = nil
    self.previousFocus  = nil
    self.state          = nil
    self.isPresenting   = false
    self.activeButton   = nil
    self.currentBounds  = nil
    self.currentText    = ""
    self.caretIndex     = 0
  }

  public func present ( title: String, prompt: String? = nil, text: String = "", buttons: [TextEntryBoxButton] ) {
    guard buttons.isEmpty == false else { return }

    if storedOverlays == nil {
      storedOverlays = scene.overlays
    }

    previousFocus = scene.focusChain.active

    let newState = State(title: title, prompt: prompt, buttons: buttons, activeIndex: 0, text: text, caret: text.count)
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
    currentText    = ""
    caretIndex     = 0
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

          case .BACKSPACE, .DEL :
            if state.caret > 0 {
              let removalIndex = state.text.index(state.text.startIndex, offsetBy: state.caret)
              let lowerBound   = state.text.index(before: removalIndex)
              state.text.removeSubrange(lowerBound..<removalIndex)
              state.caret -= 1
              presentState(state)
            }
            return true

          default :
            if let index = state.buttons.firstIndex(where: { $0.activationKey == key }) {
              activateButton(at: index)
              return true
            }
        }

      case .text(let string) :
        guard string.isEmpty == false else { return true }
        let insertionIndex = state.text.index(state.text.startIndex, offsetBy: state.caret)
        state.text.insert(contentsOf: string, at: insertionIndex)
        state.caret += string.count
        presentState(state)
        return true

      case .cursor(let key) :
        switch key {
          case .left :
            if state.caret > 0 {
              state.caret -= 1
              presentState(state)
            }
            return true

          case .right :
            if state.caret < state.text.count {
              state.caret += 1
              presentState(state)
            }
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

    state.caret = max(0, min(state.caret, state.text.count))

    let bounds = TextEntryBox.centeredBounds(title: state.title, prompt: state.prompt, text: state.text, buttons: state.buttons, minimumFieldWidth: startWidth, in: viewportBounds)
    let theme  = scene.configuration.theme
    let widget = TextEntryBox(
      title             : state.title,
      prompt            : state.prompt,
      text              : state.text,
      caretIndex        : state.caret,
      buttons           : state.buttons,
      activeButtonIndex : state.activeIndex,
      contentStyle      : theme.contentDefault,
      fieldStyle        : theme.contentDefault,
      caretStyle        : theme.highlight,
      buttonStyle       : theme.dimHighlight,
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
    currentText    = state.text
    caretIndex     = state.caret
    self.state     = State(title: state.title, prompt: state.prompt, buttons: state.buttons, activeIndex: state.activeIndex, text: state.text, caret: state.caret)
    isPresenting   = true
  }

  private func activateButton ( at index: Int ) {
    guard let state = state else { return }
    guard state.buttons.indices.contains(index) else { return }

    let handler = state.buttons[index].handler
    let text    = state.text
    dismiss()
    handler?(text)
  }

  private func nextIndex ( from index: Int, buttons: [TextEntryBoxButton] ) -> Int {
    guard buttons.isEmpty == false else { return index }
    let count = buttons.count
    return (index + 1 + count) % count
  }
}

import Foundation
import TerminalInput

public final class SelectionListController {
  private struct State {
    var title                 : String
    var entries               : [SelectionListEntry]
    var selectionIndex        : Int
    var titleStyleOverride    : ColorPair?
    var contentStyleOverride  : ColorPair?
    var highlightStyleOverride: ColorPair?
    var borderStyleOverride   : ColorPair?
  }

  public private(set) var scene         : Scene
  public private(set) var isPresenting  : Bool
  public private(set) var activeIndex   : Int?
  public private(set) var currentBounds : BoxBounds?

  private var storedOverlays : [AnyWidget]?
  private var previousFocus  : FocusIdentifier?
  private var viewportBounds : BoxBounds
  private var state          : State?

  public init ( scene: Scene, viewportBounds: BoxBounds = BoxBounds(row: 1, column: 1, width: 80, height: 24) ) {
    self.scene          = scene
    self.viewportBounds = viewportBounds
    self.storedOverlays = nil
    self.previousFocus  = nil
    self.state          = nil
    self.isPresenting   = false
    self.activeIndex    = nil
    self.currentBounds  = nil
  }

  public func present (
    title: String,
    entries: [SelectionListEntry],
    selectionIndex: Int = 0,
    titleStyleOverride: ColorPair? = nil,
    contentStyleOverride: ColorPair? = nil,
    highlightStyleOverride: ColorPair? = nil,
    borderStyleOverride: ColorPair? = nil
  ) {
    guard entries.isEmpty == false else { return }

    if storedOverlays == nil {
      storedOverlays = scene.overlays
    }

    if previousFocus == nil {
      previousFocus = scene.focusChain.active
    }

    let newState = State(
      title                 : title,
      entries               : entries,
      selectionIndex        : selectionIndex,
      titleStyleOverride    : titleStyleOverride,
      contentStyleOverride  : contentStyleOverride,
      highlightStyleOverride: highlightStyleOverride,
      borderStyleOverride   : borderStyleOverride
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
    activeIndex    = nil
    isPresenting   = false

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

      case .cursor(let key) :
        switch key {
          case .up :
            state.selectionIndex = previousIndex(from: state.selectionIndex, entries: state.entries)
            presentState(state)
            return true
          case .down :
            state.selectionIndex = nextIndex(from: state.selectionIndex, entries: state.entries)
            presentState(state)
            return true
          default :
            break
        }

      case .control(let key) :
        switch key {
          case .RETURN :
            activateEntry(at: state.selectionIndex)
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
    var state         = state
    let maxIndex      = max(0, state.entries.count - 1)
    state.selectionIndex = max(0, min(state.selectionIndex, maxIndex))

    let bounds         = SelectionList.centeredBounds(title: state.title, entries: state.entries, in: viewportBounds)
    let theme          = scene.configuration.theme
    let contentStyle   = state.contentStyleOverride ?? theme.contentDefault
    let highlightStyle = state.highlightStyleOverride ?? theme.highlight
    let borderStyle    = state.borderStyleOverride ?? theme.windowChrome
    let titleStyle     : ColorPair

    if let override = state.titleStyleOverride {
      titleStyle = override
    } else {
      var defaultTitle = theme.contentDefault
      defaultTitle.style.insert(.bold)
      titleStyle = defaultTitle
    }

    let widget = SelectionList(
      title          : state.title,
      entries        : state.entries,
      selectionIndex : state.selectionIndex,
      titleStyle     : titleStyle,
      style          : contentStyle,
      highlightStyle : highlightStyle,
      borderStyle    : borderStyle
    )

    let overlay = Overlay(
      bounds  : bounds,
      content : AnyWidget(widget)
    )

    scene.overlays = (storedOverlays ?? []) + [AnyWidget(overlay)]
    currentBounds  = bounds
    activeIndex    = state.selectionIndex
    self.state     = State(
      title                 : state.title,
      entries               : state.entries,
      selectionIndex        : state.selectionIndex,
      titleStyleOverride    : state.titleStyleOverride,
      contentStyleOverride  : state.contentStyleOverride,
      highlightStyleOverride: state.highlightStyleOverride,
      borderStyleOverride   : state.borderStyleOverride
    )
    isPresenting   = true
  }

  private func activateEntry ( at index: Int ) {
    guard let state = state else { return }
    guard state.entries.indices.contains(index) else { return }
    let action = state.entries[index].action
    dismiss()
    action?()
  }

  private func nextIndex ( from index: Int, entries: [SelectionListEntry] ) -> Int {
    guard entries.isEmpty == false else { return 0 }
    let count   = entries.count
    let current = max(0, min(index, count - 1))
    return (current + 1) % count
  }

  private func previousIndex ( from index: Int, entries: [SelectionListEntry] ) -> Int {
    guard entries.isEmpty == false else { return 0 }
    let count   = entries.count
    let current = max(0, min(index, count - 1))
    return (current - 1 + count) % count
  }
}

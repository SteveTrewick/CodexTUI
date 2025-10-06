import Foundation

// Unique identifier assigned to focusable widgets.
public struct FocusIdentifier : Hashable, Equatable {
  public let rawValue : String

  public init ( _ rawValue: String ) {
    self.rawValue = rawValue
  }
}

// Node stored inside the focus chain that carries runtime state.
public struct FocusNode : Equatable {
  public let identifier : FocusIdentifier
  public var isEnabled  : Bool
  public var acceptsTab : Bool

  public init ( identifier: FocusIdentifier, isEnabled: Bool = true, acceptsTab: Bool = true ) {
    self.identifier = identifier
    self.isEnabled  = isEnabled
    self.acceptsTab = acceptsTab
  }
}

// Tracks focusable widgets and the current focus position, providing tab-order traversal helpers.
public final class FocusChain {
  public private(set) var nodes  : [FocusNode]
  public private(set) var active : FocusIdentifier?

  public init ( nodes: [FocusNode] = [] ) {
    self.nodes  = nodes
    self.active = nodes.first?.identifier
  }

  // Captures the current focus state so layout code can respond without mutating the live chain.
  public func snapshot () -> Snapshot {
    return Snapshot(nodes: nodes, active: active)
  }

  // Explicitly focuses a particular identifier if it exists and is enabled.
  public func focus ( identifier: FocusIdentifier ) {
    guard nodes.contains(where: { $0.identifier == identifier && $0.isEnabled }) else { return }
    active = identifier
  }

  // Moves focus to the next enabled node, wrapping around to the start if necessary.
  public func advance () {
    guard nodes.isEmpty == false else { return }

    let enabled = nodes.enumerated().filter { $0.element.isEnabled }
    guard enabled.isEmpty == false else { return }

    if let active = active, let index = enabled.firstIndex(where: { $0.element.identifier == active }) {
      let nextIndex = enabled[(index + 1) % enabled.count].offset
      self.active   = nodes[nextIndex].identifier
      return
    }

    self.active = enabled.first?.element.identifier
  }

  // Moves focus to the previous enabled node, wrapping to the end when we walk past the start.
  public func retreat () {
    guard nodes.isEmpty == false else { return }

    let enabled = nodes.enumerated().filter { $0.element.isEnabled }
    guard enabled.isEmpty == false else { return }

    if let active = active, let index = enabled.firstIndex(where: { $0.element.identifier == active }) {
      let previousIndex = (index - 1 + enabled.count) % enabled.count
      let nodeIndex     = enabled[previousIndex].offset
      self.active       = nodes[nodeIndex].identifier
      return
    }

    self.active = enabled.last?.element.identifier
  }

  // Adds a node if we have not seen the identifier before. The first registration becomes active automatically.
  public func register ( node: FocusNode ) {
    guard nodes.contains(where: { $0.identifier == node.identifier }) == false else { return }
    nodes.append(node)
    if active == nil { active = node.identifier }
  }

  // Removes a node and gracefully falls back to the next available focus target.
  public func unregister ( identifier: FocusIdentifier ) {
    nodes.removeAll { $0.identifier == identifier }
    if active == identifier { active = nodes.first?.identifier }
  }

  public struct Snapshot {
    public let nodes  : [FocusNode]
    public let active : FocusIdentifier?
  }
}

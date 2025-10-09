import Foundation

/// Abstraction describing a bidirectional stream of UTF-8 text. Channels deliver decoded
/// fragments to a delegate as data arrives and expose lifecycle hooks for resource
/// management.
public protocol TextIOChannel : AnyObject {
  var delegate : TextIOChannelDelegate? { get set }

  func start ()
  func stop ()
  func send ( _ text: String )
}

/// Receives decoded UTF-8 fragments from a `TextIOChannel`.
public protocol TextIOChannelDelegate : AnyObject {
  func textIOChannel ( _ channel: TextIOChannel, didReceive fragment: String )
}

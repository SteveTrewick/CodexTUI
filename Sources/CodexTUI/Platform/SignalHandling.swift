import Foundation
import Dispatch

#if os(Linux)
import Glibc
#else
import Darwin
#endif

/// Thin wrapper around `DispatchSourceSignal` that hides platform conditional imports and exposes a
/// simple API for listening to terminal resize notifications.
public final class SignalObserver {
  public typealias Handler = () -> Void

  private let monitoredSignal : Int32
  private let signalQueue     : DispatchQueue
  private let handlerQueue    : DispatchQueue
  private var source          : DispatchSourceSignal?
  private var handler         : Handler?

  public init ( signal: Int32 = SIGWINCH, signalQueue: DispatchQueue = DispatchQueue(label: "CodexTUI.SignalObserver", qos: .userInitiated), handlerQueue: DispatchQueue = .main ) {
    self.monitoredSignal = signal
    self.signalQueue     = signalQueue
    self.handlerQueue    = handlerQueue
  }

  /// Registers the closure that should run when the monitored signal fires.
  public func setHandler ( _ handler: @escaping Handler ) {
    self.handler = handler
  }

  
  /// Begins listening for the configured signal and forwards notifications to the handler queue when
  /// events arrive. Subsequent calls are ignored while the observer is active.
  public func start () {
    
    guard source == nil else { return }

    let source = DispatchSource.makeSignalSource(signal: monitoredSignal, queue: signalQueue)
    
    source.setEventHandler { [weak self] in
      self?.handlerQueue.async {
        self?.handler?()
      }
    }
    
    source.resume()

    self.source = source
  }

  /// Cancels the dispatch source and releases the handler closure to avoid retain cycles. Safe to call
  /// multiple times.
  public func stop () {
    source?.cancel()
    source = nil
    handler = nil
  }

  deinit {
    stop()
  }
}

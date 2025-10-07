import Foundation
import Dispatch

#if os(Linux)
import Glibc
#else
import Darwin
#endif

// Thin wrapper around DispatchSourceSignal that hides platform conditional imports.
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

  public func setHandler ( _ handler: @escaping Handler ) {
    self.handler = handler
  }

  // Begins listening for the configured signal and forwards notifications to the handler.
  public func start () {
    guard source == nil else { return }

    let source = DispatchSource.makeSignalSource(signal: monitoredSignal, queue: signalQueue)
    source.setEventHandler { [weak self] in
      guard let self     = self else { return }
      guard let handler  = self.handler else { return }
      self.handlerQueue.async {
        handler()
      }
    }
    source.resume()

    self.source = source
  }

  // Cancels the dispatch source and releases the handler closure.
  public func stop () {
    source?.cancel()
    source = nil
    handler = nil
  }

  deinit {
    stop()
  }
}

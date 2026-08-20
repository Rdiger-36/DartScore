import Flutter
import UIKit

/// Takes a file another app hands to DartScore, and passes it on to Dart.
///
/// This is what makes a backup or a profile arriving by AirDrop, mail, Files or
/// Drive open the app rather than sit in a download folder waiting to be hunted
/// down through the picker. The types it answers for are declared in
/// `Info.plist`; without those declarations iOS has no reason to offer this app
/// at all.
///
/// Written by hand like the two handlers beside it: what is needed is one path
/// crossing to Dart, and a package for that would pull CocoaPods back onto a
/// build that deliberately does without it.
class IncomingFileHandler: NSObject, FlutterPlugin {
  /// Shared with `IncomingFiles` on the Dart side.
  private static let channelName = "dartscore/incoming_file"

  /// The one handler, so the scene can reach it when a file arrives.
  static let shared = IncomingFileHandler()

  private var channel: FlutterMethodChannel?

  /// Whether Dart has asked for its first file yet.
  ///
  /// The channel existing is not the same as somebody listening on it. The
  /// engine is registered while the app is still launching, well before any
  /// widget has set a handler, so a file announced then goes nowhere. The first
  /// `initial` call is what says the other end is there, and until it comes
  /// everything waits.
  private var ready = false

  /// A file the app was launched with, waiting to be asked for.
  ///
  /// Handing it over clears it: a file is offered once, not again on the next
  /// rebuild.
  private var pending: String?

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )
    shared.channel = channel
    registrar.addMethodCallDelegate(shared, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "initial" else {
      result(FlutterMethodNotImplemented)
      return
    }
    ready = true
    result(pending)
    pending = nil
  }

  /// Takes one URL the system opened the app with.
  ///
  /// Copied into this app's cache rather than read where it lies. What arrives
  /// by AirDrop or a share sits in an Inbox the system is free to clear, and a
  /// document opened in place is somebody else's file this app is allowed to
  /// look at for a moment; everything above this works on plain paths.
  ///
  /// Deferred by one turn of the run loop on purpose. On a cold start this is
  /// called while the scene is still being connected, and a security scoped URL
  /// is not reliably readable that early: the app came up on its home screen
  /// with the file silently dropped.
  func take(_ url: URL) {
    DispatchQueue.main.async { [weak self] in
      self?.deliver(url)
    }
  }

  private func deliver(_ url: URL) {
    guard let path = copyToCache(url) else {
      // Never silently. A file that could not be read has to say so, or the
      // app just opens on its home screen and the user is left guessing.
      announce("failed", url.lastPathComponent)
      return
    }
    announce("opened", path)
  }

  /// Hands [argument] to Dart, or keeps it until Dart is listening.
  private func announce(_ method: String, _ argument: String) {
    // Straight over only once Dart has shown it is listening. Before that the
    // file waits, or it is announced into a channel nobody is holding.
    if ready, let channel {
      channel.invokeMethod(method, arguments: argument)
    } else if method == "opened" {
      pending = argument
    }
  }

  /// Copies what [url] points at into this app's cache and returns the path.
  ///
  /// Through `NSFileCoordinator`, which is what a document opened in place
  /// needs: the file may be another app's, or an iCloud item that is not on the
  /// device yet, and a plain `copyItem` on one of those fails. A copy that
  /// works for the Inbox and not for Files is exactly the half-working state
  /// this had.
  private func copyToCache(_ url: URL) -> String? {
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }

    let caches = FileManager.default.urls(
      for: .cachesDirectory, in: .userDomainMask
    )[0]
    let target = caches.appendingPathComponent("opened-\(url.lastPathComponent)")

    var copied: String?
    var coordinationError: NSError?

    NSFileCoordinator().coordinate(
      readingItemAt: url, options: .withoutChanges, error: &coordinationError
    ) { readable in
      do {
        if FileManager.default.fileExists(atPath: target.path) {
          try FileManager.default.removeItem(at: target)
        }
        try FileManager.default.copyItem(at: readable, to: target)
        copied = target.path
      } catch {
        // The item exists but would not copy, most often because it is not on
        // the device yet. Reading it pulls it down.
        if let data = try? Data(contentsOf: readable),
          (try? data.write(to: target, options: .atomic)) != nil
        {
          copied = target.path
        }
      }
    }

    return copied
  }
}

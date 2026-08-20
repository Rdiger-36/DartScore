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

  /// A file the app was launched with, waiting to be asked for.
  ///
  /// The scene is handed the URL before Dart is running, so it is kept until
  /// `initial` comes to collect it. Handing it over clears it: a file is
  /// offered once, not again on the next rebuild.
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
    result(pending)
    pending = nil
  }

  /// Takes one URL the system opened the app with.
  ///
  /// Copied into this app's cache rather than read where it lies. What arrives
  /// sits in an Inbox the system is free to clear, and on a security scoped URL
  /// the claim has to be given back at once; everything above this works on
  /// plain paths.
  func take(_ url: URL) {
    guard let path = copyToCache(url) else { return }

    // Dart is running once the channel exists, so the file goes straight over.
    // Before that it waits to be collected.
    if let channel {
      channel.invokeMethod("opened", arguments: path)
    } else {
      pending = path
    }
  }

  private func copyToCache(_ url: URL) -> String? {
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }

    let caches = FileManager.default.urls(
      for: .cachesDirectory, in: .userDomainMask
    )[0]
    let target = caches.appendingPathComponent("opened-\(url.lastPathComponent)")

    do {
      if FileManager.default.fileExists(atPath: target.path) {
        try FileManager.default.removeItem(at: target)
      }
      try FileManager.default.copyItem(at: url, to: target)
      return target.path
    } catch {
      return nil
    }
  }
}

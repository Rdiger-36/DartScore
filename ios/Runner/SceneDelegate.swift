import Flutter
import OSLog
import UIKit

/// The scene, plus the one thing it has to do beyond hosting Flutter: take the
/// files the system opens this app with.
///
/// Two ways in, because iOS has two. A file that launched the app arrives in
/// the connection options before there is any Dart to hand it to;
/// `IncomingFileHandler` keeps it until Dart comes to collect it. A file handed
/// to an app already running arrives here instead.
class SceneDelegate: FlutterSceneDelegate {
  /// The same subsystem `IncomingFileHandler` writes to, so one filter on the
  /// device log shows both halves of a file arriving.
  private static let log = Logger(
    subsystem: "com.ratka.dartscore", category: "incoming-file")

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    // Logged whether there is anything there or not: an empty set on a launch
    // that was meant to open a document says the URL never reached this app,
    // which is a different fault from one that reached it and would not read.
    Self.log.info("connect, urls=\(connectionOptions.urlContexts.count, privacy: .public)")
    for context in connectionOptions.urlContexts {
      IncomingFileHandler.shared.take(context.url)
    }
  }

  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    super.scene(scene, openURLContexts: URLContexts)
    Self.log.info("openURL, urls=\(URLContexts.count, privacy: .public)")
    for context in URLContexts {
      IncomingFileHandler.shared.take(context.url)
    }
  }
}

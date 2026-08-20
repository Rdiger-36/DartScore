import Flutter
import UIKit

/// The scene, plus the one thing it has to do beyond hosting Flutter: take the
/// files the system opens this app with.
///
/// Two ways in, because iOS has two. A file that launched the app arrives in
/// the connection options before there is any Dart to hand it to;
/// `IncomingFileHandler` keeps it until Dart comes to collect it. A file handed
/// to an app already running arrives here instead.
class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    for context in connectionOptions.urlContexts {
      IncomingFileHandler.shared.take(context.url)
    }
  }

  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    super.scene(scene, openURLContexts: URLContexts)
    for context in URLContexts {
      IncomingFileHandler.shared.take(context.url)
    }
  }
}

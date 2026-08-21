import Flutter
import NetworkExtension
import UIKit

/// Joins the Wi-Fi network another device raised for one transfer.
///
/// The other half of this, raising the network, has no iOS implementation and
/// never will: Apple gives no app a way to create an access point.
/// `NEHotspotConfigurationManager` joins networks that already exist, which is
/// why an iPhone is always the device that joins and an Android phone is always
/// the one that hosts. Which of them hosts says nothing about which way the
/// data travels.
///
/// Written by hand rather than taken from a package, like the two handlers
/// beside it: no maintained Flutter plugin covers this API, and one that did
/// would pull CocoaPods back onto a build that deliberately does without it.
///
/// Needs the Hotspot Configuration capability, which is enabled on the App ID
/// in the developer portal and listed in `Runner.entitlements`. It is granted
/// on request and needs no separate case put to Apple; that is
/// `NEHotspotHelper`, a different API this does not use.
class HotspotJoinHandler: NSObject, FlutterPlugin {
  /// Shared with `WifiJoin` on the Dart side.
  private static let channelName = "dartscore/wifi_join"

  /// The network joined, so it can be given back on leave.
  private var joinedSsid: String?

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(HotspotJoinHandler(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isSupported":
      result(true)
    case "join":
      guard let arguments = call.arguments as? [String: Any],
        let ssid = arguments["ssid"] as? String,
        let passphrase = arguments["passphrase"] as? String
      else {
        result(FlutterError(code: "join_failed", message: "No network was named", details: nil))
        return
      }
      join(ssid: ssid, passphrase: passphrase, result: result)
    case "leave":
      leave()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Applies the configuration and answers once iOS has joined.
  ///
  /// `joinOnce` is what keeps a transfer network out of the user's saved
  /// networks: it is forgotten when the app goes away, rather than lingering as
  /// a network the phone tries to rejoin for the rest of its life.
  private func join(ssid: String, passphrase: String, result: @escaping FlutterResult) {
    let configuration = NEHotspotConfiguration(
      ssid: ssid, passphrase: passphrase, isWEP: false)
    configuration.joinOnce = true

    NEHotspotConfigurationManager.shared.apply(configuration) { [weak self] error in
      guard let error = error as NSError? else {
        self?.joinedSsid = ssid
        result(nil)
        return
      }

      // Already on the right network. Applying the same configuration twice is
      // an error to iOS and a success to everyone else.
      if error.domain == NEHotspotConfigurationErrorDomain,
        error.code == NEHotspotConfigurationError.alreadyAssociated.rawValue
      {
        self?.joinedSsid = ssid
        result(nil)
        return
      }

      result(
        FlutterError(
          code: error.code == NEHotspotConfigurationError.userDenied.rawValue
            ? "permission_denied" : "join_failed",
          message: error.localizedDescription,
          details: nil))
    }
  }

  /// Drops the configuration, so the phone goes back to its usual network.
  ///
  /// Has to run on every way out of a transfer, the failures included, or the
  /// phone stays on a network with no internet on it.
  private func leave() {
    guard let ssid = joinedSsid else { return }
    NEHotspotConfigurationManager.shared.removeConfiguration(forSSID: ssid)
    joinedSsid = nil
  }
}

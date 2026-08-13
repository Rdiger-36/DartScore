import Flutter
import UIKit

/// Reports what this device is, for a sync packet or a backup to say where it
/// came from.
///
/// Written by hand for the same reason `DocumentPickerHandler` is: a package
/// would pull CocoaPods back onto the iOS side, and what is needed here is two
/// strings.
///
/// The name the owner gave the device is deliberately not read. Since iOS 16
/// `UIDevice.name` answers with the model instead of that name unless the app
/// carries an entitlement Apple grants case by case, so asking for it would
/// only look like it worked. The model identifier goes back raw and Dart turns
/// it into a marketing name, which keeps that table somewhere it can be tested
/// and updated without touching Xcode.
class DeviceDescriptionHandler: NSObject, FlutterPlugin {
  /// Shared with `DeviceDescription` on the Dart side.
  private static let channelName = "dartscore/device_description"

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(DeviceDescriptionHandler(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "describe" else {
      result(FlutterMethodNotImplemented)
      return
    }
    result([
      "name": Self.modelIdentifier(),
      "os": "iOS \(UIDevice.current.systemVersion)",
    ])
  }

  /// The hardware identifier, for example "iPhone16,1".
  ///
  /// Read from `uname` rather than from `UIDevice`, which only distinguishes
  /// iPhone from iPad. On a simulator the host exports the identifier it is
  /// pretending to be, so that path is preferred where it exists.
  private static func modelIdentifier() -> String {
    if let simulated = ProcessInfo.processInfo
      .environment["SIMULATOR_MODEL_IDENTIFIER"], !simulated.isEmpty {
      return simulated
    }
    var info = utsname()
    uname(&info)
    let identifier = withUnsafePointer(to: &info.machine) {
      $0.withMemoryRebound(to: CChar.self, capacity: MemoryLayout.size(ofValue: $0)) {
        String(validatingUTF8: $0)
      }
    }
    guard let identifier, !identifier.isEmpty else {
      return UIDevice.current.model
    }
    return identifier
  }
}

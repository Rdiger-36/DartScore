import Flutter
import UIKit

/// Opens the system document picker and hands Flutter back a readable path.
///
/// Written by hand instead of taken from a package because every file picking
/// plugin still wants CocoaPods, which this project deliberately does not use
/// (see the commit that took it out of the iOS build). What is needed here is
/// small enough to own: one file in, one path back.
///
/// The picker always imports a copy into the app's own temporary directory, so
/// the caller gets a plain readable file and no security scoped URL that would
/// have to be held open while it is read.
class DocumentPickerHandler: NSObject, FlutterPlugin {
  /// Shared with `DocumentPicker` on the Dart side.
  private static let channelName = "dartscore/document_picker"

  /// The call waiting for the user to pick something, or nil when the picker
  /// is not up.
  private var pending: FlutterResult?

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )
    // Hands the instance to the registrar rather than keeping it in a closure,
    // so the engine owns it for as long as the channel lives.
    registrar.addMethodCallDelegate(DocumentPickerHandler(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "pickFile" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard pending == nil else {
      result(nil)
      return
    }
    guard let root = Self.rootViewController() else {
      result(nil)
      return
    }

    pending = result

    let picker: UIDocumentPickerViewController
    if #available(iOS 14.0, *) {
      picker = UIDocumentPickerViewController(
        forOpeningContentTypes: [.data],
        asCopy: true
      )
    } else {
      picker = UIDocumentPickerViewController(
        documentTypes: ["public.data"],
        in: .import
      )
    }
    picker.allowsMultipleSelection = false
    picker.delegate = self
    root.present(picker, animated: true)
  }

  /// Answers the waiting call once, whatever happened.
  private func finish(_ path: String?) {
    pending?(path)
    pending = nil
  }

  /// The controller to present the picker from.
  ///
  /// Read off the window scene rather than the app delegate: this app runs
  /// through a `FlutterSceneDelegate`, and with scenes in charge the delegate's
  /// own window stays empty.
  private static func rootViewController() -> UIViewController? {
    UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }?
      .rootViewController
  }
}

extension DocumentPickerHandler: UIDocumentPickerDelegate {
  func documentPicker(
    _ controller: UIDocumentPickerViewController,
    didPickDocumentsAt urls: [URL]
  ) {
    finish(urls.first?.path)
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    finish(nil)
  }
}

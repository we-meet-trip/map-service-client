import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Flutter's platform-specific dart-define is also the native SDK key.
    // Only client-restricted keys belong in an application binary.
    if let encoded = Bundle.main.object(forInfoDictionaryKey: "MapsDartDefines") as? String {
      for item in encoded.split(separator: ",") {
        guard let data = Data(base64Encoded: String(item)),
              let value = String(data: data, encoding: .utf8) else { continue }
        let prefix = "GOOGLE_MAPS_IOS_API_KEY="
        if value.hasPrefix(prefix) {
          let key = String(value.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
          if !key.isEmpty { GMSServices.provideAPIKey(key) }
        }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}

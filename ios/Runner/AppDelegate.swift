import Flutter
import UIKit

/// 시리 App Intent · 위젯과 기록을 공유하기 위해, Drift(SQLite) DB 파일을
/// App Group 공유 컨테이너에 두기로 했다. Dart 쪽(lib/data/db/shared_container.dart)이
/// 이 채널로 컨테이너 경로를 물어본다.
private let appGroupChannelName = "com.happypi.parentingLog/app_group"

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: appGroupChannelName,
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "containerPath":
        guard
          let args = call.arguments as? [String: Any],
          let groupId = args["groupId"] as? String,
          let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupId)
        else {
          result(nil)
          return
        }
        result(url.path)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

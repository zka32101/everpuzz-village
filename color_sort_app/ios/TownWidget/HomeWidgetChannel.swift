import Flutter
import WidgetKit

/// 町の絵(PNG)を App Group に書き、ウィジェットに更新を知らせる。
/// Runner ターゲットに追加し、AppDelegate の didInitializeImplicitFlutterEngine で
/// `HomeWidgetChannel.register(messenger: engineBridge.applicationRegistrar.messenger())` を呼ぶ。
/// App Group が未設定の間は何もしない(アプリは普通に動く)。
enum HomeWidgetChannel {
    static let appGroup = "group.com.petitworksapps.colorsortapp"

    static func register(messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: "everpuzz/home_widget", binaryMessenger: messenger)
        channel.setMethodCallHandler { call, result in
            guard call.method == "update" else { return result(FlutterMethodNotImplemented) }
            guard let args = call.arguments as? [String: Any],
                  let png = args["png"] as? FlutterStandardTypedData else {
                return result(FlutterError(code: "bad_args", message: "png is required", details: nil))
            }
            if let dir = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: appGroup) {
                try? png.data.write(to: dir.appendingPathComponent("town_widget.png"), options: .atomic)
                if #available(iOS 14.0, *) { WidgetCenter.shared.reloadAllTimelines() }
            }
            result(nil)
        }
    }
}

import AVKit
import Flutter
import UIKit

final class GroupLiveAirPlayViewFactory: NSObject, FlutterPlatformViewFactory {
    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        let params = args as? [String: Any]
        let tint = params?["tint"] as? Int
        return GroupLiveAirPlayPlatformView(frame: frame, tint: tint)
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }
}

final class GroupLiveAirPlayPlatformView: NSObject, FlutterPlatformView {
    private let routePickerView: AVRoutePickerView

    init(frame: CGRect, tint: Int?) {
        let picker = AVRoutePickerView(frame: frame)
        picker.backgroundColor = .clear
        if let tint {
            let color = UIColor(
                red: CGFloat((tint >> 16) & 0xFF) / 255.0,
                green: CGFloat((tint >> 8) & 0xFF) / 255.0,
                blue: CGFloat(tint & 0xFF) / 255.0,
                alpha: CGFloat((tint >> 24) & 0xFF) / 255.0
            )
            picker.tintColor = color
            picker.activeTintColor = color
        } else {
            picker.tintColor = .white
            picker.activeTintColor = .white
        }
        routePickerView = picker
        super.init()
    }

    func view() -> UIView {
        routePickerView
    }
}

import Flutter
import UIKit
import AmazonChimeSDK

class ChimeVideoViewFactory: NSObject, FlutterPlatformViewFactory {

    var activeViews: [Int: ChimeVideoView] = [:]

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        let params = args as? [String: Any]
        let tileId = params?["tileId"] as? Int ?? 0
        let view = ChimeVideoView(frame: frame, viewId: viewId, tileId: tileId)
        activeViews[tileId] = view
        return view
    }

    func removeView(tileId: Int) {
        activeViews.removeValue(forKey: tileId)
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}

class ChimeVideoView: NSObject, FlutterPlatformView {
    private let containerView: UIView
    private let videoRenderView: DefaultVideoRenderView
    private let tileId: Int

    init(frame: CGRect, viewId: Int64, tileId: Int) {
        self.tileId = tileId
        containerView = UIView(frame: frame)
        containerView.backgroundColor = .black
        videoRenderView = DefaultVideoRenderView(frame: containerView.bounds)
        videoRenderView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        containerView.addSubview(videoRenderView)
        super.init()
    }

    func view() -> UIView {
        return containerView
    }

    func getVideoRenderView() -> DefaultVideoRenderView {
        return videoRenderView
    }
}

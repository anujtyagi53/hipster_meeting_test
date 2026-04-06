import Flutter
import UIKit
import AmazonChimeSDK

@main
@objc class AppDelegate: FlutterAppDelegate {
    private var eventSink: FlutterEventSink?
    private var meetingSession: DefaultMeetingSession?
    private let videoViewFactory = ChimeVideoViewFactory()
    private var deepLinkChannel: FlutterMethodChannel?
    private var pendingDeepLink: String?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        guard let controller = window?.rootViewController as? FlutterViewController else {
            return super.application(application, didFinishLaunchingWithOptions: launchOptions)
        }

        let methodChannel = FlutterMethodChannel(
            name: "com.hipster.chime/meeting",
            binaryMessenger: controller.binaryMessenger
        )
        methodChannel.setMethodCallHandler { [weak self] (call, result) in
            self?.handleMethodCall(call: call, result: result)
        }

        let eventChannel = FlutterEventChannel(
            name: "com.hipster.chime/events",
            binaryMessenger: controller.binaryMessenger
        )
        eventChannel.setStreamHandler(ChimeEventStreamHandler(appDelegate: self))

        // Deep link channel
        deepLinkChannel = FlutterMethodChannel(
            name: "com.hipster.chime/deeplink",
            binaryMessenger: controller.binaryMessenger
        )
        deepLinkChannel?.setMethodCallHandler { [weak self] (call, result) in
            switch call.method {
            case "getInitialLink":
                result(self?.pendingDeepLink)
                self?.pendingDeepLink = nil
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        // Capture deep link from launch
        if let url = launchOptions?[.url] as? URL {
            pendingDeepLink = url.absoluteString
        }

        registrar(forPlugin: "ChimeVideoView")?.register(videoViewFactory, withId: "chime_video_view")

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // Handle deep links when app is already running
    override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        deepLinkChannel?.invokeMethod("onDeepLink", arguments: url.absoluteString)
        return true
    }

    override func applicationWillTerminate(_ application: UIApplication) {
        if meetingSession != nil {
            stopMeeting()
        }
    }

    private func handleMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startMeeting":
            guard let args = call.arguments as? [String: Any],
                  let meetingMap = args["meeting"] as? [String: Any],
                  let attendeeMap = args["attendee"] as? [String: Any] else {
                result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
                return
            }
            do {
                // Stop any existing meeting before starting a new one
                if meetingSession != nil {
                    stopMeeting()
                }
                try startMeeting(meetingMap: meetingMap, attendeeMap: attendeeMap)
                result(true)
            } catch {
                result(FlutterError(code: "START_FAILED", message: error.localizedDescription, details: nil))
            }

        case "stopMeeting":
            stopMeeting()
            result(true)

        case "setMute":
            guard let args = call.arguments as? [String: Any],
                  let muted = args["muted"] as? Bool else {
                result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
                return
            }
            if muted {
                _ = meetingSession?.audioVideo.realtimeLocalMute()
            } else {
                _ = meetingSession?.audioVideo.realtimeLocalUnmute()
            }
            sendEvent(type: muted ? "localMute" : "localUnmute", data: [:])
            result(true)

        case "startLocalVideo":
            do {
                try meetingSession?.audioVideo.startLocalVideo()
                result(true)
            } catch {
                result(FlutterError(code: "VIDEO_FAILED", message: error.localizedDescription, details: nil))
            }

        case "stopLocalVideo":
            meetingSession?.audioVideo.stopLocalVideo()
            result(true)

        case "switchCamera":
            meetingSession?.audioVideo.switchCamera()
            result(true)

        case "bindVideoView":
            if let args = call.arguments as? [String: Any],
               let tileId = args["tileId"] as? Int {
                if let view = videoViewFactory.activeViews[tileId] {
                    meetingSession?.audioVideo.bindVideoView(videoView: view.getVideoRenderView(), tileId: tileId)
                }
            }
            result(true)

        case "unbindVideoView":
            if let args = call.arguments as? [String: Any],
               let tileId = args["tileId"] as? Int {
                meetingSession?.audioVideo.unbindVideoView(tileId: tileId)
                videoViewFactory.removeView(tileId: tileId)
            }
            result(true)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // ─── Chime SDK Initialization ───

    private func startMeeting(meetingMap: [String: Any], attendeeMap: [String: Any]) throws {
        let mediaPlacementMap = meetingMap["MediaPlacement"] as? [String: Any]

        let mediaPlacement = MediaPlacement(
            audioFallbackUrl: mediaPlacementMap?["AudioFallbackUrl"] as? String ?? "",
            audioHostUrl: mediaPlacementMap?["AudioHostUrl"] as? String ?? "",
            signalingUrl: mediaPlacementMap?["SignalingUrl"] as? String ?? "",
            turnControlUrl: mediaPlacementMap?["TurnControlUrl"] as? String ?? "",
            eventIngestionUrl: mediaPlacementMap?["EventIngestionUrl"] as? String
        )

        let meeting = Meeting(
            externalMeetingId: meetingMap["ExternalMeetingId"] as? String,
            mediaPlacement: mediaPlacement,
            mediaRegion: meetingMap["MediaRegion"] as? String ?? "us-east-1",
            meetingId: meetingMap["MeetingId"] as? String ?? ""
        )

        let attendee = Attendee(
            attendeeId: attendeeMap["AttendeeId"] as? String ?? "",
            externalUserId: attendeeMap["ExternalUserId"] as? String ?? "",
            joinToken: attendeeMap["JoinToken"] as? String ?? ""
        )

        let configuration = MeetingSessionConfiguration(
            createMeetingResponse: CreateMeetingResponse(meeting: meeting),
            createAttendeeResponse: CreateAttendeeResponse(attendee: attendee)
        )

        let logger = ConsoleLogger(name: "ChimeSDK", level: .INFO)
        meetingSession = DefaultMeetingSession(configuration: configuration, logger: logger)

        meetingSession?.audioVideo.addAudioVideoObserver(observer: self)
        meetingSession?.audioVideo.addVideoTileObserver(observer: self)
        meetingSession?.audioVideo.addRealtimeObserver(observer: self)
        meetingSession?.audioVideo.addDeviceChangeObserver(observer: self)
        meetingSession?.audioVideo.addMetricsObserver(observer: self)

        try meetingSession?.audioVideo.start()
        meetingSession?.audioVideo.startRemoteVideo()
    }

    private func stopMeeting() {
        meetingSession?.audioVideo.stopLocalVideo()
        meetingSession?.audioVideo.stopRemoteVideo()
        meetingSession?.audioVideo.stop()

        meetingSession?.audioVideo.removeAudioVideoObserver(observer: self)
        meetingSession?.audioVideo.removeVideoTileObserver(observer: self)
        meetingSession?.audioVideo.removeRealtimeObserver(observer: self)
        meetingSession?.audioVideo.removeDeviceChangeObserver(observer: self)
        meetingSession?.audioVideo.removeMetricsObserver(observer: self)

        meetingSession = nil
        sendEvent(type: "meetingStopped", data: ["reason": "userLeft"])
    }

    // ─── Event Emission ───

    func sendEvent(type: String, data: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(["type": type, "data": data])
        }
    }

    func setEventSink(_ sink: FlutterEventSink?) {
        self.eventSink = sink
    }
}

// ─── AudioVideoObserver ───

extension AppDelegate: AudioVideoObserver {
    func audioSessionDidStartConnecting(reconnecting: Bool) {}

    func audioSessionDidStart(reconnecting: Bool) {
        do {
            sendEvent(type: "audioSessionStarted", data: ["reconnecting": reconnecting])
            sendEvent(type: "meetingStarted", data: [:])
        } catch { sendEvent(type: "error", data: ["message": "Callback error: \(error)"]) }
    }

    func audioSessionDidDrop() {
        sendEvent(type: "networkDegraded", data: [:])
    }

    func audioSessionDidStopWithStatus(sessionStatus: MeetingSessionStatus) {
        sendEvent(type: "audioSessionStopped", data: [:])
    }

    func audioSessionDidCancelReconnect() {
        sendEvent(type: "sessionFailure", data: ["error": "Reconnection cancelled"])
    }

    func connectionDidBecomePoor() {
        sendEvent(type: "networkDegraded", data: [:])
    }

    func connectionDidRecover() {
        sendEvent(type: "connectionRecovered", data: [:])
    }

    func videoSessionDidStartConnecting() {}

    func videoSessionDidStartWithStatus(sessionStatus: MeetingSessionStatus) {}

    func videoSessionDidStopWithStatus(sessionStatus: MeetingSessionStatus) {}

    func remoteVideoSourcesDidBecomeAvailable(sources: [RemoteVideoSource]) {}

    func remoteVideoSourcesDidBecomeUnavailable(sources: [RemoteVideoSource]) {}

    func cameraSendAvailabilityDidChange(available: Bool) {}
}

// ─── VideoTileObserver ───

extension AppDelegate: VideoTileObserver {
    func videoTileDidAdd(tileState: VideoTileState) {
        do {
            sendEvent(type: "videoTileAdded", data: [
                "tileId": tileState.tileId,
                "isLocal": tileState.isLocalTile,
                "attendeeId": tileState.attendeeId ?? "",
                "pauseState": "\(tileState.pauseState)"
            ])
        } catch { sendEvent(type: "error", data: ["message": "Callback error: \(error)"]) }
    }

    func videoTileDidRemove(tileState: VideoTileState) {
        do {
            sendEvent(type: "videoTileRemoved", data: [
                "tileId": tileState.tileId,
                "isLocal": tileState.isLocalTile
            ])
        } catch { sendEvent(type: "error", data: ["message": "Callback error: \(error)"]) }
    }

    func videoTileDidPause(tileState: VideoTileState) {
        sendEvent(type: "videoTilePaused", data: ["tileId": tileState.tileId])
    }

    func videoTileDidResume(tileState: VideoTileState) {
        sendEvent(type: "videoTileResumed", data: ["tileId": tileState.tileId])
    }

    func videoTileSizeDidChange(tileState: VideoTileState) {}
}

// ─── RealtimeObserver ───

extension AppDelegate: RealtimeObserver {
    func attendeesDidJoin(attendeeInfo: [AttendeeInfo]) {
        do {
            for info in attendeeInfo {
                sendEvent(type: "attendeeJoined", data: [
                    "attendeeId": info.attendeeId,
                    "externalUserId": info.externalUserId
                ])
            }
        } catch { sendEvent(type: "error", data: ["message": "Callback error: \(error)"]) }
    }

    func attendeesDidLeave(attendeeInfo: [AttendeeInfo]) {
        do {
            for info in attendeeInfo {
                sendEvent(type: "attendeeLeft", data: [
                    "attendeeId": info.attendeeId,
                    "externalUserId": info.externalUserId
                ])
            }
        } catch { sendEvent(type: "error", data: ["message": "Callback error: \(error)"]) }
    }

    func attendeesDidDrop(attendeeInfo: [AttendeeInfo]) {
        do {
            for info in attendeeInfo {
                sendEvent(type: "attendeeLeft", data: [
                    "attendeeId": info.attendeeId,
                    "externalUserId": info.externalUserId
                ])
            }
        } catch { sendEvent(type: "error", data: ["message": "Callback error: \(error)"]) }
    }

    func attendeesDidMute(attendeeInfo: [AttendeeInfo]) {
        for info in attendeeInfo {
            sendEvent(type: "remoteMute", data: ["attendeeId": info.attendeeId])
        }
    }

    func attendeesDidUnmute(attendeeInfo: [AttendeeInfo]) {
        for info in attendeeInfo {
            sendEvent(type: "remoteUnmute", data: ["attendeeId": info.attendeeId])
        }
    }

    func volumeDidChange(volumeUpdates: [VolumeUpdate]) {
        for update in volumeUpdates {
            sendEvent(type: "volumeChanged", data: [
                "attendeeId": update.attendeeInfo.attendeeId,
                "volume": "\(update.volumeLevel)"
            ])
        }
    }

    func signalStrengthDidChange(signalUpdates: [SignalUpdate]) {}
}

// ─── DeviceChangeObserver ───

extension AppDelegate: DeviceChangeObserver {
    func audioDeviceDidChange(freshAudioDeviceList: [MediaDevice]) {
        let deviceLabel = freshAudioDeviceList.first?.label ?? "unknown"
        sendEvent(type: "deviceChanged", data: ["device": deviceLabel])
    }
}

// ─── MetricsObserver ───

extension AppDelegate: MetricsObserver {
    func metricsDidReceive(metrics: [AnyHashable: Any]) {
        // Extract available bitrate from Chime SDK metrics
        if let sendBw = metrics[ObservableMetric.videoAvailableSendBandwidth] as? Double, sendBw > 0 {
            let bitrateKbps = Int(sendBw / 1000)
            sendEvent(type: "metricsReceived", data: ["bitrateKbps": bitrateKbps])
        } else if let recvBw = metrics[ObservableMetric.videoAvailableReceiveBandwidth] as? Double, recvBw > 0 {
            let bitrateKbps = Int(recvBw / 1000)
            sendEvent(type: "metricsReceived", data: ["bitrateKbps": bitrateKbps])
        }
    }
}

// ─── Event Stream Handler ───

class ChimeEventStreamHandler: NSObject, FlutterStreamHandler {
    private weak var appDelegate: AppDelegate?

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        appDelegate?.setEventSink(events)
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        appDelegate?.setEventSink(nil)
        return nil
    }
}

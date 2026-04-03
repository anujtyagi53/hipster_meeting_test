package com.hipster.hipster_meeting_test

import com.amazonaws.services.chime.sdk.meetings.audiovideo.AudioVideoFacade
import com.amazonaws.services.chime.sdk.meetings.audiovideo.AudioVideoObserver
import com.amazonaws.services.chime.sdk.meetings.audiovideo.video.VideoTileObserver
import com.amazonaws.services.chime.sdk.meetings.audiovideo.video.VideoTileState
import com.amazonaws.services.chime.sdk.meetings.audiovideo.metric.MetricsObserver
import com.amazonaws.services.chime.sdk.meetings.audiovideo.metric.ObservableMetric

import com.amazonaws.services.chime.sdk.meetings.device.DeviceChangeObserver
import com.amazonaws.services.chime.sdk.meetings.device.MediaDevice
import com.amazonaws.services.chime.sdk.meetings.realtime.RealtimeObserver
import com.amazonaws.services.chime.sdk.meetings.session.*
import com.amazonaws.services.chime.sdk.meetings.utils.logger.ConsoleLogger
import com.amazonaws.services.chime.sdk.meetings.utils.logger.LogLevel
import com.amazonaws.services.chime.sdk.meetings.audiovideo.AttendeeInfo
import com.amazonaws.services.chime.sdk.meetings.audiovideo.SignalUpdate
import com.amazonaws.services.chime.sdk.meetings.audiovideo.VolumeUpdate
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity(),
    AudioVideoObserver, VideoTileObserver, RealtimeObserver, DeviceChangeObserver, MetricsObserver {

    private val METHOD_CHANNEL = "com.hipster.chime/meeting"
    private val EVENT_CHANNEL = "com.hipster.chime/events"
    private val DEEPLINK_CHANNEL = "com.hipster.chime/deeplink"
    private val logger = ConsoleLogger(LogLevel.INFO)

    private var eventSink: EventChannel.EventSink? = null
    private var meetingSession: MeetingSession? = null
    private val videoViewFactory = ChimeVideoViewFactory()
    private var pendingDeepLink: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Capture deep link from launch intent
        pendingDeepLink = intent?.data?.toString()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startMeeting" -> {
                        val meetingMap = call.argument<Map<String, Any>>("meeting")
                        val attendeeMap = call.argument<Map<String, Any>>("attendee")
                        if (meetingMap == null || attendeeMap == null) {
                            result.error("INVALID_ARGS", "Meeting or attendee data is null", null)
                            return@setMethodCallHandler
                        }
                        try {
                            // Stop any existing meeting before starting a new one
                            if (meetingSession != null) {
                                stopMeeting()
                            }
                            startMeeting(meetingMap, attendeeMap)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("START_FAILED", e.message, null)
                        }
                    }
                    "stopMeeting" -> {
                        stopMeeting()
                        result.success(true)
                    }
                    "setMute" -> {
                        val muted = call.argument<Boolean>("muted") ?: false
                        if (muted) {
                            meetingSession?.audioVideo?.realtimeLocalMute()
                        } else {
                            meetingSession?.audioVideo?.realtimeLocalUnmute()
                        }
                        sendEvent(if (muted) "localMute" else "localUnmute", mapOf<String, Any>())
                        result.success(true)
                    }
                    "startLocalVideo" -> {
                        try {
                            meetingSession?.audioVideo?.startLocalVideo()
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("VIDEO_FAILED", e.message, null)
                        }
                    }
                    "stopLocalVideo" -> {
                        meetingSession?.audioVideo?.stopLocalVideo()
                        result.success(true)
                    }
                    "switchCamera" -> {
                        meetingSession?.audioVideo?.switchCamera()
                        result.success(true)
                    }
                    "bindVideoView" -> {
                        val tileId = call.argument<Int>("tileId")
                        if (tileId != null) {
                            val view = videoViewFactory.activeViews[tileId]
                            if (view != null) {
                                meetingSession?.audioVideo?.bindVideoView(
                                    view.getVideoRenderView(), tileId
                                )
                            }
                        }
                        result.success(true)
                    }
                    "unbindVideoView" -> {
                        val tileId = call.argument<Int>("tileId")
                        if (tileId != null) {
                            meetingSession?.audioVideo?.unbindVideoView(tileId)
                            videoViewFactory.removeView(tileId)
                        }
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })

        // Deep link channel
        val deepLinkChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEEPLINK_CHANNEL)
        deepLinkChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialLink" -> {
                    result.success(pendingDeepLink)
                    pendingDeepLink = null
                }
                else -> result.notImplemented()
            }
        }

        flutterEngine.platformViewsController.registry
            .registerViewFactory("chime_video_view", videoViewFactory)
    }

    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        val link = intent.data?.toString()
        if (link != null) {
            MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, DEEPLINK_CHANNEL)
                .invokeMethod("onDeepLink", link)
        }
    }

    override fun onDestroy() {
        if (meetingSession != null) {
            stopMeeting()
        }
        super.onDestroy()
    }

    // ─── Chime SDK Initialization ───

    private fun startMeeting(meetingMap: Map<String, Any>, attendeeMap: Map<String, Any>) {
        val mediaPlacementMap = meetingMap["MediaPlacement"] as? Map<*, *>

        val mediaPlacement = MediaPlacement(
            AudioFallbackUrl = mediaPlacementMap?.get("AudioFallbackUrl") as? String ?: "",
            AudioHostUrl = mediaPlacementMap?.get("AudioHostUrl") as? String ?: "",
            SignalingUrl = mediaPlacementMap?.get("SignalingUrl") as? String ?: "",
            TurnControlUrl = mediaPlacementMap?.get("TurnControlUrl") as? String ?: "",
            EventIngestionUrl = mediaPlacementMap?.get("EventIngestionUrl") as? String ?: ""
        )

        val meeting = Meeting(
            ExternalMeetingId = meetingMap["ExternalMeetingId"] as? String,
            MediaPlacement = mediaPlacement,
            MediaRegion = meetingMap["MediaRegion"] as? String ?: "us-east-1",
            MeetingId = meetingMap["MeetingId"] as? String ?: ""
        )

        val attendee = Attendee(
            AttendeeId = attendeeMap["AttendeeId"] as? String ?: "",
            ExternalUserId = attendeeMap["ExternalUserId"] as? String ?: "",
            JoinToken = attendeeMap["JoinToken"] as? String ?: ""
        )

        val configuration = MeetingSessionConfiguration(
            CreateMeetingResponse(meeting),
            CreateAttendeeResponse(attendee)
        )

        meetingSession = DefaultMeetingSession(configuration, logger, applicationContext)

        meetingSession?.audioVideo?.addAudioVideoObserver(this)
        meetingSession?.audioVideo?.addVideoTileObserver(this)
        meetingSession?.audioVideo?.addRealtimeObserver(this)
        meetingSession?.audioVideo?.addDeviceChangeObserver(this)
        meetingSession?.audioVideo?.addMetricsObserver(this)

        meetingSession?.audioVideo?.start()
        meetingSession?.audioVideo?.startRemoteVideo()
    }

    private fun stopMeeting() {
        meetingSession?.audioVideo?.stopLocalVideo()
        meetingSession?.audioVideo?.stopRemoteVideo()
        meetingSession?.audioVideo?.stop()

        meetingSession?.audioVideo?.removeAudioVideoObserver(this)
        meetingSession?.audioVideo?.removeVideoTileObserver(this)
        meetingSession?.audioVideo?.removeRealtimeObserver(this)
        meetingSession?.audioVideo?.removeDeviceChangeObserver(this)
        meetingSession?.audioVideo?.removeMetricsObserver(this)

        meetingSession = null
        sendEvent("meetingStopped", mapOf("reason" to "userLeft"))
    }

    // ─── AudioVideoObserver ───

    override fun onAudioSessionStartedConnecting(reconnecting: Boolean) {}

    override fun onAudioSessionStarted(reconnecting: Boolean) {
        try {
            sendEvent("audioSessionStarted", mapOf("reconnecting" to reconnecting))
            sendEvent("meetingStarted", mapOf<String, Any>())
        } catch (e: Exception) {
            sendEvent("error", mapOf("message" to "Callback error: ${e.message}"))
        }
    }

    override fun onAudioSessionDropped() {
        try { sendEvent("networkDegraded", mapOf<String, Any>()) }
        catch (e: Exception) { sendEvent("error", mapOf("message" to "Callback error: ${e.message}")) }
    }

    override fun onAudioSessionStopped(sessionStatus: MeetingSessionStatus) {
        try { sendEvent("audioSessionStopped", mapOf<String, Any>()) }
        catch (e: Exception) { sendEvent("error", mapOf("message" to "Callback error: ${e.message}")) }
    }

    override fun onAudioSessionCancelledReconnect() {
        try { sendEvent("sessionFailure", mapOf("error" to "Reconnection cancelled")) }
        catch (e: Exception) { sendEvent("error", mapOf("message" to "Callback error: ${e.message}")) }
    }

    override fun onConnectionBecamePoor() {
        try { sendEvent("networkDegraded", mapOf<String, Any>()) }
        catch (e: Exception) { sendEvent("error", mapOf("message" to "Callback error: ${e.message}")) }
    }

    override fun onConnectionRecovered() {
        try { sendEvent("connectionRecovered", mapOf<String, Any>()) }
        catch (e: Exception) { sendEvent("error", mapOf("message" to "Callback error: ${e.message}")) }
    }

    override fun onVideoSessionStartedConnecting() {}

    override fun onVideoSessionStarted(sessionStatus: MeetingSessionStatus) {}

    override fun onVideoSessionStopped(sessionStatus: MeetingSessionStatus) {}

    override fun onRemoteVideoSourceAvailable(sources: List<com.amazonaws.services.chime.sdk.meetings.audiovideo.video.RemoteVideoSource>) {}

    override fun onRemoteVideoSourceUnavailable(sources: List<com.amazonaws.services.chime.sdk.meetings.audiovideo.video.RemoteVideoSource>) {}

    override fun onCameraSendAvailabilityUpdated(available: Boolean) {}

    // ─── VideoTileObserver ───

    override fun onVideoTileAdded(tileState: VideoTileState) {
        try {
            sendEvent("videoTileAdded", mapOf(
                "tileId" to tileState.tileId,
                "isLocal" to tileState.isLocalTile,
                "attendeeId" to (tileState.attendeeId ?: ""),
                "pauseState" to tileState.pauseState.name
            ))
        } catch (e: Exception) {
            sendEvent("error", mapOf("message" to "Callback error: ${e.message}"))
        }
    }

    override fun onVideoTileRemoved(tileState: VideoTileState) {
        try {
            sendEvent("videoTileRemoved", mapOf(
                "tileId" to tileState.tileId,
                "isLocal" to tileState.isLocalTile
            ))
        } catch (e: Exception) {
            sendEvent("error", mapOf("message" to "Callback error: ${e.message}"))
        }
    }

    override fun onVideoTilePaused(tileState: VideoTileState) {
        try { sendEvent("videoTilePaused", mapOf("tileId" to tileState.tileId)) }
        catch (e: Exception) { sendEvent("error", mapOf("message" to "Callback error: ${e.message}")) }
    }

    override fun onVideoTileResumed(tileState: VideoTileState) {
        try { sendEvent("videoTileResumed", mapOf("tileId" to tileState.tileId)) }
        catch (e: Exception) { sendEvent("error", mapOf("message" to "Callback error: ${e.message}")) }
    }

    override fun onVideoTileSizeChanged(tileState: VideoTileState) {}

    // ─── RealtimeObserver ───

    override fun onAttendeesJoined(attendeeInfo: Array<AttendeeInfo>) {
        try {
            for (info in attendeeInfo) {
                sendEvent("attendeeJoined", mapOf(
                    "attendeeId" to info.attendeeId,
                    "externalUserId" to info.externalUserId
                ))
            }
        } catch (e: Exception) {
            sendEvent("error", mapOf("message" to "Callback error: ${e.message}"))
        }
    }

    override fun onAttendeesLeft(attendeeInfo: Array<AttendeeInfo>) {
        try {
            for (info in attendeeInfo) {
                sendEvent("attendeeLeft", mapOf(
                    "attendeeId" to info.attendeeId,
                    "externalUserId" to info.externalUserId
                ))
            }
        } catch (e: Exception) {
            sendEvent("error", mapOf("message" to "Callback error: ${e.message}"))
        }
    }

    override fun onAttendeesDropped(attendeeInfo: Array<AttendeeInfo>) {
        try {
            for (info in attendeeInfo) {
                sendEvent("attendeeLeft", mapOf(
                    "attendeeId" to info.attendeeId,
                    "externalUserId" to info.externalUserId
                ))
            }
        } catch (e: Exception) {
            sendEvent("error", mapOf("message" to "Callback error: ${e.message}"))
        }
    }

    override fun onAttendeesMuted(attendeeInfo: Array<AttendeeInfo>) {
        try {
            for (info in attendeeInfo) {
                sendEvent("remoteMute", mapOf("attendeeId" to info.attendeeId))
            }
        } catch (e: Exception) {
            sendEvent("error", mapOf("message" to "Callback error: ${e.message}"))
        }
    }

    override fun onAttendeesUnmuted(attendeeInfo: Array<AttendeeInfo>) {
        try {
            for (info in attendeeInfo) {
                sendEvent("remoteUnmute", mapOf("attendeeId" to info.attendeeId))
            }
        } catch (e: Exception) {
            sendEvent("error", mapOf("message" to "Callback error: ${e.message}"))
        }
    }

    override fun onVolumeChanged(volumeUpdates: Array<VolumeUpdate>) {
        try {
            for (update in volumeUpdates) {
                sendEvent("volumeChanged", mapOf(
                    "attendeeId" to update.attendeeInfo.attendeeId,
                    "volume" to update.volumeLevel.name
                ))
            }
        } catch (e: Exception) {
            sendEvent("error", mapOf("message" to "Callback error: ${e.message}"))
        }
    }

    override fun onSignalStrengthChanged(signalUpdates: Array<SignalUpdate>) {}

    // ─── DeviceChangeObserver ───

    override fun onAudioDeviceChanged(freshAudioDeviceList: List<MediaDevice>) {
        try {
            sendEvent("deviceChanged", mapOf(
                "device" to (freshAudioDeviceList.firstOrNull()?.label ?: "unknown")
            ))
        } catch (e: Exception) {
            sendEvent("error", mapOf("message" to "Callback error: ${e.message}"))
        }
    }

    // ─── MetricsObserver ───

    override fun onMetricsReceived(metrics: Map<ObservableMetric, Any>) {
        try {
            val sendBw = metrics[ObservableMetric.videoAvailableSendBandwidth]
            val recvBw = metrics[ObservableMetric.videoAvailableReceiveBandwidth]
            val bw = (sendBw as? Double) ?: (recvBw as? Double)
            if (bw != null && bw > 0) {
                val bitrateKbps = (bw / 1000).toInt()
                sendEvent("metricsReceived", mapOf("bitrateKbps" to bitrateKbps))
            }
        } catch (_: Exception) {
            // Silently ignore metrics errors to avoid flooding event log
        }
    }

    // ─── Event Emission ───

    private fun sendEvent(type: String, data: Map<String, Any>) {
        runOnUiThread {
            eventSink?.success(mapOf("type" to type, "data" to data))
        }
    }
}

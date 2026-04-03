import 'dart:async';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hipster_meeting_test/enums/meeting_event_type.dart';
import 'package:hipster_meeting_test/models/meeting_event_model.dart';
import 'package:hipster_meeting_test/models/meeting_model.dart';
import 'package:hipster_meeting_test/models/attendee_model.dart';
import 'package:hipster_meeting_test/utils/app_logger.dart';

/// Platform bridge layer for Amazon Chime SDK.
/// Communicates with native iOS/Android Chime SDK via MethodChannel.
class ChimeService extends GetxService {
  static const _channel = MethodChannel('com.hipster.chime/meeting');
  static const _eventChannel = EventChannel('com.hipster.chime/events');

  // Reactive state
  final isMeetingActive = false.obs;
  final isMicEnabled = true.obs;
  final isCameraEnabled = false.obs;
  final isUsingFrontCamera = true.obs;
  final localVideoTileId = Rxn<int>();
  final remoteVideoTileId = Rxn<int>();
  final remoteAttendeeId = Rxn<String>();
  final networkQuality = 'Good'.obs;
  final reconnectAttempts = 0.obs;
  final bitrateKbps = Rxn<int>();
  final sessionStartTime = Rxn<DateTime>();

  // Track local attendee to distinguish remote from local
  String? _localAttendeeId;
  String? get localAttendeeId => _localAttendeeId;

  String get sessionDuration {
    final start = sessionStartTime.value;
    if (start == null) return '--:--';
    final diff = DateTime.now().difference(start);
    if (diff.isNegative) return '00:00';
    final m = diff.inMinutes.toString().padLeft(2, '0');
    final s = (diff.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // Event stream
  final _eventController = StreamController<MeetingEventModel>.broadcast();
  Stream<MeetingEventModel> get eventStream => _eventController.stream;

  StreamSubscription? _nativeEventSubscription;

  @override
  void onInit() {
    super.onInit();
    _listenToNativeEvents();
  }

  void _listenToNativeEvents() {
    _nativeEventSubscription = _eventChannel
        .receiveBroadcastStream()
        .listen(
      (event) {
        try {
          if (event is Map) {
            _handleNativeEvent(_deepCastMap(event));
          }
        } catch (e) {
          AppLogger.error('Error handling native event', tag: 'CHIME', error: e);
          _emitEvent(MeetingEventType.error, 'Error processing callback: $e');
        }
      },
      onError: (error) {
        AppLogger.error('Native event stream error', tag: 'CHIME', error: error);
        _emitEvent(MeetingEventType.error, 'Event stream error: $error');
      },
    );
  }

  static Map<String, dynamic> _deepCastMap(Map map) {
    return map.map((key, value) => MapEntry(
          key.toString(),
          value is Map ? _deepCastMap(value) : value,
        ));
  }

  void _handleNativeEvent(Map<String, dynamic> event) {
    final type = event['type'] as String?;
    final data = (event['data'] as Map<String, dynamic>?) ?? {};

    switch (type) {
      case 'meetingStarted':
        isMeetingActive.value = true;
        sessionStartTime.value = DateTime.now();
        _emitEvent(MeetingEventType.meetingStarted, 'Meeting session started');
        break;
      case 'metricsReceived':
        bitrateKbps.value = data['bitrateKbps'] as int?;
        break;
      case 'meetingStopped':
        isMeetingActive.value = false;
        _resetState();
        _emitEvent(MeetingEventType.meetingStopped,
            'Meeting session stopped: ${data['reason'] ?? 'unknown'}');
        break;
      case 'audioSessionStarted':
        _emitEvent(MeetingEventType.audioSessionStarted,
            'Audio session started (reconnecting: ${data['reconnecting'] ?? false})');
        break;
      case 'audioSessionStopped':
        _emitEvent(MeetingEventType.audioSessionStopped, 'Audio session stopped');
        break;
      case 'attendeeJoined':
        final attendeeId = data['attendeeId'] ?? '';
        final externalId = data['externalUserId'] ?? '';
        if (attendeeId != _localAttendeeId) {
          remoteAttendeeId.value = attendeeId;
        }
        _emitEvent(MeetingEventType.attendeeJoined,
            'Attendee joined: $externalId ($attendeeId)');
        break;
      case 'attendeeLeft':
        final attendeeId = data['attendeeId'] ?? '';
        final externalId = data['externalUserId'] ?? '';
        if (remoteAttendeeId.value == attendeeId) {
          remoteAttendeeId.value = null;
          remoteVideoTileId.value = null;
        }
        _emitEvent(MeetingEventType.attendeeLeft,
            'Attendee left: $externalId ($attendeeId)');
        break;
      case 'localMute':
        isMicEnabled.value = false;
        _emitEvent(MeetingEventType.localMute, 'Local audio muted');
        break;
      case 'localUnmute':
        isMicEnabled.value = true;
        _emitEvent(MeetingEventType.localUnmute, 'Local audio unmuted');
        break;
      case 'remoteMute':
        _emitEvent(MeetingEventType.remoteMute,
            'Remote attendee muted: ${data['attendeeId']}');
        break;
      case 'remoteUnmute':
        _emitEvent(MeetingEventType.remoteUnmute,
            'Remote attendee unmuted: ${data['attendeeId']}');
        break;
      case 'videoTileAdded':
        final tileId = data['tileId'] as int?;
        final isLocal = data['isLocal'] as bool? ?? false;
        if (isLocal) {
          localVideoTileId.value = tileId;
        } else {
          remoteVideoTileId.value = tileId;
        }
        _emitEvent(MeetingEventType.videoTileAdded,
            '${isLocal ? "Local" : "Remote"} video tile added (id: $tileId)');
        break;
      case 'videoTileRemoved':
        final tileId = data['tileId'] as int?;
        final isLocal = data['isLocal'] as bool? ?? false;
        if (isLocal) {
          localVideoTileId.value = null;
        } else {
          remoteVideoTileId.value = null;
        }
        _emitEvent(MeetingEventType.videoTileRemoved,
            '${isLocal ? "Local" : "Remote"} video tile removed (id: $tileId)');
        break;
      case 'videoTilePaused':
        _emitEvent(MeetingEventType.videoTilePaused,
            'Video tile paused (id: ${data['tileId']})');
        break;
      case 'videoTileResumed':
        _emitEvent(MeetingEventType.videoTileResumed,
            'Video tile resumed (id: ${data['tileId']})');
        break;
      case 'activeSpeaker':
        _emitEvent(MeetingEventType.activeSpeaker,
            'Active speaker: ${data['attendeeId']}');
        break;
      case 'volumeChanged':
        _emitEvent(MeetingEventType.volumeChanged,
            'Volume: ${data['attendeeId']} -> ${data['volume']}');
        break;
      case 'deviceChanged':
        _emitEvent(MeetingEventType.deviceChanged,
            'Device changed: ${data['device']}');
        break;
      case 'audioRouteChanged':
        _emitEvent(MeetingEventType.audioRouteChanged,
            'Audio route: ${data['route']}');
        break;
      case 'networkDegraded':
        networkQuality.value = 'Poor';
        _emitEvent(MeetingEventType.networkDegraded,
            'Network quality degraded');
        break;
      case 'reconnectAttempt':
        reconnectAttempts.value++;
        _emitEvent(MeetingEventType.reconnectAttempt,
            'Reconnect attempt #${reconnectAttempts.value}');
        break;
      case 'connectionRecovered':
        networkQuality.value = 'Good';
        reconnectAttempts.value = 0;
        _emitEvent(MeetingEventType.connectionRecovered,
            'Connection recovered');
        break;
      case 'sessionFailure':
        _emitEvent(MeetingEventType.sessionFailure,
            'Fatal: ${data['error'] ?? 'Session failure'}');
        break;
      default:
        _emitEvent(MeetingEventType.info, 'Unknown event: $type');
    }
  }

  void _emitEvent(MeetingEventType type, String message, {Map<String, dynamic>? metadata}) {
    if (_eventController.isClosed) return;
    final event = MeetingEventModel(type: type, message: message, metadata: metadata);
    _eventController.add(event);
    AppLogger.info('${type.label}: $message', tag: 'CHIME_EVENT');
  }

  // ─── Meeting Lifecycle ───

  Future<bool> startMeeting({
    required MeetingModel meeting,
    required AttendeeModel attendee,
  }) async {
    try {
      _localAttendeeId = attendee.attendeeId;
      AppLogger.info('Starting meeting: ${meeting.meetingId}', tag: 'CHIME');
      final result = await _channel.invokeMethod('startMeeting', {
        'meeting': meeting.toJson(),
        'attendee': attendee.toJson(),
      });
      return result == true;
    } on PlatformException catch (e) {
      AppLogger.error('Failed to start meeting', tag: 'CHIME', error: e);
      _emitEvent(MeetingEventType.error, 'Failed to start: ${e.message}');
      return false;
    }
  }

  Future<void> stopMeeting() async {
    try {
      await _channel.invokeMethod('stopMeeting');
      _resetState();
      AppLogger.info('Meeting stopped', tag: 'CHIME');
    } on PlatformException catch (e) {
      AppLogger.error('Failed to stop meeting', tag: 'CHIME', error: e);
    }
  }

  // ─── Audio Controls ───

  Future<void> toggleMute() async {
    try {
      final newState = !isMicEnabled.value;
      await _channel.invokeMethod('setMute', {'muted': !newState});
      isMicEnabled.value = newState;
    } on PlatformException catch (e) {
      AppLogger.error('Failed to toggle mute', tag: 'CHIME', error: e);
    }
  }

  // ─── Video Controls ───

  Future<void> toggleCamera() async {
    try {
      final newState = !isCameraEnabled.value;
      if (newState) {
        await _channel.invokeMethod('startLocalVideo');
      } else {
        await _channel.invokeMethod('stopLocalVideo');
      }
      isCameraEnabled.value = newState;
    } on PlatformException catch (e) {
      AppLogger.error('Failed to toggle camera', tag: 'CHIME', error: e);
    }
  }

  Future<void> switchCamera() async {
    try {
      await _channel.invokeMethod('switchCamera');
      isUsingFrontCamera.toggle();
      _emitEvent(MeetingEventType.deviceChanged,
          'Switched to ${isUsingFrontCamera.value ? "front" : "back"} camera');
    } on PlatformException catch (e) {
      AppLogger.error('Failed to switch camera', tag: 'CHIME', error: e);
    }
  }

  // ─── Video Rendering ───

  Future<void> bindVideoView(int tileId, int viewId) async {
    try {
      await _channel.invokeMethod('bindVideoView', {
        'tileId': tileId,
        'viewId': viewId,
      });
    } on PlatformException catch (e) {
      AppLogger.error('Failed to bind video view', tag: 'CHIME', error: e);
    }
  }

  Future<void> unbindVideoView(int tileId) async {
    try {
      await _channel.invokeMethod('unbindVideoView', {'tileId': tileId});
    } on PlatformException catch (e) {
      AppLogger.error('Failed to unbind video view', tag: 'CHIME', error: e);
    }
  }

  void _resetState() {
    isMeetingActive.value = false;
    isMicEnabled.value = true;
    isCameraEnabled.value = false;
    localVideoTileId.value = null;
    remoteVideoTileId.value = null;
    remoteAttendeeId.value = null;
    networkQuality.value = 'Good';
    reconnectAttempts.value = 0;
    bitrateKbps.value = null;
    sessionStartTime.value = null;
    _localAttendeeId = null;
  }

  @override
  void onClose() {
    _nativeEventSubscription?.cancel();
    _eventController.close();
    super.onClose();
  }
}

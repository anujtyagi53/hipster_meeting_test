import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hipster_meeting_test/enums/call_state.dart';
import 'package:hipster_meeting_test/enums/meeting_event_type.dart';
import 'package:hipster_meeting_test/models/meeting_data_model.dart';
import 'package:hipster_meeting_test/models/meeting_event_model.dart';
import 'package:hipster_meeting_test/repository/meeting_repository.dart';
import 'package:hipster_meeting_test/services/chime_service.dart';
import 'package:hipster_meeting_test/services/connectivity_service.dart';
import 'package:hipster_meeting_test/services/permission_service.dart';
import 'package:hipster_meeting_test/utils/app_colors.dart';
import 'package:hipster_meeting_test/utils/app_logger.dart';
import 'package:hipster_meeting_test/utils/constants.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class MeetingController extends GetxController with WidgetsBindingObserver {
  final ChimeService _chimeService = Get.find<ChimeService>();
  final ConnectivityService _connectivityService = Get.find<ConnectivityService>();
  final PermissionService _permissionService = Get.find<PermissionService>();
  final MeetingRepository _meetingRepository = Get.find<MeetingRepository>();

  // State
  final callState = CallState.idle.obs;
  final events = <MeetingEventModel>[].obs;
  final showEventLog = false.obs;
  final showDiagnostics = false.obs;
  final errorMessage = Rxn<String>();

  // Meeting data
  late MeetingDataModel meetingData;
  late bool isAgent;
  String get meetingId => meetingData.meeting?.meetingId ?? '';

  // Delegated from ChimeService
  RxBool get isMicEnabled => _chimeService.isMicEnabled;
  RxBool get isCameraEnabled => _chimeService.isCameraEnabled;
  RxBool get isUsingFrontCamera => _chimeService.isUsingFrontCamera;
  Rxn<int> get localVideoTileId => _chimeService.localVideoTileId;
  Rxn<int> get remoteVideoTileId => _chimeService.remoteVideoTileId;
  Rxn<String> get remoteAttendeeId => _chimeService.remoteAttendeeId;
  RxString get networkQuality => _chimeService.networkQuality;
  RxInt get reconnectAttempts => _chimeService.reconnectAttempts;
  RxBool get isConnected => _connectivityService.isConnected;

  // Reconnect logic
  Timer? _reconnectTimer;
  Timer? _staleSessionTimer;
  bool _isReconnecting = false;
  bool _joiningSession = false;
  bool _rejoinInProgress = false;
  bool _userLeftIntentionally = false;
  final reconnectCount = 0.obs;

  StreamSubscription? _eventSubscription;
  StreamSubscription? _connectivitySubscription;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);

    final args = Get.arguments as Map<String, dynamic>;
    meetingData = args['meetingData'] as MeetingDataModel;
    isAgent = args['isAgent'] as bool;

    subscribeToEvents();
    subscribeToConnectivity();
    startMeeting();
  }

  void subscribeToEvents() {
    _eventSubscription = _chimeService.eventStream.listen((event) {
      addEvent(event);
      handleMeetingEvent(event);
    });
  }

  void subscribeToConnectivity() {
    _connectivitySubscription = _connectivityService.isConnected.listen((connected) {
      if (!connected && callState.value == CallState.connected && !_userLeftIntentionally) {
        callState.value = CallState.reconnecting;
        addEvent(MeetingEventModel(
          type: MeetingEventType.networkDegraded,
          message: 'Network connection lost',
        ));
        startReconnect();
      } else if (connected && callState.value == CallState.reconnecting && !_userLeftIntentionally) {
        _reconnectTimer?.cancel();
        attemptRejoin();
      }
    });
  }

  void handleMeetingEvent(MeetingEventModel event) {
    switch (event.type) {
      case MeetingEventType.meetingStarted:
        if (_userLeftIntentionally) break;
        _joiningSession = false;
        callState.value = CallState.connected;
        startStaleSessionTimer();
        break;
      case MeetingEventType.meetingStopped:
        if (_joiningSession) {
          // Native stopMeeting() from startMeeting arrived async after the method returned.
          // Consume the guard here so the deferred event doesn't tear down the new session.
          _joiningSession = false;
          break;
        }
        if (callState.value == CallState.failed)
          break; // deferred cleanup after max-attempts; don't overwrite failure state
        _isReconnecting = false;
        callState.value = CallState.disconnected;
        reconnectCount.value = 0;
        cancelTimers();
        WakelockPlus.disable();
        break;
      case MeetingEventType.sessionFailure:
        _isReconnecting = false;
        _joiningSession = false;
        callState.value = CallState.failed;
        errorMessage.value = event.message;
        cancelTimers();
        WakelockPlus.disable();
        break;
      case MeetingEventType.reconnectAttempt:
        if (!_userLeftIntentionally) callState.value = CallState.reconnecting;
        break;
      case MeetingEventType.connectionRecovered:
        callState.value = CallState.connected;
        _isReconnecting = false;
        reconnectCount.value = 0;
        cancelTimers();
        break;
      case MeetingEventType.attendeeJoined:
        // Show snackbar only for remote participant (message won't contain local attendee ID)
        if (!event.message.contains(_chimeService.localAttendeeId ?? '___none___')) {
          Get.snackbar(
            'Participant Joined',
            'A participant has joined the meeting',
            snackPosition: SnackPosition.TOP,
            duration: const Duration(seconds: 3),
            backgroundColor: AppColors.success.withValues(alpha: 0.9),
            colorText: AppColors.white,
            icon: const Icon(Icons.person_add, color: AppColors.white),
            margin: const EdgeInsets.all(12),
            borderRadius: 12,
          );
        }
        break;
      case MeetingEventType.attendeeLeft:
        Get.snackbar(
          'Participant Left',
          'A participant has left the meeting',
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 3),
          backgroundColor: AppColors.warning.withValues(alpha: 0.9),
          colorText: AppColors.white,
          icon: const Icon(Icons.person_remove, color: AppColors.white),
          margin: const EdgeInsets.all(12),
          borderRadius: 12,
        );
        break;
      default:
        break;
    }
  }

  void addEvent(MeetingEventModel event) {
    events.insert(0, event);
    if (events.length > Constants.maxEventLogEntries) {
      events.removeLast();
    }
  }

  Future<void> startMeeting() async {
    _joiningSession = true;
    callState.value = CallState.joining;
    addEvent(MeetingEventModel(
      type: MeetingEventType.info,
      message: 'Requesting permissions...',
    ));

    final permissions = await _permissionService.requestMeetingPermissions();
    final micDenied = !(permissions['microphone'] ?? false);
    final camDenied = !(permissions['camera'] ?? false);

    if (micDenied) {
      addEvent(MeetingEventModel(
        type: MeetingEventType.error,
        message: 'Microphone permission denied.',
      ));
    }
    if (camDenied) {
      addEvent(MeetingEventModel(
        type: MeetingEventType.error,
        message: 'Camera permission denied.',
      ));
    }

    // If any permission permanently denied, offer to open settings
    if (micDenied || camDenied) {
      final micPerm = await _permissionService.isMicrophoneDeniedPermanently();
      final camPerm = await _permissionService.isCameraDeniedPermanently();
      if (micPerm || camPerm) {
        await showPermissionSettingsDialog(micPerm: micPerm, camPerm: camPerm);
        final updated = await _permissionService.requestMeetingPermissions();
        if (!(updated['microphone'] ?? false)) {
          addEvent(MeetingEventModel(
            type: MeetingEventType.error,
            message: 'Microphone still denied after settings. Audio will not work.',
          ));
        }
        if (!(updated['camera'] ?? false)) {
          addEvent(MeetingEventModel(
            type: MeetingEventType.error,
            message: 'Camera still denied after settings. Video will not work.',
          ));
        }
      }
    }

    addEvent(MeetingEventModel(
      type: MeetingEventType.info,
      message: 'Joining meeting: $meetingId as ${isAgent ? "agent" : "client"}',
    ));

    if (meetingData.meeting == null || meetingData.attendee == null) {
      _joiningSession = false;
      callState.value = CallState.failed;
      errorMessage.value = 'Invalid meeting data received';
      addEvent(MeetingEventModel(
        type: MeetingEventType.error,
        message: 'Meeting or attendee data is null',
      ));
      return;
    }

    // Join timeout
    Timer? joinTimer;
    joinTimer = Timer(Constants.joinTimeout, () {
      if (callState.value == CallState.joining) {
        callState.value = CallState.failed;
        errorMessage.value = 'Join timed out after ${Constants.joinTimeout.inSeconds}s';
        addEvent(MeetingEventModel(
          type: MeetingEventType.error,
          message: 'Join timeout exceeded',
        ));
      }
    });

    final success = await _chimeService.startMeeting(
      meeting: meetingData.meeting!,
      attendee: meetingData.attendee!,
    );

    joinTimer.cancel();
    if (callState.value == CallState.failed) {
      _joiningSession = false; // joinTimer fired before startMeeting returned
      return;
    }

    if (!success) {
      _joiningSession = false;
      callState.value = CallState.failed;
      errorMessage.value = 'Failed to join meeting';
      addEvent(MeetingEventModel(
        type: MeetingEventType.error,
        message: 'Failed to start meeting session',
      ));
      return;
    }

    WakelockPlus.enable();
  }

  Future<void> showPermissionSettingsDialog({
    required bool micPerm,
    required bool camPerm,
  }) async {
    final denied = <String>[];
    if (micPerm) denied.add('Microphone');
    if (camPerm) denied.add('Camera');
    final label = denied.join(' & ');

    final result = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('$label Permission Required', style: const TextStyle(color: AppColors.white)),
        content: Text(
          '$label access was permanently denied. '
          'Please enable it in Settings to use this feature.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Skip', style: TextStyle(color: AppColors.textHint)),
          ),
          TextButton(
            onPressed: () async {
              await _permissionService.openSettings();
              Get.back(result: true);
            },
            child: const Text('Open Settings', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
    // Small delay to let OS update permission state after returning from settings
    if (result == true) {
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  void confirmLeave() {
    if (_userLeftIntentionally) return;
    if (callState.value == CallState.failed || callState.value == CallState.disconnected) {
      Get.back();
      return;
    }
    Get.dialog(
      AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Leave Meeting?', style: TextStyle(color: AppColors.white)),
        content: const Text(
          'Are you sure you want to leave this meeting?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              leaveMeeting();
            },
            child: const Text('Leave', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Future<void> leaveMeeting() async {
    _userLeftIntentionally = true;
    _isReconnecting = false;
    cancelTimers();
    addEvent(MeetingEventModel(
      type: MeetingEventType.info,
      message: 'Leaving meeting...',
    ));
    await _chimeService.stopMeeting();
    callState.value = CallState.disconnected;
    WakelockPlus.disable();
    Get.back();
  }

  void retryJoin() {
    errorMessage.value = null;
    reconnectCount.value = 0;
    _isReconnecting = false;
    startMeeting();
  }

  void toggleMute() => _chimeService.toggleMute();
  void toggleCamera() => _chimeService.toggleCamera();
  void switchCamera() => _chimeService.switchCamera();

  void toggleEventLog() => showEventLog.toggle();
  void toggleDiagnostics() => showDiagnostics.toggle();

  void copyMeetingId() {
    final joinCode = buildJoinCode();
    Clipboard.setData(ClipboardData(text: joinCode));
    Get.snackbar('Copied', 'Meeting join code copied to clipboard',
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 1),
        backgroundColor: AppColors.surface,
        colorText: AppColors.white);
  }

  void shareMeeting() {
    final joinCode = buildJoinCode();
    final shareLink = buildShareLink();
    SharePlus.instance.share(
      ShareParams(
        text: 'Join my Hipster Meeting!\n\n'
            'Tap to join:\n$shareLink\n\n'
            'Or paste this code in the app:\n$joinCode',
      ),
    );
  }

  ({String? cell, String? region}) parseCellRegion() {
    final fallbackUrl = meetingData.meeting?.mediaPlacement?.audioFallbackUrl ?? '';
    final m = RegExp(r'wss://wss\.k\.(\w+)\.(\w+)\.app\.chime\.aws').firstMatch(fallbackUrl);
    return (cell: m?.group(1), region: m?.group(2));
  }

  String buildJoinCode() {
    final (:cell, :region) = parseCellRegion();
    if (cell != null && region != null) return '$meetingId:$cell:$region';
    AppLogger.warning('Could not extract cell/region from fallback URL', tag: 'MEETING');
    return meetingId;
  }

  String buildShareLink() {
    final (:cell, :region) = parseCellRegion();
    final base = Constants.deepLinkBaseUrl;
    if (cell != null && region != null) return '$base/join.html?meetingId=$meetingId&c=$cell&r=$region';
    return '$base/join.html?meetingId=$meetingId';
  }

  // ─── Reconnection Strategy ───

  void startReconnect() {
    if (_isReconnecting) return;
    _isReconnecting = true;
    reconnectCount.value = 0;
    scheduleReconnect();
  }

  void scheduleReconnect() {
    if (!_isReconnecting) return;
    if (reconnectCount.value >= Constants.reconnectMaxAttempts) {
      callState.value = CallState.failed;
      errorMessage.value = 'Failed to reconnect after ${Constants.reconnectMaxAttempts} attempts';
      _isReconnecting = false;
      _joiningSession = false; // no new session will be started; don't swallow future meetingStopped
      addEvent(MeetingEventModel(
        type: MeetingEventType.sessionFailure,
        message: 'Max reconnect attempts reached',
      ));
      return;
    }

    callState.value = CallState.reconnecting;
    final delay = Constants.reconnectBaseDelay * (1 << reconnectCount.value);
    reconnectCount.value++;

    addEvent(MeetingEventModel(
      type: MeetingEventType.info,
      message: 'Scheduling reconnect #${reconnectCount.value} in ${delay.inSeconds}s',
    ));

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, attemptRejoin);
  }

  Future<void> attemptRejoin() async {
    if (_rejoinInProgress) return;
    _rejoinInProgress = true;
    try {
      if (!_connectivityService.isConnected.value) {
        scheduleReconnect();
        return;
      }

      addEvent(MeetingEventModel(
        type: MeetingEventType.info,
        message: 'Attempting to rejoin meeting...',
      ));

      final result = isAgent
          ? await _meetingRepository.getAgentToken(meetingId)
          : await _meetingRepository.getClientToken(meetingId);

      await result.fold(
        (failure) async {
          AppLogger.error('Rejoin token fetch failed: ${failure.message}', tag: 'MEETING');
          scheduleReconnect();
        },
        (data) async {
          if (data.attendee == null) {
            AppLogger.error('Rejoin got null attendee data', tag: 'MEETING');
            scheduleReconnect();
            return;
          }
          // Prefer API-returned meeting data if it has MediaPlacement,
          // otherwise fall back to the original meeting data
          final apiMeeting = data.meeting;
          final mergedMeeting = (apiMeeting?.mediaPlacement != null) ? apiMeeting : meetingData.meeting ?? apiMeeting;
          meetingData = MeetingDataModel(
            meeting: mergedMeeting,
            attendee: data.attendee,
          );
          if (mergedMeeting?.mediaPlacement == null) {
            AppLogger.error('No MediaPlacement available for rejoin', tag: 'MEETING');
            scheduleReconnect();
            return;
          }
          _joiningSession = true;
          final success = await _chimeService.startMeeting(
            meeting: mergedMeeting!,
            attendee: data.attendee!,
          );
          if (success && !_userLeftIntentionally) {
            _isReconnecting = false;
            reconnectCount.value = 0;
            callState.value = CallState.connected;
            addEvent(MeetingEventModel(
              type: MeetingEventType.connectionRecovered,
              message: 'Successfully rejoined meeting',
            ));
          } else if (!success) {
            scheduleReconnect();
          }
        },
      );
    } finally {
      _rejoinInProgress = false;
    }
  }

  // ─── Stale Session Detection ───

  void startStaleSessionTimer() {
    _staleSessionTimer?.cancel();
    _staleSessionTimer = Timer(Constants.sessionStaleTimeout, () {
      addEvent(MeetingEventModel(
        type: MeetingEventType.info,
        message: 'Session may be stale. Consider refreshing.',
      ));
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        addEvent(MeetingEventModel(
          type: MeetingEventType.info,
          message: 'App moved to background',
        ));
        AppLogger.info('App backgrounded', tag: 'LIFECYCLE');
        break;
      case AppLifecycleState.resumed:
        addEvent(MeetingEventModel(
          type: MeetingEventType.info,
          message: 'App returned to foreground',
        ));
        AppLogger.info('App foregrounded', tag: 'LIFECYCLE');
        if (_userLeftIntentionally) break;
        if (callState.value == CallState.reconnecting) {
          _reconnectTimer?.cancel();
          if (!_isReconnecting) {
            _isReconnecting = true;
            reconnectCount.value = 0;
          }
          callState.value = CallState.reconnecting;
          attemptRejoin();
        } else if (callState.value == CallState.failed) {
          addEvent(MeetingEventModel(
            type: MeetingEventType.info,
            message: 'Meeting failed. Tap retry to reconnect.',
          ));
        }
        break;
      default:
        break;
    }
  }

  void cancelTimers() {
    _reconnectTimer?.cancel();
    _staleSessionTimer?.cancel();
  }

  @override
  void onClose() {
    _isReconnecting = false;
    _joiningSession = false;
    _rejoinInProgress = false;
    _userLeftIntentionally = false;
    WidgetsBinding.instance.removeObserver(this);
    _eventSubscription?.cancel();
    _connectivitySubscription?.cancel();
    cancelTimers();
    _chimeService.stopMeeting();
    WakelockPlus.disable();
    super.onClose();
  }
}

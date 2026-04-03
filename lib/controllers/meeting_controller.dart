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
  int _reconnectCount = 0;

  StreamSubscription? _eventSubscription;
  StreamSubscription? _connectivitySubscription;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);

    final args = Get.arguments as Map<String, dynamic>;
    meetingData = args['meetingData'] as MeetingDataModel;
    isAgent = args['isAgent'] as bool;

    _subscribeToEvents();
    _subscribeToConnectivity();
    _startMeeting();
  }

  void _subscribeToEvents() {
    _eventSubscription = _chimeService.eventStream.listen((event) {
      _addEvent(event);
      _handleMeetingEvent(event);
    });
  }

  void _subscribeToConnectivity() {
    _connectivitySubscription = _connectivityService.isConnected.listen((connected) {
      if (!connected && callState.value == CallState.connected) {
        callState.value = CallState.reconnecting;
        _addEvent(MeetingEventModel(
          type: MeetingEventType.networkDegraded,
          message: 'Network connection lost',
        ));
        _startReconnect();
      } else if (connected && callState.value == CallState.reconnecting) {
        _attemptRejoin();
      }
    });
  }

  void _handleMeetingEvent(MeetingEventModel event) {
    switch (event.type) {
      case MeetingEventType.meetingStarted:
        callState.value = CallState.connected;
        _startStaleSessionTimer();
        break;
      case MeetingEventType.meetingStopped:
        callState.value = CallState.disconnected;
        _isReconnecting = false;
        _reconnectCount = 0;
        _cancelTimers();
        WakelockPlus.disable();
        break;
      case MeetingEventType.sessionFailure:
        callState.value = CallState.failed;
        errorMessage.value = event.message;
        _cancelTimers();
        WakelockPlus.disable();
        break;
      case MeetingEventType.reconnectAttempt:
        callState.value = CallState.reconnecting;
        break;
      case MeetingEventType.connectionRecovered:
        callState.value = CallState.connected;
        _isReconnecting = false;
        _reconnectCount = 0;
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

  void _addEvent(MeetingEventModel event) {
    events.insert(0, event);
    if (events.length > Constants.maxEventLogEntries) {
      events.removeLast();
    }
  }

  // ─── Meeting Lifecycle ───

  Future<void> _startMeeting() async {
    callState.value = CallState.joining;
    _addEvent(MeetingEventModel(
      type: MeetingEventType.info,
      message: 'Requesting permissions...',
    ));

    final permissions = await _permissionService.requestMeetingPermissions();
    final micDenied = !(permissions['microphone'] ?? false);
    final camDenied = !(permissions['camera'] ?? false);

    if (micDenied) {
      _addEvent(MeetingEventModel(
        type: MeetingEventType.error,
        message: 'Microphone permission denied.',
      ));
    }
    if (camDenied) {
      _addEvent(MeetingEventModel(
        type: MeetingEventType.error,
        message: 'Camera permission denied.',
      ));
    }

    // If any permission permanently denied, offer to open settings
    if (micDenied || camDenied) {
      final micPerm = await _permissionService.isMicrophoneDeniedPermanently();
      final camPerm = await _permissionService.isCameraDeniedPermanently();
      if (micPerm || camPerm) {
        await _showPermissionSettingsDialog(micPerm: micPerm, camPerm: camPerm);
        // Re-check after returning from settings
        final updated = await _permissionService.requestMeetingPermissions();
        if (!(updated['microphone'] ?? false)) {
          _addEvent(MeetingEventModel(
            type: MeetingEventType.error,
            message: 'Microphone still denied after settings. Audio will not work.',
          ));
        }
        if (!(updated['camera'] ?? false)) {
          _addEvent(MeetingEventModel(
            type: MeetingEventType.error,
            message: 'Camera still denied after settings. Video will not work.',
          ));
        }
      }
    }

    _addEvent(MeetingEventModel(
      type: MeetingEventType.info,
      message: 'Joining meeting: $meetingId as ${isAgent ? "agent" : "client"}',
    ));

    if (meetingData.meeting == null || meetingData.attendee == null) {
      callState.value = CallState.failed;
      errorMessage.value = 'Invalid meeting data received';
      _addEvent(MeetingEventModel(
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
        _addEvent(MeetingEventModel(
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

    if (!success) {
      callState.value = CallState.failed;
      errorMessage.value = 'Failed to join meeting';
      _addEvent(MeetingEventModel(
        type: MeetingEventType.error,
        message: 'Failed to start meeting session',
      ));
      return;
    }

    WakelockPlus.enable();
  }

  Future<void> _showPermissionSettingsDialog({
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
        title: Text('$label Permission Required',
            style: const TextStyle(color: AppColors.white)),
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
    if (callState.value == CallState.failed ||
        callState.value == CallState.disconnected) {
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
    _addEvent(MeetingEventModel(
      type: MeetingEventType.info,
      message: 'Leaving meeting...',
    ));
    await _chimeService.stopMeeting();
    callState.value = CallState.disconnected;
    _cancelTimers();
    WakelockPlus.disable();
    Get.back();
  }

  void retryJoin() {
    errorMessage.value = null;
    _startMeeting();
  }

  // ─── Controls ───

  void toggleMute() => _chimeService.toggleMute();
  void toggleCamera() => _chimeService.toggleCamera();
  void switchCamera() => _chimeService.switchCamera();

  void toggleEventLog() => showEventLog.toggle();
  void toggleDiagnostics() => showDiagnostics.toggle();

  /// Copies the meeting join code to clipboard.
  /// Format: meetingId:cell:region (e.g. "abc-2954:m3:as1")
  /// The joining device parses this to construct correct server URLs.
  void copyMeetingId() {
    final joinCode = _buildJoinCode();
    Clipboard.setData(ClipboardData(text: joinCode));
    Get.snackbar('Copied', 'Meeting join code copied to clipboard',
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 1),
        backgroundColor: AppColors.surface,
        colorText: AppColors.white);
  }

  void shareMeeting() {
    final joinCode = _buildJoinCode();
    final shareLink = _buildShareLink();
    SharePlus.instance.share(
      ShareParams(
        text: 'Join my Hipster Meeting!\n\n'
            'Tap to join:\n$shareLink\n\n'
            'Or paste this code in the app:\n$joinCode',
      ),
    );
  }

  String _buildJoinCode() {
    final fallbackUrl = meetingData.meeting?.mediaPlacement?.audioFallbackUrl ?? '';
    AppLogger.info('Building join code. AudioFallbackUrl: $fallbackUrl', tag: 'MEETING');
    final cellMatch = RegExp(r'wss://wss\.k\.(\w+)\.(\w+)\.app\.chime\.aws').firstMatch(fallbackUrl);
    if (cellMatch != null) {
      final code = '$meetingId:${cellMatch.group(1)}:${cellMatch.group(2)}';
      AppLogger.info('Join code: $code', tag: 'MEETING');
      return code;
    }
    AppLogger.warning('Could not extract cell/region from fallback URL', tag: 'MEETING');
    return meetingId;
  }

  /// Builds an HTTPS shareable link that opens a web page,
  /// which then redirects to the app via hipstermeet:// deep link.
  String _buildShareLink() {
    final fallbackUrl = meetingData.meeting?.mediaPlacement?.audioFallbackUrl ?? '';
    final cellMatch = RegExp(r'wss://wss\.k\.(\w+)\.(\w+)\.app\.chime\.aws').firstMatch(fallbackUrl);
    final base = Constants.deepLinkBaseUrl;
    if (cellMatch != null) {
      return '$base/join.html?meetingId=$meetingId&c=${cellMatch.group(1)}&r=${cellMatch.group(2)}';
    }
    return '$base/join.html?meetingId=$meetingId';
  }

  // ─── Reconnection Strategy ───

  void _startReconnect() {
    if (_isReconnecting) return; // Duplicate reconnect suppression
    _isReconnecting = true;
    _reconnectCount = 0;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_reconnectCount >= Constants.reconnectMaxAttempts) {
      callState.value = CallState.failed;
      errorMessage.value = 'Failed to reconnect after ${Constants.reconnectMaxAttempts} attempts';
      _isReconnecting = false;
      _addEvent(MeetingEventModel(
        type: MeetingEventType.sessionFailure,
        message: 'Max reconnect attempts reached',
      ));
      return;
    }

    // Exponential backoff: 2s, 4s, 8s, 16s, 32s
    final delay = Constants.reconnectBaseDelay * (1 << _reconnectCount);
    _reconnectCount++;

    _addEvent(MeetingEventModel(
      type: MeetingEventType.reconnectAttempt,
      message: 'Reconnect attempt #$_reconnectCount in ${delay.inSeconds}s',
    ));

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, _attemptRejoin);
  }

  Future<void> _attemptRejoin() async {
    if (!_connectivityService.isConnected.value) {
      _scheduleReconnect();
      return;
    }

    _addEvent(MeetingEventModel(
      type: MeetingEventType.info,
      message: 'Attempting to rejoin meeting...',
    ));

    // Get fresh token
    final result = isAgent
        ? await _meetingRepository.getAgentToken(meetingId)
        : await _meetingRepository.getClientToken(meetingId);

    result.fold(
      (failure) {
        AppLogger.error('Rejoin token fetch failed: ${failure.message}', tag: 'MEETING');
        _scheduleReconnect();
      },
      (data) async {
        if (data.attendee == null) {
          AppLogger.error('Rejoin got null attendee data', tag: 'MEETING');
          _scheduleReconnect();
          return;
        }
        // Prefer API-returned meeting data if it has MediaPlacement,
        // otherwise fall back to the original meeting data
        final apiMeeting = data.meeting;
        final mergedMeeting = (apiMeeting?.mediaPlacement != null)
            ? apiMeeting
            : meetingData.meeting ?? apiMeeting;
        meetingData = MeetingDataModel(
          meeting: mergedMeeting,
          attendee: data.attendee,
        );
        if (mergedMeeting?.mediaPlacement == null) {
          AppLogger.error('No MediaPlacement available for rejoin', tag: 'MEETING');
          _scheduleReconnect();
          return;
        }
        final success = await _chimeService.startMeeting(
          meeting: mergedMeeting!,
          attendee: data.attendee!,
        );
        if (success) {
          _isReconnecting = false;
          _reconnectCount = 0;
          callState.value = CallState.connected;
          _addEvent(MeetingEventModel(
            type: MeetingEventType.connectionRecovered,
            message: 'Successfully rejoined meeting',
          ));
        } else {
          _scheduleReconnect();
        }
      },
    );
  }

  // ─── Stale Session Detection ───

  void _startStaleSessionTimer() {
    _staleSessionTimer?.cancel();
    _staleSessionTimer = Timer(Constants.sessionStaleTimeout, () {
      _addEvent(MeetingEventModel(
        type: MeetingEventType.info,
        message: 'Session may be stale. Consider refreshing.',
      ));
    });
  }

  // ─── App Lifecycle ───

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        _addEvent(MeetingEventModel(
          type: MeetingEventType.info,
          message: 'App moved to background',
        ));
        AppLogger.info('App backgrounded', tag: 'LIFECYCLE');
        break;
      case AppLifecycleState.resumed:
        _addEvent(MeetingEventModel(
          type: MeetingEventType.info,
          message: 'App returned to foreground',
        ));
        AppLogger.info('App foregrounded', tag: 'LIFECYCLE');
        if (callState.value == CallState.reconnecting ||
            callState.value == CallState.disconnected) {
          callState.value = CallState.reconnecting;
          _attemptRejoin();
        } else if (callState.value == CallState.failed) {
          // Allow user to retry from failed state after returning from background
          _addEvent(MeetingEventModel(
            type: MeetingEventType.info,
            message: 'Meeting failed. Tap retry to reconnect.',
          ));
        }
        break;
      default:
        break;
    }
  }

  // ─── Cleanup ───

  void _cancelTimers() {
    _reconnectTimer?.cancel();
    _staleSessionTimer?.cancel();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _eventSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _cancelTimers();
    _chimeService.stopMeeting();
    WakelockPlus.disable();
    super.onClose();
  }
}

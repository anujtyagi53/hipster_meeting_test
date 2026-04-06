import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:hipster_meeting_test/models/meeting_data_model.dart';
import 'package:hipster_meeting_test/models/meeting_model.dart';
import 'package:hipster_meeting_test/repository/meeting_repository.dart';
import 'package:hipster_meeting_test/routes/app_routes.dart';
import 'package:hipster_meeting_test/utils/app_logger.dart';

class HomeController extends GetxController {
  final MeetingRepository _repository = Get.find<MeetingRepository>();
  final meetingIdController = TextEditingController();
  final isLoading = false.obs;
  final selectedRole = 'agent'.obs;

  /// Cache of full meeting data (with MediaPlacement) keyed by MeetingId.
  /// The token retrieval APIs don't return MediaPlacement, so we cache it
  /// from createMeeting and reuse it when joining/rejoining.
  static final Map<String, MeetingModel> _meetingCache = {};

  /// Retrieve cached meeting data for a given meeting ID.
  static MeetingModel? getCachedMeeting(String meetingId) => _meetingCache[meetingId];

  @override
  void onInit() {
    super.onInit();
    // Handle deep link: auto-fill meeting ID and cache MediaPlacement if provided
    final args = Get.arguments;
    if (args is Map && args['deepLinkMeetingId'] != null) {
      final id = args['deepLinkMeetingId'] as String;
      meetingIdController.text = id;
      selectedRole.value = 'client';

      // If cell + region from deep link, construct exact MediaPlacement
      final cell = args['cell'] as String?;
      final regionCode = args['regionCode'] as String?;
      if (cell != null && regionCode != null) {
        final placement = MediaPlacement.fromCellAndRegion(
          meetingId: id,
          cell: cell,
          regionCode: regionCode,
        );
        _meetingCache[id] = MeetingModel(
          meetingId: id,
          mediaRegion: MediaPlacement.fullRegionFromCode(regionCode),
          mediaPlacement: placement,
        );
        AppLogger.info('Constructed MediaPlacement from deep link (cell=$cell, region=$regionCode)', tag: 'HOME');
      }

      // Auto-join after UI is built
      SchedulerBinding.instance.addPostFrameCallback((_) => joinMeeting());
    }
  }

  /// Agent creates a new meeting
  Future<void> createMeeting() async {
    isLoading.value = true;
    EasyLoading.show(status: 'Creating meeting...');

    final result = await _repository.createMeeting();
    EasyLoading.dismiss();
    isLoading.value = false;

    result.fold(
      (failure) {
        AppLogger.error('Create meeting failed: ${failure.message}', tag: 'HOME');
        Get.snackbar('Error', failure.message,
            backgroundColor: Colors.red.withValues(alpha: 0.8),
            colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM);
      },
      (data) {
        // Cache full meeting data (with MediaPlacement) for rejoin/reconnect
        if (data.meeting != null && data.meeting!.meetingId != null) {
          _meetingCache[data.meeting!.meetingId!] = data.meeting!;
        }
        AppLogger.info('Meeting created, navigating to meeting page', tag: 'HOME');
        _navigateToMeeting(data, isAgent: true);
      },
    );
  }

  /// Client joins an existing meeting by meeting ID.
  /// First fetches the full meeting info (with MediaPlacement) via the agent
  /// token API for the target meeting, then gets the caller's own attendee token.
  Future<void> joinMeeting() async {
    final input = meetingIdController.text.trim();
    if (input.isEmpty) {
      Get.snackbar('Error', 'Please enter a Meeting ID or join code',
          backgroundColor: Colors.red.withValues(alpha: 0.8),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    // Parse join code format: "meetingId:cell:region" or plain "meetingId"
    String meetingId;
    String? cell;
    String? regionCode;
    final parts = input.split(':');
    if (parts.length == 3) {
      meetingId = parts[0];
      cell = parts[1];
      regionCode = parts[2];
      meetingIdController.text = meetingId; // Show clean meeting ID
    } else {
      meetingId = input;
    }

    isLoading.value = true;
    EasyLoading.show(status: 'Joining meeting...');

    // Check local cache first for MediaPlacement
    MeetingModel? meetingInfo = _meetingCache[meetingId];

    // If cell+region provided (from join code), construct exact MediaPlacement
    if (meetingInfo == null && cell != null && regionCode != null) {
      final placement = MediaPlacement.fromCellAndRegion(
        meetingId: meetingId,
        cell: cell,
        regionCode: regionCode,
      );
      meetingInfo = MeetingModel(
        meetingId: meetingId,
        mediaRegion: MediaPlacement.fullRegionFromCode(regionCode),
        mediaPlacement: placement,
      );
      _meetingCache[meetingId] = meetingInfo;
      AppLogger.info('Constructed MediaPlacement from join code (cell=$cell, region=$regionCode)', tag: 'HOME');
    }

    // If no cached MediaPlacement, create a temp meeting to discover the region's
    // URL patterns, then construct MediaPlacement for the target meeting.
    // The token retrieval API never returns MediaPlacement — only createMeeting does.
    if (meetingInfo == null || meetingInfo.mediaPlacement == null) {
      AppLogger.info('No cached MediaPlacement, creating temp meeting for URL template...', tag: 'HOME');
      final templateResult = await _repository.createMeeting();
      templateResult.fold(
        (failure) {
          AppLogger.warning('Template meeting creation failed: ${failure.message}', tag: 'HOME');
        },
        (templateData) {
          final template = templateData.meeting;
          if (template?.mediaPlacement != null) {
            final constructedPlacement = template!.mediaPlacement!.forMeetingId(meetingId);
            meetingInfo = MeetingModel(
              meetingId: meetingId,
              mediaRegion: template.mediaRegion,
              mediaPlacement: constructedPlacement,
            );
            _meetingCache[meetingId] = meetingInfo!;
            AppLogger.info('Constructed MediaPlacement from template meeting', tag: 'HOME');
          }
        },
      );
    }

    // Now get the caller's own attendee token
    final result = selectedRole.value == 'agent'
        ? await _repository.getAgentToken(meetingId)
        : await _repository.getClientToken(meetingId);

    EasyLoading.dismiss();
    isLoading.value = false;

    result.fold(
      (failure) {
        AppLogger.error('Join meeting failed: ${failure.message}', tag: 'HOME');
        Get.snackbar('Error', failure.message,
            backgroundColor: Colors.red.withValues(alpha: 0.8),
            colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM);
      },
      (data) {
        // Prefer API-returned meeting data with MediaPlacement over cached
        final apiMeeting = data.meeting;
        final effectiveMeeting = (apiMeeting?.mediaPlacement != null) ? apiMeeting : meetingInfo ?? apiMeeting;

        final mergedData = MeetingDataModel(
          meeting: effectiveMeeting,
          attendee: data.attendee,
        );
        if (mergedData.meeting?.mediaPlacement == null) {
          AppLogger.error('No MediaPlacement available for meeting $meetingId', tag: 'HOME');
          Get.snackbar('Error', 'Unable to get meeting connection data. Please try again.',
              backgroundColor: Colors.red.withValues(alpha: 0.8),
              colorText: Colors.white,
              snackPosition: SnackPosition.BOTTOM);
          return;
        }
        // Cache for reconnect
        if (mergedData.meeting != null) {
          _meetingCache[meetingId] = mergedData.meeting!;
        }
        AppLogger.info('Joined meeting, navigating to meeting page', tag: 'HOME');
        _navigateToMeeting(mergedData, isAgent: selectedRole.value == 'agent');
      },
    );
  }

  void _navigateToMeeting(MeetingDataModel data, {required bool isAgent}) {
    Get.toNamed(AppRoutes.meeting, arguments: {
      'meetingData': data,
      'isAgent': isAgent,
    });
  }

  @override
  void onClose() {
    meetingIdController.dispose();
    super.onClose();
  }
}

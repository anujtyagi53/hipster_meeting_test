import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hipster_meeting_test/controllers/meeting_controller.dart';
import 'package:hipster_meeting_test/enums/meeting_event_type.dart';
import 'package:hipster_meeting_test/models/meeting_event_model.dart';
import 'package:hipster_meeting_test/utils/app_colors.dart';
import 'package:hipster_meeting_test/utils/app_styles.dart';

class EventLogPanel extends GetView<MeetingController> {
  const EventLogPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.controlBarBg.withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.divider, width: 0.5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.list_alt, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text('Event Log', style: kTitleStyle(size: 14)),
                const Spacer(),
                Obx(() => Text(
                      '${controller.events.length} events',
                      style: kCaptionStyle(size: 11),
                    )),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: controller.toggleEventLog,
                  child: const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),

          // Event list
          Expanded(
            child: Obx(() {
              if (controller.events.isEmpty) {
                return Center(
                  child: Text('No events yet', style: kCaptionStyle()),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                itemCount: controller.events.length,
                itemBuilder: (_, index) => _EventLogItem(event: controller.events[index]),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _EventLogItem extends StatelessWidget {
  final MeetingEventModel event;
  const _EventLogItem({required this.event});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 5, right: 8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _eventColor(event.type),
            ),
          ),
          Text(
            event.formattedTime,
            style: kEventLogStyle(color: AppColors.textHint),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${event.type.label}: ${event.message}',
              style: kEventLogStyle(color: _eventColor(event.type)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Color _eventColor(MeetingEventType type) {
    if (type == MeetingEventType.error || type == MeetingEventType.sessionFailure) {
      return AppColors.eventError;
    }
    if (type == MeetingEventType.networkDegraded || type == MeetingEventType.reconnectAttempt) {
      return AppColors.eventWarning;
    }
    if (type == MeetingEventType.connectionRecovered ||
        type == MeetingEventType.meetingStarted ||
        type == MeetingEventType.attendeeJoined) {
      return AppColors.eventSuccess;
    }
    return AppColors.eventInfo;
  }
}

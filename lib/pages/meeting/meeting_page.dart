import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hipster_meeting_test/controllers/meeting_controller.dart';
import 'package:hipster_meeting_test/enums/call_state.dart';
import 'package:hipster_meeting_test/pages/meeting/widgets/control_bar.dart';
import 'package:hipster_meeting_test/pages/meeting/widgets/diagnostics_panel.dart';
import 'package:hipster_meeting_test/pages/meeting/widgets/event_log_panel.dart';
import 'package:hipster_meeting_test/pages/meeting/widgets/reconnect_banner.dart';
import 'package:hipster_meeting_test/pages/meeting/widgets/video_area.dart';
import 'package:hipster_meeting_test/utils/app_colors.dart';
import 'package:hipster_meeting_test/utils/app_styles.dart';

class MeetingPage extends GetView<MeetingController> {
  const MeetingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          controller.confirmLeave();
        }
      },
      child: Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Obx(() {
          final state = controller.callState.value;

          if (state == CallState.joining) {
            return _buildJoiningView();
          }

          if (state == CallState.failed) {
            return _buildFailedView();
          }

          return Column(
            children: [
              // Reconnect banner
              if (state == CallState.reconnecting) const ReconnectBanner(),

              // Top bar with meeting info
              _buildTopBar(),

              // Main content area
              Expanded(
                child: Stack(
                  children: [
                    // Video area (remote + local preview)
                    const VideoArea(),

                    // Event log panel (slide up)
                    if (controller.showEventLog.value)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: MediaQuery.of(context).size.height * 0.4,
                        child: const EventLogPanel(),
                      ),

                    // Diagnostics panel
                    if (controller.showDiagnostics.value)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: const DiagnosticsPanel(),
                      ),
                  ],
                ),
              ),

              // Control bar
              const ControlBar(),
            ],
          );
        }),
      ),
    ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.controlBarBg,
      child: Row(
        children: [
          Obx(() => Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _stateColor(controller.callState.value),
                ),
              )),
          const SizedBox(width: 8),
          Obx(() => Text(
                controller.callState.value.label,
                style: kCaptionStyle(size: 12),
              )),
          const Spacer(),
          Text(
            'ID: ${controller.meetingId.length > 8 ? '${controller.meetingId.substring(0, 8)}...' : controller.meetingId}',
            style: kCaptionStyle(size: 11),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(
              Icons.copy,
              size: 16,
              color: AppColors.textSecondary,
            ),
            onPressed: controller.copyMeetingId,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          ),
          IconButton(
            icon: const Icon(
              Icons.share,
              size: 16,
              color: AppColors.textSecondary,
            ),
            onPressed: controller.shareMeeting,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildJoiningView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 24),
          Text('Joining Meeting...', style: kTitleStyle()),
          const SizedBox(height: 8),
          Text('Setting up audio & video', style: kCaptionStyle()),
        ],
      ),
    );
  }

  Widget _buildFailedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: 24),
            Text('Connection Failed', style: kTitleStyle(color: AppColors.error)),
            const SizedBox(height: 8),
            Obx(() => Text(
                  controller.errorMessage.value ?? 'Unable to connect to meeting',
                  style: kCaptionStyle(),
                  textAlign: TextAlign.center,
                )),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => Get.back(),
                  icon: const Icon(Icons.arrow_back, color: AppColors.white),
                  label: Text('Go Back', style: kButtonStyle()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.surfaceLight,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: controller.retryJoin,
                  icon: const Icon(Icons.refresh, color: AppColors.white),
                  label: Text('Retry', style: kButtonStyle()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _stateColor(CallState state) {
    switch (state) {
      case CallState.connected:
        return AppColors.success;
      case CallState.reconnecting:
        return AppColors.warning;
      case CallState.failed:
        return AppColors.error;
      default:
        return AppColors.textHint;
    }
  }
}

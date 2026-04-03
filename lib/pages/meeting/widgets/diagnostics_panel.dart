import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hipster_meeting_test/controllers/meeting_controller.dart';
import 'package:hipster_meeting_test/enums/call_state.dart';
import 'package:hipster_meeting_test/services/chime_service.dart';
import 'package:hipster_meeting_test/utils/app_colors.dart';
import 'package:hipster_meeting_test/utils/app_styles.dart';

class DiagnosticsPanel extends GetView<MeetingController> {
  const DiagnosticsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.controlBarBg.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Obx(() => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.analytics_outlined, size: 14, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text('Diagnostics', style: kTitleStyle(size: 12)),
                  const Spacer(),
                  GestureDetector(
                    onTap: controller.toggleDiagnostics,
                    child: const Icon(Icons.close, size: 14, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const Divider(color: AppColors.divider, height: 16),
              _DiagRow(label: 'Connection', value: controller.callState.value.label,
                  valueColor: _connectionColor()),
              _DiagRow(label: 'Network', value: controller.networkQuality.value,
                  valueColor: controller.networkQuality.value == 'Good'
                      ? AppColors.success : AppColors.warning),
              _DiagRow(label: 'Reconnects', value: '${controller.reconnectAttempts.value}'),
              _DiagRow(label: 'Audio', value: controller.isMicEnabled.value ? 'Enabled' : 'Muted',
                  valueColor: controller.isMicEnabled.value ? AppColors.success : AppColors.error),
              _DiagRow(label: 'Video', value: controller.isCameraEnabled.value ? 'Enabled' : 'Disabled',
                  valueColor: controller.isCameraEnabled.value ? AppColors.success : AppColors.error),
              _DiagRow(label: 'Bitrate', value: _bitrateLabel()),
              _DiagRow(label: 'Duration', value: Get.find<ChimeService>().sessionDuration),
              _DiagRow(label: 'Camera', value: controller.isUsingFrontCamera.value ? 'Front' : 'Back'),
              _DiagRow(label: 'Remote', value: controller.remoteAttendeeId.value != null ? 'Connected' : 'None',
                  valueColor: controller.remoteAttendeeId.value != null ? AppColors.success : AppColors.textHint),
              _DiagRow(label: 'Meeting ID', value: controller.meetingId.length > 12
                  ? '${controller.meetingId.substring(0, 12)}...' : controller.meetingId),
            ],
          )),
    );
  }

  String _bitrateLabel() {
    final kbps = Get.find<ChimeService>().bitrateKbps.value;
    if (kbps == null) return 'N/A';
    if (kbps > 1000) return '${(kbps / 1000).toStringAsFixed(1)} Mbps';
    return '$kbps Kbps';
  }

  Color _connectionColor() {
    switch (controller.callState.value) {
      case CallState.connected:
        return AppColors.success;
      case CallState.reconnecting:
        return AppColors.warning;
      case CallState.failed:
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }
}

class _DiagRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _DiagRow({
    required this.label,
    required this.value,
    this.valueColor = AppColors.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: kCaptionStyle(size: 10)),
          Text(value, style: kEventLogStyle(size: 10, color: valueColor)),
        ],
      ),
    );
  }
}

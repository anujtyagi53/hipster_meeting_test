import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hipster_meeting_test/controllers/meeting_controller.dart';
import 'package:hipster_meeting_test/utils/app_colors.dart';

class ControlBar extends GetView<MeetingController> {
  const ControlBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppColors.controlBarBg,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Mic toggle
          Obx(() => _ControlButton(
                icon: controller.isMicEnabled.value ? Icons.mic : Icons.mic_off,
                label: controller.isMicEnabled.value ? 'Mute' : 'Unmute',
                isActive: controller.isMicEnabled.value,
                activeColor: AppColors.white,
                inactiveColor: AppColors.error,
                onTap: controller.toggleMute,
              )),

          // Camera toggle
          Obx(() => _ControlButton(
                icon: controller.isCameraEnabled.value ? Icons.videocam : Icons.videocam_off,
                label: controller.isCameraEnabled.value ? 'Cam Off' : 'Cam On',
                isActive: controller.isCameraEnabled.value,
                activeColor: AppColors.white,
                inactiveColor: AppColors.error,
                onTap: controller.toggleCamera,
              )),

          // Switch camera
          _ControlButton(
            icon: Icons.cameraswitch,
            label: 'Switch',
            isActive: true,
            activeColor: AppColors.white,
            onTap: controller.switchCamera,
          ),

          // Event log toggle
          Obx(() => _ControlButton(
                icon: Icons.list_alt,
                label: 'Events',
                isActive: controller.showEventLog.value,
                activeColor: AppColors.primary,
                inactiveColor: AppColors.white,
                onTap: controller.toggleEventLog,
              )),

          // Diagnostics toggle
          Obx(() => _ControlButton(
                icon: Icons.analytics_outlined,
                label: 'Diag',
                isActive: controller.showDiagnostics.value,
                activeColor: AppColors.primary,
                inactiveColor: AppColors.white,
                onTap: controller.toggleDiagnostics,
              )),

          // Leave button
          _ControlButton(
            icon: Icons.call_end,
            label: 'Leave',
            isActive: false,
            inactiveColor: AppColors.white,
            backgroundColor: AppColors.error,
            onTap: () => controller.confirmLeave(),
          ),
        ],
      ),
    );
  }

}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color activeColor;
  final Color inactiveColor;
  final Color? backgroundColor;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.isActive,
    this.activeColor = AppColors.white,
    this.inactiveColor = AppColors.textHint,
    this.backgroundColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: backgroundColor ?? (isActive ? AppColors.surface : AppColors.surfaceLight),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isActive ? activeColor : inactiveColor,
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isActive ? activeColor : inactiveColor,
            ),
          ),
        ],
      ),
    );
  }
}

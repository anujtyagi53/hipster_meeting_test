import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hipster_meeting_test/controllers/meeting_controller.dart';
import 'package:hipster_meeting_test/utils/app_colors.dart';
import 'package:hipster_meeting_test/utils/app_styles.dart';

class ReconnectBanner extends GetView<MeetingController> {
  const ReconnectBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.reconnectBanner,
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Obx(() => Text(
                  'Reconnecting... (attempt ${controller.reconnectAttempts.value})',
                  style: kCaptionStyle(size: 12, color: Colors.white),
                )),
          ),
        ],
      ),
    );
  }
}

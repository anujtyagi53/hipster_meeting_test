import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hipster_meeting_test/controllers/home_controller.dart';
import 'package:hipster_meeting_test/utils/app_colors.dart';
import 'package:hipster_meeting_test/utils/app_styles.dart';

class HomePage extends GetView<HomeController> {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo / Title
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.video_call_rounded, size: 64, color: AppColors.primary),
                ),
                const SizedBox(height: 24),
                Text('Hipster Meeting', style: kHeadingStyle(size: 28)),
                const SizedBox(height: 8),
                Text('1:1 Real-Time Video Call', style: kCaptionStyle(size: 14)),
                const SizedBox(height: 48),

                // Role selector
                Obx(() => Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildRoleChip('Agent', 'agent'),
                        const SizedBox(width: 12),
                        _buildRoleChip('Client', 'client'),
                      ],
                    )),
                const SizedBox(height: 32),

                // Create Meeting button (Agent only)
                Obx(() => controller.selectedRole.value == 'agent'
                    ? Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton.icon(
                              onPressed: controller.isLoading.value ? null : controller.createMeeting,
                              icon: const Icon(Icons.add_call, color: AppColors.white),
                              label: Text('Create New Meeting', style: kButtonStyle()),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              const Expanded(child: Divider(color: AppColors.divider)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text('OR', style: kCaptionStyle()),
                              ),
                              const Expanded(child: Divider(color: AppColors.divider)),
                            ],
                          ),
                          const SizedBox(height: 24),
                        ],
                      )
                    : const SizedBox.shrink()),

                // Meeting ID input
                TextField(
                  controller: controller.meetingIdController,
                  style: kBodyStyle(),
                  decoration: InputDecoration(
                    hintText: 'Enter Meeting ID',
                    hintStyle: kCaptionStyle(color: AppColors.textHint),
                    filled: true,
                    fillColor: AppColors.surface,
                    prefixIcon: const Icon(Icons.meeting_room_outlined, color: AppColors.textSecondary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Join Meeting button
                Obx(() => SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: controller.isLoading.value ? null : controller.joinMeeting,
                        icon: const Icon(Icons.login_rounded, color: AppColors.white),
                        label: Text('Join Meeting', style: kButtonStyle()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.surfaceLight,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    )),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleChip(String label, String value) {
    final isSelected = controller.selectedRole.value == value;
    return GestureDetector(
      onTap: () => controller.selectedRole.value = value,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
          ),
        ),
        child: Text(
          label,
          style: kButtonStyle(
            color: isSelected ? AppColors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

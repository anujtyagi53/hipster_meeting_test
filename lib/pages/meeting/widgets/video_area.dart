import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hipster_meeting_test/controllers/meeting_controller.dart';
import 'package:hipster_meeting_test/utils/app_colors.dart';
import 'package:hipster_meeting_test/utils/app_styles.dart';
import 'package:hipster_meeting_test/pages/meeting/widgets/chime_video_view.dart';

class VideoArea extends GetView<MeetingController> {
  const VideoArea({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Remote video (full screen)
        Positioned.fill(
          child: Obx(() {
            final remoteTileId = controller.remoteVideoTileId.value;
            final remoteAttendee = controller.remoteAttendeeId.value;
            if (remoteTileId != null) {
              return ChimeVideoView(
                key: ValueKey('remote_$remoteTileId'),
                tileId: remoteTileId,
              );
            }
            return _buildPlaceholder(
              icon: remoteAttendee != null
                  ? Icons.videocam_off
                  : Icons.person_outline,
              label: remoteAttendee != null
                  ? 'Participant joined - Camera off'
                  : 'Waiting for participant...',
            );
          }),
        ),

        // Local preview (thumbnail)
        Positioned(
          top: 16,
          right: 16,
          child: Obx(() {
            final localTileId = controller.localVideoTileId.value;
            return GestureDetector(
              onTap: controller.switchCamera,
              child: Container(
                width: 120,
                height: 160,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: localTileId != null && controller.isCameraEnabled.value
                    ? ChimeVideoView(
                        key: ValueKey('local_$localTileId'),
                        tileId: localTileId,
                        isMirror: controller.isUsingFrontCamera.value,
                      )
                    : _buildLocalPlaceholder(),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildPlaceholder({required IconData icon, required String label}) {
    return Container(
      color: AppColors.surface,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: AppColors.textHint),
            const SizedBox(height: 16),
            Text(label, style: kCaptionStyle()),
          ],
        ),
      ),
    );
  }

  Widget _buildLocalPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.videocam_off, size: 32, color: AppColors.textHint),
          const SizedBox(height: 4),
          Text('You', style: kCaptionStyle(size: 10)),
        ],
      ),
    );
  }
}

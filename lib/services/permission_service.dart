import 'package:permission_handler/permission_handler.dart';
import 'package:hipster_meeting_test/utils/app_logger.dart';

class PermissionService {
  Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    AppLogger.info('Camera permission: ${status.name}', tag: 'PERMISSION');
    return status.isGranted;
  }

  Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    AppLogger.info('Microphone permission: ${status.name}', tag: 'PERMISSION');
    return status.isGranted;
  }

  Future<Map<String, bool>> requestMeetingPermissions() async {
    final camera = await requestCameraPermission();
    final microphone = await requestMicrophonePermission();
    return {'camera': camera, 'microphone': microphone};
  }

  Future<bool> isCameraGranted() async => await Permission.camera.isGranted;
  Future<bool> isMicrophoneGranted() async => await Permission.microphone.isGranted;

  Future<bool> isCameraDeniedPermanently() async =>
      await Permission.camera.isPermanentlyDenied;

  Future<bool> isMicrophoneDeniedPermanently() async =>
      await Permission.microphone.isPermanentlyDenied;

  Future<void> openSettings() async => await openAppSettings();
}

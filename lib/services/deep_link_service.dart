import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hipster_meeting_test/routes/app_routes.dart';
import 'package:hipster_meeting_test/utils/app_logger.dart';

/// Handles deep links for joining meetings.
/// Scheme: hipstermeet://join?meetingId=xxx&c=m3&r=as1
class DeepLinkService extends GetxService {
  static const _channel = MethodChannel('com.hipster.chime/deeplink');

  @override
  void onInit() {
    super.onInit();
    _handleInitialLink();
    _channel.setMethodCallHandler(_onMethodCall);
  }

  Future<void> _handleInitialLink() async {
    try {
      final link = await _channel.invokeMethod<String>('getInitialLink');
      if (link != null) _processLink(link);
    } catch (_) {
      // No initial link
    }
  }

  Future<dynamic> _onMethodCall(MethodCall call) async {
    if (call.method == 'onDeepLink') {
      final link = call.arguments as String?;
      if (link != null) _processLink(link);
    }
  }

  void _processLink(String link) {
    AppLogger.info('Deep link received: $link', tag: 'DEEPLINK');
    final uri = Uri.tryParse(link);
    if (uri == null) return;

    if (uri.scheme == 'hipstermeet' && uri.host == 'join') {
      final meetingId = uri.queryParameters['meetingId'];
      if (meetingId != null && meetingId.isNotEmpty) {
        final cell = uri.queryParameters['c'];   // e.g. "m3"
        final region = uri.queryParameters['r']; // e.g. "as1"

        AppLogger.info('Joining meeting from deep link: $meetingId (cell=$cell, region=$region)', tag: 'DEEPLINK');
        Get.toNamed(AppRoutes.home, arguments: {
          'deepLinkMeetingId': meetingId,
          if (cell != null) 'cell': cell,
          if (region != null) 'regionCode': region,
        });
      }
    }
  }
}

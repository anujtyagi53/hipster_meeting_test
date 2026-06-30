import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hipster_meeting_test/routes/app_routes.dart';
import 'package:hipster_meeting_test/utils/app_logger.dart';

class DeepLinkService extends GetxService {
  static const _channel = MethodChannel('com.hipster.chime/deeplink');

  @override
  void onInit() {
    super.onInit();
    handleInitialLink();
    _channel.setMethodCallHandler(onMethodCall);
  }

  Future<void> handleInitialLink() async {
    try {
      final link = await _channel.invokeMethod<String>('getInitialLink');
      if (link != null) processLink(link);
    } catch (_) {}
  }

  Future<dynamic> onMethodCall(MethodCall call) async {
    if (call.method == 'onDeepLink') {
      final link = call.arguments as String?;
      if (link != null) processLink(link);
    }
  }

  void processLink(String link) {
    AppLogger.info('Deep link received: $link', tag: 'DEEPLINK');
    final uri = Uri.tryParse(link);
    if (uri == null) return;

    String? meetingId;
    String? cell;
    String? region;

    if (uri.scheme == 'https' &&
        uri.host == 'anujtyagi53.github.io' &&
        uri.path.contains('/hipster_meeting_test/')) {
      meetingId = uri.queryParameters['meetingId'];
      cell = uri.queryParameters['c'];
      region = uri.queryParameters['r'];
    }

    if (meetingId != null && meetingId.isNotEmpty) {
      AppLogger.info('Joining meeting from deep link: $meetingId (cell=$cell, region=$region)', tag: 'DEEPLINK');
      Get.toNamed(AppRoutes.home, arguments: {
        'deepLinkMeetingId': meetingId,
        if (cell != null) 'cell': cell,
        if (region != null) 'regionCode': region,
      });
    }
  }
}

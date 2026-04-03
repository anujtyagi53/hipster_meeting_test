import 'package:get/get.dart';
import 'package:hipster_meeting_test/network/api_client.dart';
import 'package:hipster_meeting_test/repository/meeting_repository.dart';
import 'package:hipster_meeting_test/services/chime_service.dart';
import 'package:hipster_meeting_test/services/connectivity_service.dart';
import 'package:hipster_meeting_test/services/deep_link_service.dart';
import 'package:hipster_meeting_test/services/permission_service.dart';

class AppBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(ApiClient(), permanent: true);
    Get.put(MeetingRepository(), permanent: true);
    Get.put(ConnectivityService(), permanent: true);
    Get.put(ChimeService(), permanent: true);
    Get.put(DeepLinkService(), permanent: true);
    Get.put(PermissionService(), permanent: true);
  }
}

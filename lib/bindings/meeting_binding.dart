import 'package:get/get.dart';
import 'package:hipster_meeting_test/controllers/meeting_controller.dart';

class MeetingBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MeetingController>(() => MeetingController());
  }
}

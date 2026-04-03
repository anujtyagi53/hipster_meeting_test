import 'package:get/get.dart';
import 'package:hipster_meeting_test/bindings/home_binding.dart';
import 'package:hipster_meeting_test/bindings/meeting_binding.dart';
import 'package:hipster_meeting_test/pages/home/home_page.dart';
import 'package:hipster_meeting_test/pages/meeting/meeting_page.dart';
import 'package:hipster_meeting_test/routes/app_routes.dart';

class AppPages {
  static final pages = [
    GetPage(
      name: AppRoutes.home,
      page: () => const HomePage(),
      binding: HomeBinding(),
    ),
    GetPage(
      name: AppRoutes.meeting,
      page: () => const MeetingPage(),
      binding: MeetingBinding(),
    ),
  ];
}

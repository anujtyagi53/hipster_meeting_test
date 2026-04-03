import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:hipster_meeting_test/bindings/app_binding.dart';
import 'package:hipster_meeting_test/routes/app_pages.dart';
import 'package:hipster_meeting_test/routes/app_routes.dart';
import 'package:hipster_meeting_test/utils/app_colors.dart';
import 'package:hipster_meeting_test/utils/app_styles.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hipster_meeting_test/utils/constants.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env').catchError((_) {});
  Constants.prefs = await SharedPreferences.getInstance();
  runApp(const HipsterMeetingApp());
}

class HipsterMeetingApp extends StatelessWidget {
  const HipsterMeetingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Hipster Meeting',
      initialBinding: AppBinding(),
      getPages: AppPages.pages,
      initialRoute: AppRoutes.home,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: AppColors.primary,
          secondary: AppColors.accent,
          surface: AppColors.surface,
          error: AppColors.error,
        ),
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.controlBarBg,
          foregroundColor: AppColors.white,
          titleTextStyle: kTitleStyle(size: 18),
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
        ),
      ),
      builder: EasyLoading.init(),
    );
  }
}

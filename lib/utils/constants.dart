import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Constants {
  static late SharedPreferences prefs;

  static const int maxEventLogEntries = 50;
  static const int reconnectMaxAttempts = 5;
  static const Duration reconnectBaseDelay = Duration(seconds: 2);
  static const Duration sessionStaleTimeout = Duration(minutes: 30);
  static const Duration joinTimeout = Duration(seconds: 30);

  /// Base URL for the shareable deep link page (GitHub Pages).
  /// Update this after enabling GitHub Pages on your repo.
  static const String deepLinkBaseUrl = 'https://anujtyagi53.github.io/hipster_meeting_test';

  static String formatTimestamp(DateTime dt) => DateFormat('HH:mm:ss.SSS').format(dt);
  static String formatDate(DateTime dt) => DateFormat('yyyy-MM-dd HH:mm').format(dt);
}

import 'package:hipster_meeting_test/config/env_config.dart';

class ApiEndpoints {
  static String get baseUrl => EnvConfig.apiBaseUrl;
  static String get meetingsApi => 'meetings';
}

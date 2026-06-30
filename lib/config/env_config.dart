import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  static const String _dartDefineBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const String _dartDefineApiKey = String.fromEnvironment('API_KEY');
  static const String _dartDefineEnv = String.fromEnvironment('ENV');

  static String get apiBaseUrl =>
      _dartDefineBaseUrl.isNotEmpty ? _dartDefineBaseUrl : (dotenv.env['API_BASE_URL'] ?? '');

  static String get apiKey => _dartDefineApiKey.isNotEmpty ? _dartDefineApiKey : (dotenv.env['API_KEY'] ?? '');

  static String get env => _dartDefineEnv.isNotEmpty ? _dartDefineEnv : (dotenv.env['ENV'] ?? 'debug');

  static bool get isProduction => env == 'production';
  static bool get isDebug => env == 'debug';
}

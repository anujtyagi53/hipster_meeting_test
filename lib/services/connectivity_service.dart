import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';
import 'package:hipster_meeting_test/utils/app_logger.dart';

class ConnectivityService extends GetxService {
  final _connectivity = Connectivity();
  final isConnected = true.obs;
  StreamSubscription? _subscription;
  Timer? _debounceTimer;

  @override
  void onInit() {
    super.onInit();
    _checkConnectivity();
    _subscription = _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);
  }

  Future<void> _checkConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    _applyStatus(results);
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    // Debounce rapid connectivity changes to avoid excessive reconnect triggers
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 1), () {
      _applyStatus(results);
    });
  }

  void _applyStatus(List<ConnectivityResult> results) {
    final connected = results.any((r) => r != ConnectivityResult.none);
    if (isConnected.value != connected) {
      isConnected.value = connected;
      AppLogger.info(
        connected ? 'Network connected' : 'Network disconnected',
        tag: 'CONNECTIVITY',
      );
    }
  }

  @override
  void onClose() {
    _subscription?.cancel();
    _debounceTimer?.cancel();
    super.onClose();
  }
}

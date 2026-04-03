enum CallState {
  idle,
  joining,
  connected,
  reconnecting,
  disconnected,
  failed;

  String get label {
    switch (this) {
      case CallState.idle:
        return 'Idle';
      case CallState.joining:
        return 'Joining...';
      case CallState.connected:
        return 'Connected';
      case CallState.reconnecting:
        return 'Reconnecting...';
      case CallState.disconnected:
        return 'Disconnected';
      case CallState.failed:
        return 'Failed';
    }
  }

  bool get isActive => this == CallState.connected || this == CallState.reconnecting;
}

import 'package:hipster_meeting_test/enums/meeting_event_type.dart';
import 'package:hipster_meeting_test/utils/constants.dart';

class MeetingEventModel {
  final MeetingEventType type;
  final String message;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  MeetingEventModel({
    required this.type,
    required this.message,
    DateTime? timestamp,
    this.metadata,
  }) : timestamp = timestamp ?? DateTime.now();

  String get formattedTime => Constants.formatTimestamp(timestamp);

  String get displayText => '[$formattedTime] ${type.label}: $message';

  bool get isError =>
      type == MeetingEventType.sessionFailure ||
      type == MeetingEventType.error;

  bool get isWarning =>
      type == MeetingEventType.networkDegraded ||
      type == MeetingEventType.reconnectAttempt;
}

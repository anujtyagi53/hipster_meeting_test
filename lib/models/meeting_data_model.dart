import 'package:hipster_meeting_test/models/attendee_model.dart';
import 'package:hipster_meeting_test/models/meeting_model.dart';

class MeetingDataModel {
  final MeetingModel? meeting;
  final AttendeeModel? attendee;

  MeetingDataModel({this.meeting, this.attendee});

  factory MeetingDataModel.fromJson(Map<String, dynamic> json) {
    return MeetingDataModel(
      meeting: json['meeting'] != null ? MeetingModel.fromJson(json['meeting']) : null,
      attendee: json['attendee'] != null ? AttendeeModel.fromJson(json['attendee']) : null,
    );
  }
}

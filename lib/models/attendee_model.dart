class AttendeeModel {
  final String? externalUserId;
  final String? attendeeId;
  final String? joinToken;

  AttendeeModel({
    this.externalUserId,
    this.attendeeId,
    this.joinToken,
  });

  factory AttendeeModel.fromJson(Map<String, dynamic> json) {
    return AttendeeModel(
      externalUserId: json['ExternalUserId'],
      attendeeId: json['AttendeeId'],
      joinToken: json['JoinToken'],
    );
  }

  Map<String, dynamic> toJson() => {
        'ExternalUserId': externalUserId,
        'AttendeeId': attendeeId,
        'JoinToken': joinToken,
      };
}

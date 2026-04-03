class AttendeeModel {
  final String? externalUserId;
  final String? attendeeId;
  final String? joinToken;
  final AttendeeCapabilities? capabilities;

  AttendeeModel({
    this.externalUserId,
    this.attendeeId,
    this.joinToken,
    this.capabilities,
  });

  factory AttendeeModel.fromJson(Map<String, dynamic> json) {
    return AttendeeModel(
      externalUserId: json['ExternalUserId'],
      attendeeId: json['AttendeeId'],
      joinToken: json['JoinToken'],
      capabilities: json['Capabilities'] != null
          ? AttendeeCapabilities.fromJson(json['Capabilities'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'ExternalUserId': externalUserId,
        'AttendeeId': attendeeId,
        'JoinToken': joinToken,
        'Capabilities': capabilities?.toJson(),
      };
}

class AttendeeCapabilities {
  final String? audio;
  final String? video;
  final String? content;

  AttendeeCapabilities({this.audio, this.video, this.content});

  factory AttendeeCapabilities.fromJson(Map<String, dynamic> json) {
    return AttendeeCapabilities(
      audio: json['Audio'],
      video: json['Video'],
      content: json['Content'],
    );
  }

  Map<String, dynamic> toJson() => {
        'Audio': audio,
        'Video': video,
        'Content': content,
      };
}

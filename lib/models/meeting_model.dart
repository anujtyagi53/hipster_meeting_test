class MeetingModel {
  final String? meetingId;
  final String? externalMeetingId;
  final String? mediaRegion;
  final MediaPlacement? mediaPlacement;
  final MeetingFeatures? meetingFeatures;
  final String? meetingArn;

  MeetingModel({
    this.meetingId,
    this.externalMeetingId,
    this.mediaRegion,
    this.mediaPlacement,
    this.meetingFeatures,
    this.meetingArn,
  });

  factory MeetingModel.fromJson(Map<String, dynamic> json) {
    return MeetingModel(
      meetingId: json['MeetingId'],
      externalMeetingId: json['ExternalMeetingId'],
      mediaRegion: json['MediaRegion'],
      mediaPlacement: json['MediaPlacement'] != null
          ? MediaPlacement.fromJson(json['MediaPlacement'])
          : null,
      meetingFeatures: json['MeetingFeatures'] != null
          ? MeetingFeatures.fromJson(json['MeetingFeatures'])
          : null,
      meetingArn: json['MeetingArn'],
    );
  }

  Map<String, dynamic> toJson() => {
        'MeetingId': meetingId,
        'ExternalMeetingId': externalMeetingId,
        'MediaRegion': mediaRegion,
        'MediaPlacement': mediaPlacement?.toJson(),
        'MeetingFeatures': meetingFeatures?.toJson(),
        'MeetingArn': meetingArn,
      };
}

class MediaPlacement {
  final String? audioHostUrl;
  final String? audioFallbackUrl;
  final String? signalingUrl;
  final String? turnControlUrl;
  final String? screenDataUrl;
  final String? screenViewingUrl;
  final String? screenSharingUrl;
  final String? eventIngestionUrl;

  MediaPlacement({
    this.audioHostUrl,
    this.audioFallbackUrl,
    this.signalingUrl,
    this.turnControlUrl,
    this.screenDataUrl,
    this.screenViewingUrl,
    this.screenSharingUrl,
    this.eventIngestionUrl,
  });

  factory MediaPlacement.fromJson(Map<String, dynamic> json) {
    return MediaPlacement(
      audioHostUrl: json['AudioHostUrl'],
      audioFallbackUrl: json['AudioFallbackUrl'],
      signalingUrl: json['SignalingUrl'],
      turnControlUrl: json['TurnControlUrl'],
      screenDataUrl: json['ScreenDataUrl'],
      screenViewingUrl: json['ScreenViewingUrl'],
      screenSharingUrl: json['ScreenSharingUrl'],
      eventIngestionUrl: json['EventIngestionUrl'],
    );
  }

  Map<String, dynamic> toJson() => {
        'AudioHostUrl': audioHostUrl,
        'AudioFallbackUrl': audioFallbackUrl,
        'SignalingUrl': signalingUrl,
        'TurnControlUrl': turnControlUrl,
        'ScreenDataUrl': screenDataUrl,
        'ScreenViewingUrl': screenViewingUrl,
        'ScreenSharingUrl': screenSharingUrl,
        'EventIngestionUrl': eventIngestionUrl,
      };

  /// Constructs MediaPlacement from cell and region code.
  /// e.g. cell="m3", regionCode="as1", meetingId="xxx-2954"
  static MediaPlacement fromCellAndRegion({
    required String meetingId,
    required String cell,
    required String regionCode,
  }) {
    final lastFour = meetingId.length >= 4
        ? meetingId.substring(meetingId.length - 4)
        : meetingId;
    return MediaPlacement(
      audioHostUrl: '0.k.$cell.$regionCode.app.chime.aws:3478',
      audioFallbackUrl: 'wss://wss.k.$cell.$regionCode.app.chime.aws:443/calls/$meetingId',
      signalingUrl: 'wss://signal.$cell.$regionCode.app.chime.aws/control/$meetingId',
      turnControlUrl: 'https://$lastFour.cell.${fullRegionFromCode(regionCode)}.meetings.chime.aws/v2/turn_sessions',
      screenDataUrl: 'wss://bitpw.$cell.$regionCode.app.chime.aws:443/v2/screen/$meetingId',
      screenViewingUrl: 'wss://bitpw.$cell.$regionCode.app.chime.aws:443/ws/connect?passcode=null&viewer_uuid=null&X-BitHub-Call-Id=$meetingId',
      screenSharingUrl: 'wss://bitpw.$cell.$regionCode.app.chime.aws:443/v2/screen/$meetingId',
      eventIngestionUrl: 'https://data.svc.$regionCode.ingest.chime.aws/v1/client-events',
    );
  }

  static String fullRegionFromCode(String code) {
    const map = {
      'as1': 'ap-southeast-1',
      'ue1': 'us-east-1',
      'uw2': 'us-west-2',
      'eu1': 'eu-west-1',
      'ae1': 'ap-northeast-1',
    };
    return map[code] ?? 'ap-southeast-1';
  }

  /// Constructs a MediaPlacement for [targetMeetingId] by using this instance
  /// as a URL template. Replaces UUIDs in paths with the target meeting ID.
  MediaPlacement forMeetingId(String targetMeetingId) {
    final lastFour = targetMeetingId.length >= 4
        ? targetMeetingId.substring(targetMeetingId.length - 4)
        : targetMeetingId;
    final uuidRegex = RegExp(r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}');

    String replaceId(String? url) {
      if (url == null || url.isEmpty) return '';
      return url.replaceAll(uuidRegex, targetMeetingId);
    }

    String replaceTurn(String? url) {
      if (url == null || url.isEmpty) return '';
      return url.replaceFirst(RegExp(r'https://\d{4}\.cell\.'), 'https://$lastFour.cell.');
    }

    final fallback = replaceId(audioFallbackUrl);
    return MediaPlacement(
      // AudioHostUrl must be in TURN format (host:3478). Keep template's URL —
      // the SDK will fail TURN auth (wrong hash) and fall back to AudioFallbackUrl.
      audioHostUrl: audioHostUrl,
      audioFallbackUrl: fallback,
      signalingUrl: replaceId(signalingUrl),
      turnControlUrl: replaceTurn(turnControlUrl),
      screenDataUrl: replaceId(screenDataUrl),
      screenViewingUrl: replaceId(screenViewingUrl),
      screenSharingUrl: replaceId(screenSharingUrl),
      eventIngestionUrl: eventIngestionUrl,
    );
  }
}

class MeetingFeatures {
  final AudioFeatures? audio;

  MeetingFeatures({this.audio});

  factory MeetingFeatures.fromJson(Map<String, dynamic> json) {
    return MeetingFeatures(
      audio: json['Audio'] != null ? AudioFeatures.fromJson(json['Audio']) : null,
    );
  }

  Map<String, dynamic> toJson() => {'Audio': audio?.toJson()};
}

class AudioFeatures {
  final String? echoReduction;

  AudioFeatures({this.echoReduction});

  factory AudioFeatures.fromJson(Map<String, dynamic> json) {
    return AudioFeatures(echoReduction: json['EchoReduction']);
  }

  Map<String, dynamic> toJson() => {'EchoReduction': echoReduction};
}

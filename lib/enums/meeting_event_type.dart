enum MeetingEventType {
  meetingStarted,
  meetingStopped,
  audioSessionStarted,
  audioSessionStopped,
  attendeeJoined,
  attendeeLeft,
  localMute,
  localUnmute,
  remoteMute,
  remoteUnmute,
  videoTileAdded,
  videoTileRemoved,
  videoTilePaused,
  videoTileResumed,
  activeSpeaker,
  volumeChanged,
  deviceChanged,
  audioRouteChanged,
  networkDegraded,
  reconnectAttempt,
  connectionRecovered,
  sessionFailure,
  error,
  info;

  String get label {
    switch (this) {
      case MeetingEventType.meetingStarted:
        return 'Meeting Started';
      case MeetingEventType.meetingStopped:
        return 'Meeting Stopped';
      case MeetingEventType.audioSessionStarted:
        return 'Audio Session Started';
      case MeetingEventType.audioSessionStopped:
        return 'Audio Session Stopped';
      case MeetingEventType.attendeeJoined:
        return 'Attendee Joined';
      case MeetingEventType.attendeeLeft:
        return 'Attendee Left';
      case MeetingEventType.localMute:
        return 'Local Muted';
      case MeetingEventType.localUnmute:
        return 'Local Unmuted';
      case MeetingEventType.remoteMute:
        return 'Remote Muted';
      case MeetingEventType.remoteUnmute:
        return 'Remote Unmuted';
      case MeetingEventType.videoTileAdded:
        return 'Video Tile Added';
      case MeetingEventType.videoTileRemoved:
        return 'Video Tile Removed';
      case MeetingEventType.videoTilePaused:
        return 'Video Tile Paused';
      case MeetingEventType.videoTileResumed:
        return 'Video Tile Resumed';
      case MeetingEventType.activeSpeaker:
        return 'Active Speaker';
      case MeetingEventType.volumeChanged:
        return 'Volume Changed';
      case MeetingEventType.deviceChanged:
        return 'Device Changed';
      case MeetingEventType.audioRouteChanged:
        return 'Audio Route Changed';
      case MeetingEventType.networkDegraded:
        return 'Network Degraded';
      case MeetingEventType.reconnectAttempt:
        return 'Reconnect Attempt';
      case MeetingEventType.connectionRecovered:
        return 'Connection Recovered';
      case MeetingEventType.sessionFailure:
        return 'Session Failure';
      case MeetingEventType.error:
        return 'Error';
      case MeetingEventType.info:
        return 'Info';
    }
  }
}

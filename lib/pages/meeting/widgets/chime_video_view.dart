import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hipster_meeting_test/services/chime_service.dart';

/// Native platform view for rendering Chime video tiles.
/// Uses AndroidView/UiKitView to embed native video surfaces.
class ChimeVideoView extends StatefulWidget {
  final int tileId;
  final bool isMirror;

  const ChimeVideoView({
    super.key,
    required this.tileId,
    this.isMirror = false,
  });

  @override
  State<ChimeVideoView> createState() => _ChimeVideoViewState();
}

class _ChimeVideoViewState extends State<ChimeVideoView> {
  final ChimeService _chimeService = Get.find<ChimeService>();

  @override
  Widget build(BuildContext context) {
    if (Platform.isAndroid) {
      return Transform(
        alignment: Alignment.center,
        transform: widget.isMirror ? Matrix4.diagonal3Values(-1.0, 1.0, 1.0) : Matrix4.identity(),
        child: AndroidView(
          viewType: 'chime_video_view',
          creationParams: {'tileId': widget.tileId},
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: _onPlatformViewCreated,
        ),
      );
    } else if (Platform.isIOS) {
      return Transform(
        alignment: Alignment.center,
        transform: widget.isMirror ? Matrix4.diagonal3Values(-1.0, 1.0, 1.0) : Matrix4.identity(),
        child: UiKitView(
          viewType: 'chime_video_view',
          creationParams: {'tileId': widget.tileId},
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: _onPlatformViewCreated,
        ),
      );
    }

    return const Center(child: Text('Unsupported platform'));
  }

  void _onPlatformViewCreated(int viewId) {
    _chimeService.bindVideoView(widget.tileId, viewId);
  }

  @override
  void dispose() {
    _chimeService.unbindVideoView(widget.tileId);
    super.dispose();
  }
}

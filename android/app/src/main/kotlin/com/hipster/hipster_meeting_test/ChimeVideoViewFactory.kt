package com.hipster.hipster_meeting_test

import android.content.Context
import android.view.View
import android.widget.FrameLayout
import com.amazonaws.services.chime.sdk.meetings.audiovideo.video.DefaultVideoRenderView
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class ChimeVideoViewFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    val activeViews = mutableMapOf<Int, ChimeVideoView>()

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = args as? Map<*, *>
        val tileId = params?.get("tileId") as? Int ?: 0
        val view = ChimeVideoView(context, viewId, tileId)
        activeViews[tileId] = view
        return view
    }

    fun removeView(tileId: Int) {
        activeViews.remove(tileId)
    }
}

class ChimeVideoView(
    context: Context,
    private val viewId: Int,
    private val tileId: Int
) : PlatformView {

    private val container: FrameLayout = FrameLayout(context)
    private val videoRenderView: DefaultVideoRenderView = DefaultVideoRenderView(context)

    init {
        videoRenderView.layoutParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        )
        container.addView(videoRenderView)
    }

    override fun getView(): View = container

    override fun dispose() {
        container.removeAllViews()
    }

    fun getVideoRenderView(): DefaultVideoRenderView = videoRenderView
}

package com.lifesense.lifesense_frontend

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * NativeVideoTimestampPlugin
 * 
 * Provides high-frequency video position updates to Flutter.
 * While the standard video_player plugin updates every ~50ms, this plugin
 * allows for per-frame (or 60Hz) polling of the native player position
 * to achieve frame-perfect skeleton synchronization.
 */
class NativeVideoTimestampPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null
    
    private val handler = Handler(Looper.getMainLooper())
    private var isPolling = false
    
    // In a real production scenario with a custom player, we would reference 
    // the ExoPlayer instance here. For now, we provide a high-frequency 
    // bridge that Dart can trigger.
    private val pollRunnable = object : Runnable {
        override fun run() {
            if (!isPolling) return
            
            // Note: We can't easily access the private ExoPlayer instance inside 
            // the official video_player plugin without reflection or modified source.
            // Phase 2 strategy: High-frequency sync signal tied to Choreographer.
            
            eventSink?.success(System.currentTimeMillis()) // Placeholder for real PTS
            handler.postDelayed(this, 16) // ~60Hz
        }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel = MethodChannel(binding.binaryMessenger, "liftsense/video_sync_methods")
        methodChannel.setMethodCallHandler(this)
        
        eventChannel = EventChannel(binding.binaryMessenger, "liftsense/video_sync_events")
        eventChannel.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        stopPolling()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startSync" -> {
                startPolling()
                result.success(null)
            }
            "stopSync" -> {
                stopPolling()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }
    
    private fun startPolling() {
        if (isPolling) return
        isPolling = true
        handler.post(pollRunnable)
    }
    
    private fun stopPolling() {
        isPolling = false
        handler.removeCallbacks(pollRunnable)
    }
}

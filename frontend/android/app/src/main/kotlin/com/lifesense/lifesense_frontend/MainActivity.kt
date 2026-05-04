package com.lifesense.lifesense_frontend

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Register the high-frequency video sync plugin
        flutterEngine.plugins.add(NativeVideoTimestampPlugin())
    }
}


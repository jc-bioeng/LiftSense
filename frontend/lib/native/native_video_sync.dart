import 'dart:async';
import 'package:flutter/services.dart';

/**
 * NativeVideoSync
 * 
 * Dart interface for the high-frequency native synchronization plugin.
 * Streams pulses at ~60Hz to drive the skeleton rendering loop.
 */
class NativeVideoSync {
  static const MethodChannel _methodChannel = MethodChannel('liftsense/video_sync_methods');
  static const EventChannel _eventChannel = EventChannel('liftsense/video_sync_events');

  static Stream<int>? _syncStream;

  /// Starts the high-frequency sync signal from the native side.
  static Future<void> start() async {
    await _methodChannel.invokeMethod('startSync');
  }

  /// Stops the native sync signal.
  static Future<void> stop() async {
    await _methodChannel.invokeMethod('stopSync');
  }

  /// Stream of timestamps (ms) emitted at high frequency (up to 60Hz).
  static Stream<int> get syncStream {
    _syncStream ??= _eventChannel.receiveBroadcastStream().map((event) => event as int);
    return _syncStream!;
  }
}

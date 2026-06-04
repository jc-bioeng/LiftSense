// liftsense_ffi.dart — Dart FFI bindings for the liftsense_core native library.
//
// All heavy computation (CSV parsing, frame lookup, coordinate mapping,
// biomechanics) happens in C++; Dart receives only pre-computed results.
//
// Usage:
//   LiftsenseNative.init('/path/to/tracking.csv');
//   final frame = LiftsenseNative.queryFrame(timestampMs, vpWidth, vpHeight);
//   LiftsenseNative.dispose();

import 'dart:ffi';
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

// ─── Native Function Typedefs ───────────────────────────────

// ls_init(csv_path, video_w, video_h) → int32
typedef _InitC = Int32 Function(Pointer<Utf8>, Float, Float);
typedef _InitDart = int Function(Pointer<Utf8>, double, double);

// ls_dispose()
typedef _DisposeC = Void Function();
typedef _DisposeDart = void Function();

// ls_query_frame_buf(out_buf, timestamp_ms, vp_w, vp_h, conf_threshold)
typedef _QueryFrameBufC = Void Function(Pointer<Uint8>, Int32, Float, Float, Float);
typedef _QueryFrameBufDart = void Function(Pointer<Uint8>, int, double, double, double);

// ls_compute_biomechanics_buf(out_buf, frame_index)
typedef _ComputeBioBufC = Void Function(Pointer<Uint8>, Int32);
typedef _ComputeBioBufDart = void Function(Pointer<Uint8>, int);

// ls_version() → Pointer<Utf8>
typedef _VersionC = Pointer<Utf8> Function();
typedef _VersionDart = Pointer<Utf8> Function();

// ls_get_info() → LsTrackInfo
typedef _GetInfoC = NativeTrackInfo Function();
typedef _GetInfoDart = NativeTrackInfo Function();

// ls_get_metric_series(metric_id, out_buf, max_len) → int32
typedef _GetMetricSeriesC = Int32 Function(Int32, Pointer<Float>, Int32);
typedef _GetMetricSeriesDart = int Function(int, Pointer<Float>, int);

// ls_detect_segments(out_segments, max_len) → int32
typedef _DetectSegmentsC = Int32 Function(Pointer<NativeSegment>, Int32);
typedef _DetectSegmentsDart = int Function(Pointer<NativeSegment>, int);

// ─── High-Level Dart Data Classes ───────────────────────────

/// A single skeleton point in viewport coordinates.
class SkeletonPoint {
  final double x;
  final double y;
  final double confidence;
  final bool valid;

  const SkeletonPoint(this.x, this.y, this.confidence, this.valid);
}

/// A bone connection between two points.
class SkeletonConnection {
  final int fromIdx;
  final int toIdx;
  final int group; // 0=torso, 1=arms, 2=legs

  const SkeletonConnection(this.fromIdx, this.toIdx, this.group);
}

/// Result of a frame query — pre-transformed skeleton data.
class NativeFrameData {
  final int status;
  final int frameIndex;
  final int timestampMs;
  final List<SkeletonPoint> points;
  final List<SkeletonConnection> connections;

  const NativeFrameData({
    required this.status,
    required this.frameIndex,
    required this.timestampMs,
    required this.points,
    required this.connections,
  });

  bool get isValid => status == 0;

  static const empty = NativeFrameData(
    status: -1, frameIndex: 0, timestampMs: 0,
    points: [], connections: [],
  );
}

/// Biomechanical analysis result.
class NativeBiomechanicsData {
  final int status;
  final double hipAngle;
  final double kneeAngle;
  final double ankleAngle;
  final double trunkAngle;
  final double comX;
  final double comY;
  final double kneeVelocity;
  final double hipVelocity;
  final double tibiaAngle;
  final double hipBias;
  final int repId;
  final int phaseType;

  const NativeBiomechanicsData({
    required this.status,
    required this.hipAngle,
    required this.kneeAngle,
    required this.ankleAngle,
    required this.trunkAngle,
    required this.comX,
    required this.comY,
    required this.kneeVelocity,
    required this.hipVelocity,
    required this.tibiaAngle,
    required this.hipBias,
    required this.repId,
    required this.phaseType,
  });

  bool get isValid => status == 0;

  static const empty = NativeBiomechanicsData(
    status: -1, hipAngle: 0, kneeAngle: 0, ankleAngle: 0,
    trunkAngle: 0, comX: 0, comY: 0, kneeVelocity: 0, hipVelocity: 0,
    tibiaAngle: 0, hipBias: 0, repId: 0, phaseType: 0,
  );
}

final class NativeTrackInfo extends Struct {
  @Int32()
  external int frameCount;
  @Int32()
  external int firstTimestampMs;
  @Int32()
  external int lastTimestampMs;
  @Float()
  external double videoWidth;
  @Float()
  external double videoHeight;
}

/// Native segment data (Rep/Phase)
final class NativeSegment extends Struct {
  @Int32()
  external int startMs;
  @Int32()
  external int endMs;
  @Int32()
  external int type; // 0=DESCENDING, 1=BOTTOM, 2=ASCENDING, 3=LOCKOUT
  @Int32()
  external int repId;
}

// ─── Buffer Sizes (must match C struct layouts) ─────────────
// LsFrameResult:
//   5 × int32 (20 bytes) header
//   17 × LsPoint2D (3 floats + 1 int32 = 16 bytes each) = 272 bytes
//   20 × LsConnection (3 int32 = 12 bytes each) = 240 bytes
//   Total = 532 bytes
const int _kFrameResultSize = 532;

// LsBiomechanicsResult:
//   1 × int32 (status) + 10 × float + 2 × int32 = 52 bytes
const int _kBioResultSize = 52;

// ─── Main API Class ─────────────────────────────────────────

/// High-level Dart interface to the native liftsense_core library.
///
/// All FFI calls are synchronous but sub-millisecond.
/// The engine is a singleton; call [init] once, then [queryFrame] per frame.
class LiftsenseNative {
  static DynamicLibrary? _lib;
  static bool _initialized = false;

  // Cached function pointers
  static late _InitDart _init;
  static late _DisposeDart _dispose;
  static late _QueryFrameBufDart _queryFrameBuf;
  static late _ComputeBioBufDart _computeBioBuf;
  static late _GetMetricSeriesDart _getMetricSeries;
  static late _DetectSegmentsDart _detectSegments;
  static late _GetInfoDart _getInfo;
  static late _VersionDart _version;

  // Pre-allocated native buffers to avoid per-frame allocation
  static Pointer<Uint8>? _frameBuf;
  static Pointer<Uint8>? _bioBuf;

  LiftsenseNative._();

  /// Load the native library and resolve function symbols.
  static void _ensureLoaded() {
    if (_lib != null) return;

    if (Platform.isAndroid) {
      _lib = DynamicLibrary.open('libliftsense_core.so');
    } else if (Platform.isIOS || Platform.isMacOS) {
      _lib = DynamicLibrary.process();
    } else if (Platform.isWindows) {
      _lib = DynamicLibrary.open('liftsense_core.dll');
    } else if (Platform.isLinux) {
      _lib = DynamicLibrary.open('libliftsense_core.so');
    } else {
      throw UnsupportedError('Unsupported platform for liftsense_core');
    }

    _init = _lib!.lookupFunction<_InitC, _InitDart>('ls_init');
    _dispose = _lib!.lookupFunction<_DisposeC, _DisposeDart>('ls_dispose');
    _queryFrameBuf = _lib!.lookupFunction<_QueryFrameBufC, _QueryFrameBufDart>('ls_query_frame_buf');
    _computeBioBuf = _lib!.lookupFunction<_ComputeBioBufC, _ComputeBioBufDart>('ls_compute_biomechanics_buf');
    _getMetricSeries = _lib!.lookupFunction<_GetMetricSeriesC, _GetMetricSeriesDart>('ls_get_metric_series');
    _detectSegments = _lib!.lookupFunction<_DetectSegmentsC, _DetectSegmentsDart>('ls_detect_segments');
    _getInfo = _lib!.lookupFunction<_GetInfoC, _GetInfoDart>('ls_get_info');
    _version = _lib!.lookupFunction<_VersionC, _VersionDart>('ls_version');

    // Allocate persistent buffers (freed in dispose)
    _frameBuf = calloc<Uint8>(_kFrameResultSize);
    _bioBuf = calloc<Uint8>(_kBioResultSize);
  }

  /// Initialize the native engine by loading a CSV tracking file.
  ///
  /// Returns the number of frames loaded, or throws on error.
  static int init(String csvPath, {double videoWidth = 1080, double videoHeight = 1920}) {
    _ensureLoaded();

    final pathPtr = csvPath.toNativeUtf8();
    try {
      final result = _init(pathPtr, videoWidth, videoHeight);
      if (result < 0) {
        final errors = {
          -1: 'File not found: $csvPath',
          -2: 'CSV parse error',
          -3: 'Already initialized — call dispose() first',
        };
        throw Exception('LiftsenseNative.init failed: ${errors[result] ?? "code $result"}');
      }
      _initialized = true;
      return result;
    } finally {
      calloc.free(pathPtr);
    }
  }

  /// Release all native resources. Safe to call multiple times.
  static void dispose() {
    if (_lib == null) return;
    _dispose();
    _initialized = false;

    if (_frameBuf != null) {
      calloc.free(_frameBuf!);
      _frameBuf = null;
    }
    if (_bioBuf != null) {
      calloc.free(_bioBuf!);
      _bioBuf = null;
    }
    _lib = null;
  }

  /// Query skeleton data for a video timestamp.
  ///
  /// Returns pre-transformed points in viewport coordinates.
  /// This is the hot-path call — happens every frame during playback.
  /// Uses a pre-allocated native buffer to avoid per-frame allocation.
  static NativeFrameData queryFrame(
    int timestampMs,
    double viewportWidth,
    double viewportHeight, {
    double confThreshold = 0.45,
  }) {
    if (!_initialized || _frameBuf == null) return NativeFrameData.empty;

    // ── Call C++ (sub-millisecond) ──────────────────────────
    _queryFrameBuf(_frameBuf!, timestampMs, viewportWidth, viewportHeight, confThreshold);

    // ── Decode buffer ──────────────────────────────────────
    return _decodeFrameResult(_frameBuf!);
  }

  /// Extracts the flat memory layout (52 floats: frameIndex + 17 points x 3 values)
  static Float32List extractRawSkeleton(
    int timestampMs,
    double viewportWidth,
    double viewportHeight, {
    double confThreshold = 0.45,
  }) {
    if (!_initialized || _frameBuf == null) return Float32List(0);

    _queryFrameBuf(_frameBuf!, timestampMs, viewportWidth, viewportHeight, confThreshold);
    return _extractSkeletonBuffer(_frameBuf!);
  }

  /// Compute biomechanical metrics for a specific frame.
  static NativeBiomechanicsData computeBiomechanics(int frameIndex) {
    if (!_initialized || _bioBuf == null) return NativeBiomechanicsData.empty;

    _computeBioBuf(_bioBuf!, frameIndex);

    return _decodeBioResult(_bioBuf!);
  }

  /// Extracts the flat metrics layout
  static Float32List extractRawMetrics(int frameIndex) {
    if (!_initialized || _bioBuf == null) return Float32List(0);
    _computeBioBuf(_bioBuf!, frameIndex);
    return _extractMetricsBuffer(_bioBuf!);
  }

  /// Returns a full time-series for a metric (e.g. for charts)
  static Float32List getMetricSeries(int metricId, int maxLen) {
    _ensureLoaded();
    final outBuf = calloc<Float>(maxLen);
    try {
      final count = _getMetricSeries(metricId, outBuf, maxLen);
      if (count <= 0) return Float32List(0);
      return Float32List.fromList(outBuf.asTypedList(count));
    } finally {
      calloc.free(outBuf);
    }
  }

  /// Detects repetitions and phases automatically
  static List<NativeSegment> detectSegments({int maxLen = 100}) {
    _ensureLoaded();
    final outBuf = calloc<NativeSegment>(maxLen);
    try {
      final count = _detectSegments(outBuf, maxLen);
      if (count <= 0) return [];
      // Retornamos los structs nativos directamente (viven hasta liberar outBuf)
      return List.generate(count, (i) => outBuf[i]);
    } finally {
      calloc.free(outBuf);
    }
  }

  /// Get the native library version string.
  static String version() {
    _ensureLoaded();
    return _version().toDartString();
  }

  /// Get summary info about the loaded tracking data.
  static NativeTrackInfo getInfo() {
    _ensureLoaded();
    return _getInfo();
  }

  /// Whether the native engine is currently initialized.
  static bool get isInitialized => _initialized;

  // ─── Private: Buffer Decoding ─────────────────────────────

  static NativeFrameData _decodeFrameResult(Pointer<Uint8> buf) {
    final ints = buf.cast<Int32>();
    final status = ints[0];
    final frameIndex = ints[1];
    final timestampMs = ints[2];
    // ints[3] = numPoints (17), ints[4] = numConnections (20)

    // Points: offset 20 bytes, each LsPoint2D = 16 bytes
    // Layout per point: float x, float y, float confidence, int32 valid
    final points = <SkeletonPoint>[];
    for (int i = 0; i < 17; i++) {
      final baseOffset = 20 + i * 16; // bytes
      final floats = (buf + baseOffset).cast<Float>();
      final validPtr = (buf + baseOffset + 12).cast<Int32>();
      points.add(SkeletonPoint(
        floats[0], // x
        floats[1], // y
        floats[2], // confidence
        validPtr.value != 0,
      ));
    }

    // Connections: offset 292 bytes, each LsConnection = 12 bytes
    final connections = <SkeletonConnection>[];
    for (int i = 0; i < 20; i++) {
      final baseOffset = 292 + i * 12;
      final connInts = (buf + baseOffset).cast<Int32>();
      connections.add(SkeletonConnection(
        connInts[0], // from_idx
        connInts[1], // to_idx
        connInts[2], // group
      ));
    }

    return NativeFrameData(
      status: status,
      frameIndex: frameIndex,
      timestampMs: timestampMs,
      points: points,
      connections: connections,
    );
  }

  static NativeBiomechanicsData _decodeBioResult(Pointer<Uint8> buf) {
    final ints = buf.cast<Int32>();
    final status = ints[0];

    // Floats start at offset 4 bytes
    final floats = (buf + 4).cast<Float>();

    return NativeBiomechanicsData(
      status: status,
      hipAngle: floats[0],
      kneeAngle: floats[1],
      ankleAngle: floats[2],
      trunkAngle: floats[3],
      comX: floats[4],
      comY: floats[5],
      kneeVelocity: floats[6],
      hipVelocity: floats[7],
      tibiaAngle: floats[8],
      hipBias: floats[9],
      repId: ints[11],
      phaseType: ints[12],
    );
  }

  static Float32List _extractSkeletonBuffer(Pointer<Uint8> buf) {
    final ints = buf.cast<Int32>();
    final frameIndex = ints[1];

    // Layout del buffer (532 bytes):
    //   bytes [0..19]   → 5 × int32 (status, frame_index, timestamp_ms, num_points, num_connections)
    //   bytes [20..291] → 17 × LsPoint2D (cada uno: float x, float y, float confidence, int32 valid)
    //
    // Flat output: [frameIndex, x0,y0,c0,  x1,y1,c1, ... x16,y16,c16] = 52 floats
    //   donde ci = confidence si valid==1, -1.0 si valid==0 (señal de punto inválido)
    final flatBuf = Float32List(52); // 1 + 17*3
    flatBuf[0] = frameIndex.toDouble();

    for (int i = 0; i < 17; i++) {
      final baseOffset = 20 + i * 16; // LsPoint2D empieza en byte 20
      final floats   = (buf + baseOffset).cast<Float>();
      final validPtr = (buf + baseOffset + 12).cast<Int32>(); // int32 valid a offset 12
      final int vIndex = 1 + i * 3;
      flatBuf[vIndex]     = floats[0]; // x
      flatBuf[vIndex + 1] = floats[1]; // y
      // -1.0 = inválido (filtrado por confianza) → el painter lo omite
      flatBuf[vIndex + 2] = (validPtr.value != 0) ? floats[2] : -1.0;
    }
    return flatBuf;
  }

  static Float32List _extractMetricsBuffer(Pointer<Uint8> buf) {
    // Extraemos 12 valores (10 floats + 2 ints como floats)
    final flatBuf = Float32List(12);
    final floats = (buf + 4).cast<Float>();
    final ints = buf.cast<Int32>();
    
    flatBuf[0] = floats[0]; // hip
    flatBuf[1] = floats[1]; // knee
    flatBuf[2] = floats[2]; // ankle
    flatBuf[3] = floats[3]; // trunk
    flatBuf[4] = floats[4]; // comX
    flatBuf[5] = floats[5]; // comY
    flatBuf[6] = floats[6]; // kneeVelocity
    flatBuf[7] = floats[7]; // hipVelocity
    flatBuf[8] = floats[8]; // tibiaAngle
    flatBuf[9] = floats[9]; // hipBias
    flatBuf[10] = ints[11].toDouble(); // repId
    flatBuf[11] = ints[12].toDouble(); // phaseType
    return flatBuf;
  }
}

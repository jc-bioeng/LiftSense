import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart';

// ============================================================================
// DART FFI STRUCTS
// ============================================================================

final class NativeLandmark extends ffi.Struct {
  @ffi.Float() external double x;
  @ffi.Float() external double y;
  @ffi.Float() external double z;
  @ffi.Float() external double conf;
}

final class NativePoseFrame extends ffi.Struct {
  @ffi.Int32() external int frameIndex;
  @ffi.Int64() external int timeMs;

  @ffi.Array(33)
  external ffi.Array<NativeLandmark> landmarks;

  @ffi.Float() external double comX;
  @ffi.Float() external double comY;
  @ffi.Float() external double midHipX;
  @ffi.Float() external double midHipY;
  @ffi.Float() external double midFootX;
  @ffi.Float() external double heelX;
  @ffi.Float() external double footIndexX;
}

final class NativeJointAngles extends ffi.Struct {
  @ffi.Float() external double leftKnee;
  @ffi.Float() external double rightKnee;
  @ffi.Float() external double leftHip;
  @ffi.Float() external double rightHip;
  @ffi.Float() external double trunkFlexion;
  @ffi.Float() external double tibiaAngle;
  @ffi.Float() external double valgusAngle;
  @ffi.Float() external double comProjection;
  @ffi.Float() external double hipKneeRatio;
  @ffi.Float() external double lumbarLoadingProxy;
  @ffi.Float() external double patellofemoralStressProxy;
  @ffi.Float() external double buttWinkProbability;
}

final class NativeBiomechanicalMetrics extends ffi.Struct {
  external NativeJointAngles angles;
  @ffi.Int32() external int phase;
  @ffi.Int32() external int warningLevel;
  @ffi.Float() external double verticalVelocity;
  @ffi.Float() external double asymmetryIndex;
  @ffi.Bool() external bool isRiskDetected;
}

// ============================================================================
// FFI TYPEDEFS
// ============================================================================
typedef CreateEngineC = ffi.Pointer<ffi.Void> Function(ffi.Int32 viewType);
typedef CreateEngineDart = ffi.Pointer<ffi.Void> Function(int viewType);

typedef DestroyEngineC = ffi.Void Function(ffi.Pointer<ffi.Void> enginePtr);
typedef DestroyEngineDart = void Function(ffi.Pointer<ffi.Void> enginePtr);

typedef ProcessFrameC = NativeBiomechanicalMetrics Function(
    ffi.Pointer<ffi.Void> enginePtr, ffi.Pointer<NativePoseFrame> frame);
typedef ProcessFrameDart = NativeBiomechanicalMetrics Function(
    ffi.Pointer<ffi.Void> enginePtr, ffi.Pointer<NativePoseFrame> frame);

// ============================================================================
// BIOMECH NATIVE SERVICE (Wrapper)
// ============================================================================

class BiomechNativeService {
  late final ffi.DynamicLibrary _lib;
  late final CreateEngineDart _createEngine;
  late final DestroyEngineDart _destroyEngine;
  late final ProcessFrameDart _processFrame;

  ffi.Pointer<ffi.Void>? _enginePtr;

  // REUSABLE NATIVE MEMORY (Zero-Copy target)
  // Dart asume el ownership total del ciclo de vida de este buffer.
  ffi.Pointer<NativePoseFrame>? sharedFramePtr;

  BiomechNativeService() {
    _loadLibrary();
    _bindFunctions();
  }

  void _loadLibrary() {
    if (Platform.isAndroid) {
      _lib = ffi.DynamicLibrary.open('libcpp_engine.so');
    } else if (Platform.isWindows) {
      _lib = ffi.DynamicLibrary.open('cpp_engine.dll');
    } else if (Platform.isIOS || Platform.isMacOS) {
      _lib = ffi.DynamicLibrary.process();
    } else {
      throw UnsupportedError('Unsupported platform for FFI');
    }
  }

  void _bindFunctions() {
    _createEngine = _lib.lookupFunction<CreateEngineC, CreateEngineDart>('create_engine');
    _destroyEngine = _lib.lookupFunction<DestroyEngineC, DestroyEngineDart>('destroy_engine');
    _processFrame = _lib.lookupFunction<ProcessFrameC, ProcessFrameDart>('process_frame');
  }

  void initEngine(int viewType) {
    if (_enginePtr != null) return;
    _enginePtr = _createEngine(viewType);
    
    // Asignar memoria nativa reutilizable (Malloc manejado por Dart)
    sharedFramePtr = calloc<NativePoseFrame>();
  }

  /// Procesa el frame invocando C++. 
  /// Se asume que [sharedFramePtr] ya fue sobreescrito con los nuevos bytes.
  NativeBiomechanicalMetrics processSharedFrame() {
    if (_enginePtr == null || sharedFramePtr == null) {
      throw StateError("Engine not initialized");
    }
    // Llamada FFI Zero-copy
    return _processFrame(_enginePtr!, sharedFramePtr!);
  }

  void dispose() {
    if (_enginePtr != null) {
      _destroyEngine(_enginePtr!);
      _enginePtr = null;
    }
    
    // Liberar memoria nativa explícitamente para evitar memory leaks
    if (sharedFramePtr != null) {
      calloc.free(sharedFramePtr!);
      sharedFramePtr = null;
    }
  }
}

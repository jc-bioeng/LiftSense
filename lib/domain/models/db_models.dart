import 'dart:typed_data';

class AppUser {
  final String id;
  final String? email;
  final int createdAt;

  AppUser({required this.id, this.email, required this.createdAt});

  Map<String, dynamic> toMap() => {
    'id': id,
    'email': email,
    'created_at': createdAt,
  };
}

class Session {
  final String id;
  final String userId;
  final int startTime;
  final String? notes;
  final int isSynced;

  Session({required this.id, required this.userId, required this.startTime, this.notes, this.isSynced = 0});

  Map<String, dynamic> toMap() => {
    'id': id,
    'user_id': userId,
    'start_time': startTime,
    'notes': notes,
    'is_synced': isSynced,
  };
}

class VideoRecord {
  final String id;
  final String sessionId;
  final String filePath;
  final double fps;
  final String? resolution;

  VideoRecord({required this.id, required this.sessionId, required this.filePath, required this.fps, this.resolution});

  Map<String, dynamic> toMap() => {
    'id': id,
    'session_id': sessionId,
    'file_path': filePath,
    'fps': fps,
    'resolution': resolution,
  };
}

class LiftSet {
  final String id;
  final String sessionId;
  final String videoId;
  final String exerciseType;
  final String viewType;
  final double? weightKg;

  LiftSet({required this.id, required this.sessionId, required this.videoId, required this.exerciseType, required this.viewType, this.weightKg});

  Map<String, dynamic> toMap() => {
    'id': id,
    'session_id': sessionId,
    'video_id': videoId,
    'exercise_type': exerciseType,
    'view_type': viewType,
    'weight_kg': weightKg,
  };
}

class Repetition {
  final String id;
  final String setId;
  final int repNumber;
  final int startTimeMs;
  final int endTimeMs;
  final double? maxDepthCm;
  final double? maxConcentricVelocity;
  final double? minHipKneeRatio;
  final int isValid;

  Repetition({required this.id, required this.setId, required this.repNumber, required this.startTimeMs, required this.endTimeMs, this.maxDepthCm, this.maxConcentricVelocity, this.minHipKneeRatio, this.isValid = 1});

  Map<String, dynamic> toMap() => {
    'id': id,
    'set_id': setId,
    'rep_number': repNumber,
    'start_time_ms': startTimeMs,
    'end_time_ms': endTimeMs,
    'max_depth_cm': maxDepthCm,
    'max_concentric_velocity': maxConcentricVelocity,
    'min_hip_knee_ratio': minHipKneeRatio,
    'is_valid': isValid,
  };
}

class FrameMetric {
  final String id;
  final String setId;
  final int timeMs;
  final String phase;
  final String warningLevel;
  
  final double? verticalVelocity;
  final double? leftKneeAngle;
  final double? rightKneeAngle;
  final double? leftHipAngle;
  final double? rightHipAngle;
  
  final double? trunkAngle;
  final double? tibiaAngle;
  final double? comProjection;
  final double? hipKneeRatio;
  final double? valgusAngle;
  final double? asymmetryIndex;
  
  final Uint8List? landmarksBlob;

  FrameMetric({
    required this.id, required this.setId, required this.timeMs, required this.phase, required this.warningLevel,
    this.verticalVelocity, this.leftKneeAngle, this.rightKneeAngle, this.leftHipAngle, this.rightHipAngle,
    this.trunkAngle, this.tibiaAngle, this.comProjection, this.hipKneeRatio, this.valgusAngle, this.asymmetryIndex,
    this.landmarksBlob,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'set_id': setId,
    'time_ms': timeMs,
    'phase': phase,
    'warning_level': warningLevel,
    'vertical_velocity': verticalVelocity,
    'left_knee_angle': leftKneeAngle,
    'right_knee_angle': rightKneeAngle,
    'left_hip_angle': leftHipAngle,
    'right_hip_angle': rightHipAngle,
    'trunk_angle': trunkAngle,
    'tibia_angle': tibiaAngle,
    'com_projection': comProjection,
    'hip_knee_ratio': hipKneeRatio,
    'valgus_angle': valgusAngle,
    'asymmetry_index': asymmetryIndex,
    'landmarks_blob': landmarksBlob,
  };
}

class Alert {
  final String id;
  final String setId;
  final String? repId;
  final int timeMs;
  final String alertType;
  final String severity;
  final String? description;

  Alert({required this.id, required this.setId, this.repId, required this.timeMs, required this.alertType, required this.severity, this.description});

  Map<String, dynamic> toMap() => {
    'id': id,
    'set_id': setId,
    'rep_id': repId,
    'time_ms': timeMs,
    'alert_type': alertType,
    'severity': severity,
    'description': description,
  };
}

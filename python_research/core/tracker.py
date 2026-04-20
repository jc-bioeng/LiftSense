"""
Este módulo provee la abstracción del motor de inferencia de postura.
Utiliza MediaPipe Tasks (PoseLandmarker) para compatibilidad con versiones modernas.
"""

import mediapipe as mp
from mediapipe.tasks import python
from mediapipe.tasks.python import vision
import numpy as np

class PoseResult:
    def __init__(self, keypoints, raw_results=None):
        """
        keypoints: diccionario mapping de 'landmark_name' -> {'x': float, 'y': float, 'z': float, 'conf': float}
        """
        self.keypoints = keypoints
        self.raw_results = raw_results

class MediaPipePoseTracker:
    def __init__(self, model_path='pose_landmarker_full.task'):
        base_options = python.BaseOptions(model_asset_path=model_path)
        options = vision.PoseLandmarkerOptions(
            base_options=base_options,
            running_mode=vision.RunningMode.IMAGE,
            num_poses=1,
            min_pose_detection_confidence=0.5,
            min_pose_presence_confidence=0.5,
            min_tracking_confidence=0.5,
            output_segmentation_masks=False
        )
        self.detector = vision.PoseLandmarker.create_from_options(options)
        
        # Diccionario para mapear nombres a índices de MediaPipe (los mismos 33 tradicionales)
        self.lm_mapping = {
            'nose': 0,
            'l_shoulder': 11, 'r_shoulder': 12,
            'l_elbow': 13, 'r_elbow': 14,
            'l_wrist': 15, 'r_wrist': 16,
            'l_hip': 23, 'r_hip': 24,
            'l_knee': 25, 'r_knee': 26,
            'l_ankle': 27, 'r_ankle': 28,
            'l_heel': 29, 'r_heel': 30,
            'l_foot_index': 31, 'r_foot_index': 32
        }

    def process_frame(self, image_rgb):
        """
        Procesa una imagen RGB y devuelve un PoseResult object.
        """
        mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=image_rgb)
        detection_result = self.detector.detect(mp_image)
        
        parsed_keypoints = {}
        if detection_result.pose_landmarks:
            height, width, _ = image_rgb.shape
            # Tomamos la primera pose detectada
            landmarks = detection_result.pose_landmarks[0]
            for name, idx in self.lm_mapping.items():
                # Refuerzo de Seguridad: En MediaPipe, Z nariz < Z hombro significa que 
                # la cara apunta a la cámara (frontal). MediaPipe entrega coordenadas 
                # 3D relativas donde Z-negativo es 'hacia la cámara'.
                landmark = landmarks[idx]
                parsed_keypoints[name] = {
                    'x': landmark.x * width,
                    'y': landmark.y * height,
                    'z': landmark.z,
                    'conf': landmark.visibility if hasattr(landmark, 'visibility') else 0.5
                }
        
        return PoseResult(parsed_keypoints, raw_results=detection_result)

    def close(self):
        self.detector.close()

    def mp_pose_pose_draw(self, results, image):
        # Esta versión de Tasks no trae un dibujante automático como el legacy 'mp_draw'
        # Pero podemos dibujar círculos básicos si es necesario.
        # Por ahora lo dejamos como stub para no romper la llamada en pose_tracker.py
        pass

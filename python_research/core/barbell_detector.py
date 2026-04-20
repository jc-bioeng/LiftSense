"""
barbell_detector.py
Detección de barra (rod) y discos mediante visión computacional clásica.
Diferencia entre Varilla (Hough Lines) para Frontal/Back
y Discos (Hough Circles) para Lateral.
"""

import cv2
import numpy as np


class BarbellDetector:
    def __init__(self):
        self.last_observation = False
        self.buffer = []
        self.BUFFER_SIZE = 10

    def detect_frontal_rod(self, frame_gray: np.ndarray, kps: dict) -> bool:
        """
        Busca una línea horizontal larga que atraviese los hombros.
        """
        l_sh = kps.get('l_shoulder')
        r_sh = kps.get('r_shoulder')
        if not (l_sh and r_sh and l_sh['conf'] > 0.5 and r_sh['conf'] > 0.5):
            return False

        h, w = frame_gray.shape
        # Definir ROI alrededor de los hombros
        y_center = int((l_sh['y'] + r_sh['y']) / 2)
        sh_width = abs(l_sh['x'] - r_sh['x'])
        
        y1 = max(0, y_center - 40)
        y2 = min(h, y_center + 40)
        # Extendemos el ROI lateralmente ya que la barra sobresale
        x1 = max(0, int(min(l_sh['x'], r_sh['x']) - sh_width * 0.5))
        x2 = min(w, int(max(l_sh['x'], r_sh['x']) + sh_width * 0.5))

        roi = frame_gray[y1:y2, x1:x2]
        if roi.size == 0: return False

        # Procesamiento para resaltar la barra (línea brillante/oscura horizontal)
        edges = cv2.Canny(roi, 50, 150, apertureSize=3)
        
        # HoughLinesP para detectar segmentos
        lines = cv2.HoughLinesP(edges, 1, np.pi/180, threshold=40, 
                                minLineLength=sh_width * 0.6, maxLineGap=20)

        if lines is not None:
            # Filtrar por horizontalidad (ángulo < 15 grados)
            for line in lines:
                x_a, y_a, x_b, y_b = line[0]
                angle = abs(np.degrees(np.arctan2(y_b - y_a, x_b - x_a)))
                if angle < 15 or angle > 165:
                    return True
        return False

    def verify_with_buffer(self, observed: bool) -> bool:
        self.buffer.append(observed)
        if len(self.buffer) > self.BUFFER_SIZE:
            self.buffer.pop(0)
        
        # Consenso: 60% de los frames deben verla
        if len(self.buffer) < 5: return observed
        return sum(self.buffer) / len(self.buffer) > 0.6

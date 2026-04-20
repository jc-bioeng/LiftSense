"""
plate_detector.py
Detecta discos de barra usando Hough Circles clásico.
Acepta un radio esperado (en px) derivado de la calibración antropométrica
para filtrar aros de tamaño imposible.
"""

import cv2
import numpy as np


class PlateDetector:

    def detect(self, image_gray: np.ndarray, wrist_x: float, wrist_y: float,
               direction: str, expected_radius_px: int | None = None):
        """
        image_gray      : Frame en escala de grises.
        wrist_x/y       : Coordenadas de la muñeca.
        direction       : 'left' o 'right'.
        expected_radius_px: Radio esperado de un disco olímpico en píxeles.
                            Si se provee, restringe la búsqueda a ±50% de ese valor.
        """
        h, w = image_gray.shape

        # Región de Interés: sólo al lado de la muñeca
        margin_x = 280
        margin_y = 160

        if direction == 'left':
            x1, x2 = max(0, int(wrist_x - margin_x)), max(0, int(wrist_x))
        else:
            x1, x2 = min(w, int(wrist_x)), min(w, int(wrist_x + margin_x))

        y1 = max(0, int(wrist_y - margin_y))
        y2 = min(h, int(wrist_y + margin_y))

        if x2 - x1 < 20 or y2 - y1 < 20:
            return None

        roi = cv2.medianBlur(image_gray[y1:y2, x1:x2], 5)

        # Rango de radios estricto (±20% del esperado)
        if expected_radius_px and expected_radius_px > 20:
            min_r = int(expected_radius_px * 0.80)
            max_r = int(expected_radius_px * 1.20)
        else:
            # Fallback si no hay calibración (menos preciso)
            min_r, max_r = 40, 150

        circles = cv2.HoughCircles(
            roi, cv2.HOUGH_GRADIENT, dp=1.2, minDist=expected_radius_px or 50,
            param1=50, param2=38,  # param2 más alto = más estricto con la redondez
            minRadius=min_r, maxRadius=max_r
        )

        if circles is None:
            return None

        for c in circles[0]:
            cx, cy, r = int(c[0]), int(c[1]), int(c[2])
            # Validación de Textura: Un disco de metal es liso y uniforme.
            # Ruid (caras, sillas) tiene mucha variación interna.
            sample_r = int(r * 0.4)
            sy1, sy2 = max(0, cy - sample_r), min(roi.shape[0], cy + sample_r)
            sx1, sx2 = max(0, cx - sample_r), min(roi.shape[1], cx + sample_r)
            sample = roi[sy1:sy2, sx1:sx2]
            
            if sample.size > 0:
                # Calculamos la variación de color/brillo.
                # Un disco de hierro o goma tiene una textura mate y uniforme (baja desviación).
                # Reflejos, caras u objetos domésticos tienen alta desviación estándar.
                std_dev = np.std(sample)
                if std_dev < 22: # Umbral de uniformidad (experimental para discos)
                    return (cx + x1, cy + y1, r)
        
        return None

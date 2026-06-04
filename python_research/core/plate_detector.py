"""
plate_detector.py
Detecta discos de barra usando Hough Circles clásico.

Mejoras respecto a la versión anterior:
  1. Tracking espacial: mantiene EMA de la última posición del disco
  2. Anti-salto: rechaza detecciones que saltan >60px entre frames
  3. Coherencia con hombro: el disco debe estar a una distancia razonable
  4. ROI dinámico: anclado al hombro visible, no a la muñeca
  5. Validación de radio mejorada: consistencia temporal del tamaño
"""

import cv2
import numpy as np


class PlateDetector:

    def __init__(self):
        # ── Tracking espacial ────────────────────────────────────────────────
        self._last_plate_pos: tuple | None = None   # (x, y, r) del último disco
        self._ema_pos: tuple | None = None           # EMA de la posición
        self._consecutive_detections = 0
        self._consecutive_misses = 0
        self.MAX_JUMP_PX = 60                        # Máximo salto aceptable
        self.MIN_CONSECUTIVE_FOR_LOCK = 3            # Detecciones seguidas para confiar

    def detect(self, image_gray: np.ndarray, anchor_x: float, anchor_y: float,
               direction: str, expected_radius_px: int | None = None):
        """
        Detecta un disco de barra cerca del punto de anclaje (hombro).

        Args:
            image_gray: Frame en escala de grises
            anchor_x/y: Coordenadas del punto de anclaje (hombro, no muñeca)
            direction: 'left' o 'right'
            expected_radius_px: Radio esperado del disco en píxeles

        Returns:
            (x, y, r) del disco detectado, o None
        """
        h, w = image_gray.shape

        # ── ROI dinámico anclado al hombro ───────────────────────────────────
        # Si tenemos tracking, el ROI se centra en la última posición conocida
        if self._ema_pos is not None:
            # ROI más pequeño centrado en el tracking (seguimiento preciso)
            ema_x, ema_y, ema_r = self._ema_pos
            margin = max(80, int(ema_r * 3))
            x1 = max(0, int(ema_x - margin))
            x2 = min(w, int(ema_x + margin))
            y1 = max(0, int(ema_y - margin))
            y2 = min(h, int(ema_y + margin))
        else:
            # Primera detección: ROI amplio basado en el hombro
            margin_x = 250
            margin_y = 180

            if direction == 'left':
                x1 = max(0, int(anchor_x - margin_x))
                x2 = max(0, int(anchor_x + 30))  # Ligeramente más allá del hombro
            else:
                x1 = min(w, int(anchor_x - 30))
                x2 = min(w, int(anchor_x + margin_x))

            y1 = max(0, int(anchor_y - margin_y))
            y2 = min(h, int(anchor_y + margin_y))

        if x2 - x1 < 20 or y2 - y1 < 20:
            self._on_miss()
            return None

        roi = cv2.medianBlur(image_gray[y1:y2, x1:x2], 5)

        # ── Rango de radios adaptativo ───────────────────────────────────────
        if expected_radius_px and expected_radius_px > 20:
            min_r = int(expected_radius_px * 0.70)
            max_r = int(expected_radius_px * 1.30)
        elif self._ema_pos is not None:
            # Si tenemos tracking, usar el radio previo ±25%
            ema_r = self._ema_pos[2]
            min_r = int(ema_r * 0.75)
            max_r = int(ema_r * 1.25)
        else:
            min_r, max_r = 35, 160

        # ── Hough Circles ────────────────────────────────────────────────────
        circles = cv2.HoughCircles(
            roi, cv2.HOUGH_GRADIENT,
            dp=1.2,
            minDist=max(min_r, 40),
            param1=50,
            param2=28,
            minRadius=min_r,
            maxRadius=max_r
        )

        if circles is None:
            self._on_miss()
            return None

        # ── Seleccionar el mejor candidato ───────────────────────────────────
        best_circle = None
        best_score = -1

        for c in circles[0]:
            cx, cy, r = int(c[0]), int(c[1]), int(c[2])

            # Coordenadas globales
            gx = cx + x1
            gy = cy + y1

            # 1. Validación de textura (el disco es relativamente uniforme)
            sample_r = int(r * 0.35)
            sy1 = max(0, cy - sample_r)
            sy2 = min(roi.shape[0], cy + sample_r)
            sx1 = max(0, cx - sample_r)
            sx2 = min(roi.shape[1], cx + sample_r)
            sample = roi[sy1:sy2, sx1:sx2]

            if sample.size == 0:
                continue

            std_dev = np.std(sample)
            # Disco metálico: std_dev entre 5 y 50 (no completamente uniforme,
            # pero tampoco caótico como una pared con textura)
            if std_dev > 55:
                continue

            # 2. Distancia al hombro: debe ser razonable
            dist_to_anchor = np.hypot(gx - anchor_x, gy - anchor_y)
            if dist_to_anchor > 350:  # Muy lejos del hombro
                continue

            # 3. Proximidad vertical al hombro (el disco está a la altura del hombro)
            y_diff = abs(gy - anchor_y)
            if y_diff > 150:  # Demasiado arriba/abajo
                continue

            # 4. Coherencia espacial con tracking previo
            spatial_penalty = 0.0
            if self._ema_pos is not None:
                ema_x, ema_y, ema_r = self._ema_pos
                jump = np.hypot(gx - ema_x, gy - ema_y)
                if jump > self.MAX_JUMP_PX:
                    continue  # Rechazar saltos
                spatial_penalty = jump / self.MAX_JUMP_PX

            # Score: prioriza proximidad al tracking + tamaño consistente
            score = (1.0 - spatial_penalty) * 0.6 + (1.0 - std_dev / 55) * 0.4

            if score > best_score:
                best_score = score
                best_circle = (gx, gy, int(r))

        if best_circle is None:
            self._on_miss()
            return None

        # ── Actualizar tracking ──────────────────────────────────────────────
        gx, gy, r = best_circle
        self._update_tracking(gx, gy, r)

        return best_circle

    def _update_tracking(self, x: float, y: float, r: float):
        """Actualiza el EMA de posición del disco."""
        if self._ema_pos is None:
            self._ema_pos = (x, y, r)
        else:
            alpha = 0.35
            ex, ey, er = self._ema_pos
            self._ema_pos = (
                alpha * x + (1 - alpha) * ex,
                alpha * y + (1 - alpha) * ey,
                alpha * r + (1 - alpha) * er,
            )
        self._consecutive_detections += 1
        self._consecutive_misses = 0

    def _on_miss(self):
        """Registra un frame sin detección."""
        self._consecutive_misses += 1
        self._consecutive_detections = 0
        # Si perdemos el disco por muchos frames, liberar el tracking
        if self._consecutive_misses > 20:
            self._ema_pos = None

    @property
    def is_tracking(self) -> bool:
        """True si el detector tiene un disco en seguimiento estable."""
        return self._consecutive_detections >= self.MIN_CONSECUTIVE_FOR_LOCK

    def reset(self):
        """Resetea el estado para un nuevo video."""
        self._last_plate_pos = None
        self._ema_pos = None
        self._consecutive_detections = 0
        self._consecutive_misses = 0

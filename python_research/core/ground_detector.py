"""
ground_detector.py
Detección del plano del suelo usando 3 métodos en cascada:
  1. Hough Lines — detecta la línea horizontal del piso real
  2. Heel Anchor — promedio bilateral de talones
  3. Torso Projection — proyección descendente desde la cadera usando cm_per_pixel

Incluye suavizado temporal (EMA) para evitar saltos entre frames.
"""

import cv2
import numpy as np
import math


class GroundDetector:
    """
    Detecta la coordenada Y del suelo en cada frame.
    El resultado se suaviza temporalmente para mantener estabilidad visual.
    """

    def __init__(self):
        self._smoothed_y: float | None = None
        self._alpha = 0.15  # EMA: 15% peso al nuevo valor, 85% al histórico
        self._method_used: str = "none"
        self._consecutive_hough = 0
        self._hough_lock_y: float | None = None  # Bloqueo si Hough es estable

    def detect(self, frame_gray: np.ndarray, kps: dict,
               cm_per_pixel: float | None = None,
               height_cm: float = 175.0) -> dict:
        """
        Intenta detectar el suelo usando los 3 métodos en cascada.

        Returns:
            dict con:
              - ground_y_px: float   — Coordenada Y del suelo
              - ground_method: str   — Método usado ('hough', 'heel', 'projection', 'none')
              - ground_confidence: float — Confianza del método (0.0–1.0)
        """
        result_y = None
        method = "none"
        confidence = 0.0

        # ── Método 1: Hough Lines (máxima confianza) ─────────────────────────
        hough_y = self._detect_by_hough(frame_gray, kps)
        if hough_y is not None:
            result_y = hough_y
            method = "hough"
            confidence = 0.95
            self._consecutive_hough += 1
            # Si Hough es estable por 15+ frames, bloqueamos su valor
            if self._consecutive_hough >= 15:
                self._hough_lock_y = self._smoothed_y or hough_y
        else:
            self._consecutive_hough = 0

        # ── Método 2: Heel Anchor (confianza media) ──────────────────────────
        if result_y is None:
            heel_y = self._detect_by_heels(kps)
            if heel_y is not None:
                result_y = heel_y
                method = "heel"
                confidence = 0.70

        # ── Método 3: Torso Projection (fallback) ────────────────────────────
        if result_y is None and cm_per_pixel:
            proj_y = self._detect_by_projection(kps, cm_per_pixel, height_cm)
            if proj_y is not None:
                result_y = proj_y
                method = "projection"
                confidence = 0.40

        # ── Fallback al bloqueo de Hough previo ──────────────────────────────
        if result_y is None and self._hough_lock_y is not None:
            result_y = self._hough_lock_y
            method = "hough_locked"
            confidence = 0.80

        # ── Suavizado temporal (EMA) ─────────────────────────────────────────
        if result_y is not None:
            if self._smoothed_y is None:
                self._smoothed_y = result_y
            else:
                # Cambios muy grandes (>50px) = salto, rechazar parcialmente
                delta = abs(result_y - self._smoothed_y)
                alpha = self._alpha if delta < 50 else 0.05
                self._smoothed_y = alpha * result_y + (1 - alpha) * self._smoothed_y

        return {
            'ground_y_px': self._smoothed_y,
            'ground_method': method,
            'ground_confidence': confidence,
        }

    # ─── Método 1: Hough Lines ───────────────────────────────────────────────

    def _detect_by_hough(self, frame_gray: np.ndarray, kps: dict) -> float | None:
        """
        Detecta la línea horizontal más baja (suelo) en la mitad inferior del frame.
        Filtra por:
          - Longitud mínima (>25% del ancho del frame)
          - Horizontalidad (<8°)
          - Posición: debe estar por debajo de las rodillas
        """
        h, w = frame_gray.shape

        # Solo buscar en el tercio inferior del frame (donde está el suelo)
        y_start = int(h * 0.55)
        roi = frame_gray[y_start:, :]

        if roi.size == 0:
            return None

        # Pre-procesamiento para resaltar bordes del piso
        blurred = cv2.GaussianBlur(roi, (5, 5), 0)
        edges = cv2.Canny(blurred, 30, 100, apertureSize=3)

        # Detectar segmentos horizontales largos
        min_length = int(w * 0.25)
        lines = cv2.HoughLinesP(edges, 1, np.pi / 180,
                                threshold=50,
                                minLineLength=min_length,
                                maxLineGap=30)

        if lines is None:
            return None

        # Filtrar por horizontalidad y buscar la más baja (candidata a suelo)
        floor_candidates = []
        for line in lines:
            x1, y1, x2, y2 = line[0]
            angle = abs(math.degrees(math.atan2(y2 - y1, x2 - x1)))
            if angle < 8 or angle > 172:
                # Coordenada Y global (compensar el offset del ROI)
                global_y = (y1 + y2) / 2 + y_start
                line_length = math.hypot(x2 - x1, y2 - y1)
                floor_candidates.append((global_y, line_length))

        if not floor_candidates:
            return None

        # Validar contra posición de rodillas: el suelo debe estar debajo
        knee_y = self._get_lowest_knee_y(kps)
        valid_candidates = []
        for gy, length in floor_candidates:
            if knee_y is None or gy > knee_y:
                valid_candidates.append((gy, length))

        if not valid_candidates:
            return None

        # Elegir la línea más larga entre las candidatas más bajas (top-3 por Y)
        valid_candidates.sort(key=lambda c: c[0], reverse=True)
        top_low = valid_candidates[:3]
        best = max(top_low, key=lambda c: c[1])
        return best[0]

    # ─── Método 2: Heel Anchor ───────────────────────────────────────────────

    def _detect_by_heels(self, kps: dict) -> float | None:
        """
        Usa ambos talones como ancla del suelo.
        Requiere alta confianza bilateral para evitar falsos positivos.
        """
        heel_ys = []

        for name in ['l_heel', 'r_heel']:
            kp = kps.get(name)
            if kp and kp['conf'] > 0.65:
                heel_ys.append(kp['y'])

        # Solo usar foot_index si los talones no son suficientes
        if len(heel_ys) < 2:
            for name in ['l_foot_index', 'r_foot_index']:
                kp = kps.get(name)
                if kp and kp['conf'] > 0.70:
                    heel_ys.append(kp['y'])

        if len(heel_ys) >= 2:
            # El suelo es el punto más bajo + un pequeño margen (el talón
            # está ligeramente por encima del suelo real)
            return max(heel_ys) + 5  # +5px de margen por la suela del zapato
        return None

    # ─── Método 3: Torso Projection ──────────────────────────────────────────

    def _detect_by_projection(self, kps: dict, cm_per_pixel: float,
                               height_cm: float) -> float | None:
        """
        Proyecta la posición del suelo desde la cadera usando la proporción
        anatómica: las piernas son ~53% de la altura total (Drillis & Contini).
        """
        hip_kps = []
        for name in ['l_hip', 'r_hip']:
            kp = kps.get(name)
            if kp and kp['conf'] > 0.5:
                hip_kps.append(kp)

        if not hip_kps:
            return None

        mid_hip_y = sum(kp['y'] for kp in hip_kps) / len(hip_kps)

        # Piernas ≈ 53% de la altura; de cadera a suelo ≈ 47% de altura total
        leg_length_cm = height_cm * 0.47
        leg_length_px = leg_length_cm / cm_per_pixel

        return mid_hip_y + leg_length_px

    # ─── Helpers ─────────────────────────────────────────────────────────────

    def _get_lowest_knee_y(self, kps: dict) -> float | None:
        """Devuelve la Y más baja de las rodillas (para validar que el suelo esté debajo)."""
        ys = []
        for name in ['l_knee', 'r_knee']:
            kp = kps.get(name)
            if kp and kp['conf'] > 0.4:
                ys.append(kp['y'])
        return max(ys) if ys else None

    def reset(self):
        """Resetea el estado para un nuevo video."""
        self._smoothed_y = None
        self._consecutive_hough = 0
        self._hough_lock_y = None
        self._method_used = "none"

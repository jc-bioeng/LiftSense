"""
barbell_detector.py
Detección de barra (rod) y validación temporal con coherencia espacial.

Mejoras respecto a la versión anterior:
  1. Coherencia espacial: la posición de la barra debe ser consistente entre frames
  2. Buffer de histéresis: diferentes umbrales para activar vs desactivar
  3. Anti-flicker: cambios de estado requieren consenso sostenido
  4. Anchoring: la barra detectada debe estar cerca de C7 (centro de hombros)
"""

import cv2
import numpy as np
import math


class BarbellDetector:
    def __init__(self):
        # ── Buffer temporal ──────────────────────────────────────────────────
        self.buffer: list[bool] = []
        self.BUFFER_SIZE = 15           # Ventana más amplia para estabilidad

        # ── Histéresis ───────────────────────────────────────────────────────
        self._state = False             # Estado actual (barra detectada o no)
        self.ACTIVATE_THRESHOLD = 0.65  # 65% de frames positivos para activar
        self.DEACTIVATE_THRESHOLD = 0.25  # <25% para desactivar (resistente a pérdidas)

        # ── Coherencia espacial de la barra ──────────────────────────────────
        self._last_rod_y: float | None = None   # Última Y de la barra (rod detection)
        self._rod_y_ema: float | None = None    # EMA de la posición Y de la barra
        self.ROD_MAX_JUMP_PX = 40               # Máximo salto permitido entre frames

    def detect_frontal_rod(self, frame_gray: np.ndarray, kps: dict) -> bool:
        """
        Busca una línea horizontal larga que atraviese los hombros.
        Ahora con validación de coherencia espacial:
          - La línea debe estar cerca de C7 (centro de hombros)
          - Debe ser consistente con detecciones previas
          - Filtra líneas que "saltan" a paredes/bordes
        """
        l_sh = kps.get('l_shoulder')
        r_sh = kps.get('r_shoulder')
        if not (l_sh and r_sh and l_sh['conf'] > 0.5 and r_sh['conf'] > 0.5):
            return False

        h, w = frame_gray.shape
        # C7 = centro de hombros
        c7_y = (l_sh['y'] + r_sh['y']) / 2
        c7_x = (l_sh['x'] + r_sh['x']) / 2
        sh_width = abs(l_sh['x'] - r_sh['x'])

        # ROI centrado en C7, más ajustado verticalmente para evitar
        # detectar bordes del techo/pared
        y1 = max(0, int(c7_y - 50))
        y2 = min(h, int(c7_y + 50))
        x1 = max(0, int(min(l_sh['x'], r_sh['x']) - sh_width * 0.8))
        x2 = min(w, int(max(l_sh['x'], r_sh['x']) + sh_width * 0.8))

        roi = frame_gray[y1:y2, x1:x2]
        if roi.size == 0:
            return False

        # Preprocesamiento mejorado: blur + Canny adaptativos
        blurred = cv2.GaussianBlur(roi, (3, 3), 0)
        edges = cv2.Canny(blurred, 40, 130, apertureSize=3)

        # Detección de segmentos
        min_line_length = max(sh_width * 0.5, 50)
        lines = cv2.HoughLinesP(edges, 1, np.pi / 180,
                                threshold=35,
                                minLineLength=int(min_line_length),
                                maxLineGap=20)

        if lines is None:
            return False

        # ── Filtrar y puntuar líneas candidatas ──────────────────────────────
        best_score = 0.0
        best_y_global = None

        for line in lines:
            x_a, y_a, x_b, y_b = line[0]
            # 1. Horizontalidad estricta (<12°)
            angle = abs(math.degrees(math.atan2(y_b - y_a, x_b - x_a)))
            if not (angle < 12 or angle > 168):
                continue

            # 2. Longitud de la línea
            length = math.hypot(x_b - x_a, y_b - y_a)

            # 3. Proximidad a C7 en Y (la barra debe estar cerca de los hombros)
            line_global_y = (y_a + y_b) / 2 + y1
            dist_to_c7 = abs(line_global_y - c7_y)

            # Penalizar líneas lejanas a C7 (>35px = probablemente pared/techo)
            if dist_to_c7 > 45:
                continue

            # 4. La línea debe cruzar el centro X del cuerpo
            line_center_x = (x_a + x_b) / 2 + x1
            dist_to_center = abs(line_center_x - c7_x)
            if dist_to_center > sh_width * 1.5:
                continue

            # Score: longitud ponderada inversamente por distancia a C7
            proximity_factor = max(0, 1.0 - dist_to_c7 / 45)
            score = length * proximity_factor

            if score > best_score:
                best_score = score
                best_y_global = line_global_y

        if best_y_global is None:
            return False

        # ── Coherencia espacial ──────────────────────────────────────────────
        # Si hay una posición previa, la nueva debe estar cerca
        if self._rod_y_ema is not None:
            jump = abs(best_y_global - self._rod_y_ema)
            if jump > self.ROD_MAX_JUMP_PX:
                # Salto demasiado grande → probablemente un borde de pared
                return False

        # Actualizar EMA de posición
        if self._rod_y_ema is None:
            self._rod_y_ema = best_y_global
        else:
            self._rod_y_ema = 0.3 * best_y_global + 0.7 * self._rod_y_ema

        self._last_rod_y = best_y_global
        return True

    def verify_with_buffer(self, observed: bool) -> bool:
        """
        Buffer de histéresis:
          - Para ACTIVAR la barra: necesita 65% de frames positivos
          - Para DESACTIVAR: necesita que caiga por debajo del 25%
        Esto evita parpadeos cuando la barra se pierde 1-2 frames.
        """
        self.buffer.append(observed)
        if len(self.buffer) > self.BUFFER_SIZE:
            self.buffer.pop(0)

        # Warm-up: mínimo 5 frames antes de decidir
        if len(self.buffer) < 5:
            return observed

        ratio = sum(self.buffer) / len(self.buffer)

        if self._state:
            # Actualmente detectada: solo desactivar si la ratio cae mucho
            if ratio < self.DEACTIVATE_THRESHOLD:
                self._state = False
        else:
            # Actualmente no detectada: activar con consenso claro
            if ratio > self.ACTIVATE_THRESHOLD:
                self._state = True

        return self._state

    def reset(self):
        """Resetea todo el estado para un nuevo video."""
        self.buffer.clear()
        self._state = False
        self._last_rod_y = None
        self._rod_y_ema = None

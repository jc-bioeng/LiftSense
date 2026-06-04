"""
inclination_analyzer.py
Análisis de inclinación de segmentos corporales durante la sentadilla.
Calcula ángulos relativos a la vertical (perpendicular al suelo detectado):
  - Trunk angle (inclinación del tronco)
  - Shin angle (inclinación tibial / dorsiflexión)
  - Knee valgus (vista frontal)
  - Lateral lean (vista posterior)
  - Squat depth percentage

Todos los ángulos se expresan en grados.
"""

import math


class InclinationAnalyzer:
    """
    Motor de análisis angular para sentadilla.
    Requiere keypoints filtrados y opcionalmente la coordenada Y del suelo.
    """

    def __init__(self):
        self._prev_trunk_angle: float | None = None  # Para derivada temporal

    def analyze(self, kps: dict, view_type: str,
                ground_y_px: float | None = None) -> dict:
        """
        Calcula todas las métricas de inclinación disponibles según la vista.

        Args:
            kps: Keypoints filtrados
            view_type: 'frontal', 'posterior', 'lateral', 'unknown'
            ground_y_px: Coordenada Y del suelo detectado (opcional)

        Returns:
            dict con ángulos e indicadores
        """
        metrics = {}

        # ── Trunk Angle (todas las vistas, pero más preciso en lateral) ──────
        trunk = self._trunk_angle(kps)
        if trunk is not None:
            metrics['trunk_angle_deg'] = round(trunk, 1)

            # Derivada: detectar "good morning squat"
            if self._prev_trunk_angle is not None:
                delta = trunk - self._prev_trunk_angle
                metrics['trunk_angle_delta'] = round(delta, 2)
                # Si el tronco se inclina >5° entre frames, alerta
                if delta > 5.0:
                    metrics['trunk_warning'] = 'good_morning_risk'
            self._prev_trunk_angle = trunk

        # ── Shin Angle (lateral y frontal) ───────────────────────────────────
        shin = self._shin_angle(kps)
        if shin is not None:
            metrics['shin_angle_deg'] = round(shin, 1)

        # ── Knee Valgus (solo frontal/posterior) ─────────────────────────────
        if view_type in ('frontal', 'posterior'):
            valgus = self._knee_valgus(kps)
            if valgus is not None:
                metrics['knee_valgus_l_deg'] = round(valgus['left'], 1)
                metrics['knee_valgus_r_deg'] = round(valgus['right'], 1)
                metrics['knee_valgus_avg_deg'] = round(
                    (valgus['left'] + valgus['right']) / 2, 1)

        # ── Lateral Lean (posterior/frontal) ─────────────────────────────────
        if view_type in ('frontal', 'posterior'):
            lean = self._lateral_lean(kps)
            if lean is not None:
                metrics['lateral_lean_deg'] = round(lean, 1)

        # ── Hip Angle (ángulo hip-knee para profundidad) ─────────────────────
        hip_angle = self._hip_angle(kps)
        if hip_angle is not None:
            metrics['hip_angle_deg'] = round(hip_angle, 1)

        # ── Squat Depth (%) ──────────────────────────────────────────────────
        depth = self._squat_depth_pct(kps, ground_y_px)
        if depth is not None:
            metrics['squat_depth_pct'] = round(depth, 1)

        return metrics

    # ─── Trunk Angle ─────────────────────────────────────────────────────────

    def _trunk_angle(self, kps: dict) -> float | None:
        """
        Ángulo del vector mid_shoulder→mid_hip respecto a la vertical.
        0° = perfectamente erguido, 90° = horizontal.
        """
        mid_sh = self._midpoint(kps, 'l_shoulder', 'r_shoulder', min_conf=0.45)
        mid_hip = self._midpoint(kps, 'l_hip', 'r_hip', min_conf=0.45)

        if mid_sh is None or mid_hip is None:
            # Intentar con un solo lado
            for side in ['l', 'r']:
                sh = kps.get(f'{side}_shoulder')
                hi = kps.get(f'{side}_hip')
                if sh and hi and sh['conf'] > 0.45 and hi['conf'] > 0.45:
                    mid_sh = sh
                    mid_hip = hi
                    break

        if mid_sh is None or mid_hip is None:
            return None

        # Vector tronco: desde cadera hacia arriba (hombro)
        dx = mid_sh['x'] - mid_hip['x']
        dy = mid_sh['y'] - mid_hip['y']  # Negativo = hacia arriba en coords imagen

        # Ángulo respecto a la vertical (eje Y negativo = arriba)
        # La vertical es (0, -1). Usamos atan2 para obtener el ángulo.
        angle = math.degrees(math.atan2(abs(dx), abs(dy)))
        return angle

    # ─── Shin Angle ──────────────────────────────────────────────────────────

    def _shin_angle(self, kps: dict) -> float | None:
        """
        Ángulo promedio de la tibia (ankle→knee) respecto a la vertical.
        Indica dorsiflexión del tobillo.
        0° = tibia vertical, valores positivos = inclinación anterior.
        """
        angles = []
        for side in ['l', 'r']:
            ankle = kps.get(f'{side}_ankle')
            knee = kps.get(f'{side}_knee')
            if ankle and knee and ankle['conf'] > 0.5 and knee['conf'] > 0.5:
                dx = knee['x'] - ankle['x']
                dy = knee['y'] - ankle['y']  # Negativo (rodilla arriba del tobillo)
                angle = math.degrees(math.atan2(abs(dx), abs(dy)))
                angles.append(angle)

        if angles:
            return sum(angles) / len(angles)
        return None

    # ─── Knee Valgus ─────────────────────────────────────────────────────────

    def _knee_valgus(self, kps: dict) -> dict | None:
        """
        Desviación de la rodilla respecto a la línea cadera-tobillo (vista frontal).
        Valores positivos = valgus (rodilla se desplaza medialmente).
        Valores negativos = varus (rodilla se desplaza lateralmente).
        """
        result = {}
        for side, label in [('l', 'left'), ('r', 'right')]:
            hip = kps.get(f'{side}_hip')
            knee = kps.get(f'{side}_knee')
            ankle = kps.get(f'{side}_ankle')

            if not all(p and p['conf'] > 0.45 for p in [hip, knee, ankle]):
                return None  # Necesitamos ambos lados completos

            # Vector cadera→tobillo (línea "ideal")
            ideal_x = ankle['x'] - hip['x']
            ideal_y = ankle['y'] - hip['y']

            # Vector cadera→rodilla (posición real)
            actual_x = knee['x'] - hip['x']
            actual_y = knee['y'] - hip['y']

            # Ángulo entre los dos vectores
            angle_ideal = math.atan2(ideal_y, ideal_x)
            angle_actual = math.atan2(actual_y, actual_x)

            # La diferencia angular es el valgus
            valgus_rad = angle_actual - angle_ideal
            valgus_deg = math.degrees(valgus_rad)

            # Para el lado izquierdo, invertir el signo para que valgus sea siempre positivo
            if side == 'l':
                valgus_deg = -valgus_deg

            result[label] = valgus_deg

        if len(result) == 2:
            return result
        return None

    # ─── Lateral Lean ────────────────────────────────────────────────────────

    def _lateral_lean(self, kps: dict) -> float | None:
        """
        Diferencia angular entre caderas (vista frontal/posterior).
        0° = caderas niveladas. Positivo = inclinación a la derecha.
        """
        l_hip = kps.get('l_hip')
        r_hip = kps.get('r_hip')

        if not (l_hip and r_hip and l_hip['conf'] > 0.5 and r_hip['conf'] > 0.5):
            return None

        dx = r_hip['x'] - l_hip['x']
        dy = r_hip['y'] - l_hip['y']

        if abs(dx) < 1:
            return 0.0

        # Ángulo respecto a la horizontal
        angle = math.degrees(math.atan2(dy, dx))
        return angle  # Positivo = cadera derecha más baja

    # ─── Hip Angle ───────────────────────────────────────────────────────────

    def _hip_angle(self, kps: dict) -> float | None:
        """
        Ángulo en la articulación de la cadera (shoulder-hip-knee).
        180° = completamente extendido, <90° = squat profundo.
        """
        angles = []
        for side in ['l', 'r']:
            sh = kps.get(f'{side}_shoulder')
            hi = kps.get(f'{side}_hip')
            kn = kps.get(f'{side}_knee')

            if not all(p and p['conf'] > 0.4 for p in [sh, hi, kn]):
                continue

            # Vector hip→shoulder
            v1x = sh['x'] - hi['x']
            v1y = sh['y'] - hi['y']
            # Vector hip→knee
            v2x = kn['x'] - hi['x']
            v2y = kn['y'] - hi['y']

            dot = v1x * v2x + v1y * v2y
            mag1 = math.sqrt(v1x * v1x + v1y * v1y)
            mag2 = math.sqrt(v2x * v2x + v2y * v2y)

            if mag1 < 1e-5 or mag2 < 1e-5:
                continue

            cos_angle = max(-1, min(1, dot / (mag1 * mag2)))
            angle = math.degrees(math.acos(cos_angle))
            angles.append(angle)

        if angles:
            return sum(angles) / len(angles)
        return None

    # ─── Squat Depth ─────────────────────────────────────────────────────────

    def _squat_depth_pct(self, kps: dict, ground_y_px: float | None) -> float | None:
        """
        Profundidad de la sentadilla como porcentaje:
          0%  = de pie (cadera a máxima altura)
          100% = muslos paralelos al suelo (cadera al nivel de rodillas)
          >100% = profunda

        Se calcula como la relación entre la posición actual de la cadera
        y la posición de las rodillas, con referencia al suelo.
        """
        hip_kps = []
        knee_kps = []

        for side in ['l', 'r']:
            hi = kps.get(f'{side}_hip')
            kn = kps.get(f'{side}_knee')
            if hi and hi['conf'] > 0.4:
                hip_kps.append(hi)
            if kn and kn['conf'] > 0.4:
                knee_kps.append(kn)

        if not hip_kps or not knee_kps:
            return None

        avg_hip_y = sum(kp['y'] for kp in hip_kps) / len(hip_kps)
        avg_knee_y = sum(kp['y'] for kp in knee_kps) / len(knee_kps)

        # En coordenadas de imagen, Y crece hacia abajo.
        # hip_y < knee_y → de pie (cadera arriba de rodillas)
        # hip_y ≈ knee_y → paralelo (100%)
        # hip_y > knee_y → profundo (>100%)

        if ground_y_px is not None:
            # Referencia al suelo: distancia de la cadera al suelo normalizada
            standing_hip_range = ground_y_px - avg_hip_y
            knee_to_ground = ground_y_px - avg_knee_y

            if knee_to_ground < 10:
                return None  # Datos inconsistentes

            # 100% = hip al nivel de knee
            depth = ((avg_knee_y - avg_hip_y) / knee_to_ground)
            # Invertir: cuando hip_y < knee_y, la persona está de pie
            depth_pct = (1.0 - depth) * 100
            return max(0, depth_pct)

        else:
            # Sin suelo detectado, usar la diferencia hip-knee directamente
            diff = avg_knee_y - avg_hip_y  # Positivo = de pie
            # Normalizar a algo razonable (asumimos que muslo ≈ 40cm ~ 200px)
            if diff > 0:
                return max(0, min(100, (1 - diff / 200) * 100))
            else:
                return min(150, 100 + abs(diff) / 2)

    # ─── Helpers ─────────────────────────────────────────────────────────────

    def _midpoint(self, kps: dict, name_a: str, name_b: str,
                  min_conf: float = 0.5) -> dict | None:
        a = kps.get(name_a)
        b = kps.get(name_b)
        if a and b and a['conf'] > min_conf and b['conf'] > min_conf:
            return {
                'x': (a['x'] + b['x']) / 2,
                'y': (a['y'] + b['y']) / 2,
                'conf': min(a['conf'], b['conf']),
            }
        return None

    def reset(self):
        """Resetea el estado para un nuevo video."""
        self._prev_trunk_angle = None

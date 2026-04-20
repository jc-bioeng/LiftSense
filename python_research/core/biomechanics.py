"""
biomechanics.py
Cálculos biomecánicos puros:
  - Detección de vista (FRONTAL / POSTERIOR / LATERAL) con nariz + Z
  - Inferencia de barra con validación en eje X y oclusión posterior
  - Centro de Masa segmental
  - Proyección vertical y relación con mid-foot
"""

from enum import Enum


class ViewType(Enum):
    FRONTAL = "frontal"
    POSTERIOR = "posterior"
    LATERAL = "lateral"
    UNKNOWN = "unknown"


def _mid(p1: dict, p2: dict) -> dict:
    return {
        'x': (p1['x'] + p2['x']) / 2,
        'y': (p1['y'] + p2['y']) / 2,
        'z': (p1.get('z', 0) + p2.get('z', 0)) / 2,
        'conf': min(p1['conf'], p2['conf']),
    }


def _visible(kps: dict, name: str, threshold: float = 0.5) -> bool:
    p = kps.get(name)
    return p is not None and p['conf'] > threshold


class BiomechanicsEngine:

    def __init__(self):
        self._view_lock: ViewType | None = None  # View-Lock una vez detectada la vista dominante

    def calculate_metrics(self, kps: dict, frame_gray, px_to_cm_func=None, barbell_detector=None) -> dict:
        metrics: dict = {}

        # ── 1. Vista ─────────────────────────────────────────────────────────
        view = self._detect_view(kps)
        metrics['view_type'] = view.value
        is_lateral = view == ViewType.LATERAL

        # ── 2. Punto C7 (centro de hombros) ──────────────────────────────────
        c7 = None
        if _visible(kps, 'l_shoulder') and _visible(kps, 'r_shoulder'):
            c7 = _mid(kps['l_shoulder'], kps['r_shoulder'])
        elif _visible(kps, 'l_shoulder'):
            c7 = kps['l_shoulder']
        elif _visible(kps, 'r_shoulder'):
            c7 = kps['r_shoulder']

        if c7:
            metrics['c7_x'] = c7['x']
            metrics['c7_y'] = c7['y']

        # ── 3. Inferencia de barra ────────────────────────────────────────────
        has_barbell = self._infer_barbell(kps, view, frame_gray, barbell_detector)
        metrics['has_barbell'] = has_barbell

        if has_barbell and c7:
            metrics['bar_x'] = c7['x']
            metrics['bar_y'] = c7['y']

        # ── 4. Centro de Masa ─────────────────────────────────────────────────
        com = self._estimate_center_of_mass(kps)
        if com:
            metrics['com_x'] = com['x']
            metrics['com_y'] = com['y']

        # ── 5. Relación Barra–Mid-foot ────────────────────────────────────────
        foot_xs = []
        for fp in ['l_heel', 'l_foot_index', 'r_heel', 'r_foot_index']:
            if _visible(kps, fp):
                foot_xs.append(kps[fp]['x'])

        if foot_xs:
            mid_foot_x = sum(foot_xs) / len(foot_xs)
            metrics['mid_foot_x'] = mid_foot_x

            if has_barbell and c7 and px_to_cm_func:
                diff_px = c7['x'] - mid_foot_x
                metrics['bar_to_midfoot_cm'] = px_to_cm_func(diff_px)
                metrics['bar_to_midfoot_px'] = diff_px

        return metrics

    # ── Detección de Vista ───────────────────────────────────────────────────

    def _detect_view(self, kps: dict) -> ViewType:
        """
        Determina la orientación dominante del usuario.
        Usa:
          a) Visibilidad de rasgos faciales (nariz, ojos) → distingue frontal vs posterior.
          b) Ancho de hombros vs largo de tronco       → distingue lateral.
        """
        if self._view_lock is not None:
            return self._view_lock

        # — Vista Lateral —
        # Si un hombro o cadera no es visible, o la distancia entre hombros es minúscula respecto al tronco
        l_sh, r_sh = kps.get('l_shoulder'), kps.get('r_shoulder')
        l_hip      = kps.get('l_hip')
        
        if l_sh and r_sh and l_hip:
            sh_width = abs(l_sh['x'] - r_sh['x'])
            trunk_h  = abs(l_sh['y'] - l_hip['y'])
            # En lateral puro, los hombros están casi superpuestos (ratio < 0.35)
            if sh_width < trunk_h * 0.35:
                return ViewType.LATERAL
        
        # Si perdemos un hombro/cadera pero el otro es fuerte, suele ser lateral
        sh_vis_count = sum(1 for n in ['l_shoulder', 'r_shoulder'] if _visible(kps, n))
        if sh_vis_count == 1:
            return ViewType.LATERAL

        # — Frontal vs Posterior —
        # La nariz o ambos ojos deben ser visibles con confianza clara (>0.55)
        face_points = ['nose', 'l_eye', 'r_eye']
        face_conf = max((kps.get(n, {}).get('conf', 0) for n in face_points), default=0)
        face_visible = face_conf > 0.55

        # Refuerzo: en MediaPipe, Z nariz < Z hombro → cara apunta a la cámara (frontal).
        nose  = kps.get('nose')
        sh_l  = kps.get('l_shoulder')
        z_frontal = False
        if nose and sh_l and nose['conf'] > 0.45:
            z_frontal = nose.get('z', 0) < sh_l.get('z', 0)

        # Solo declarar FRONTAL si ambas señales coinciden, o la cara es muy clara
        if face_visible and z_frontal:
            return ViewType.FRONTAL
        elif face_visible and face_conf > 0.75:
            return ViewType.FRONTAL   # cara muy prominente → frontal inequívoco
        elif _visible(kps, 'l_shoulder') and _visible(kps, 'r_shoulder'):
            return ViewType.POSTERIOR

        return ViewType.UNKNOWN

    def set_view_lock(self, view: ViewType):
        """Fija la vista para el resto del video (se llama desde el pipeline)."""
        if self._view_lock is None and view != ViewType.UNKNOWN:
            self._view_lock = view
            print(f"[Vista] Bloqueada como: {view.value.upper()}")

    def reset_view_lock(self):
        self._view_lock = None

    # ── Inferencia de Barra ──────────────────────────────────────────────────

    def _infer_barbell(self, kps: dict, view: ViewType, frame_gray=None, barbell_detector=None) -> bool:
        """
        Detecta si el usuario porta una barra según la vista:
        Usa señales de Pose + Visión Computacional (Hough Lines).
        """
        conf = 0.60
        cv_signal = False
        
        # ── Señal de Pose ────────────────────────────────────────────────────
        pose_signal = False
        if view == ViewType.POSTERIOR:
            pose_signal = self._barbell_by_elbow_flare(kps, conf)
        elif view == ViewType.LATERAL:
            # En lateral, la pose es ambigua (manos arriba para equilibrio).
            # Desactivamos la sospecha por pose para evitar falsos positivos en sentadilla libre.
            pose_signal = False
            cv_signal = False # El PlateDetector en el loop principal se encargará
        
        # ── Integración Final ────────────────────────────────────────────────
        # Cambio Crítico: Exigimos evidencia física (CV) para confirmar la barra.
        # La pose_signal puede usarse internamente, pero queremos asegurar que se VE la barra.
        obs = cv_signal
        
        if barbell_detector:
            return barbell_detector.verify_with_buffer(obs)
        return obs

    def _barbell_by_elbow_flare(self, kps: dict, conf: float) -> bool:
        """
        Para vista posterior: si los codos sobresalen más que los hombros (Elbow Flare),
        el usuario casi certainly tiene una barra apoyada en C7.
        """
        el_l = kps.get('l_elbow')
        el_r = kps.get('r_elbow')
        sh_l = kps.get('l_shoulder')
        sh_r = kps.get('r_shoulder')

        if not (el_l and el_r and sh_l and sh_r):
            return False
        if el_l['conf'] < conf or el_r['conf'] < conf:
            return False

        # Los dos codos deben estar más afuera que los hombros en X
        left_flare  = el_l['x'] < sh_l['x']   # Codo izquierdo sobresale a la izquierda
        right_flare = el_r['x'] > sh_r['x']   # Codo derecho sobresale a la derecha
        return left_flare and right_flare

    # ── Centro de Masa ───────────────────────────────────────────────────────

    def _estimate_center_of_mass(self, kps: dict) -> dict | None:
        """
        Método Segmental de Dempster simplificado.
        Si los brazos no son visibles, simplemente no se incluyen en la ponderación.
        """
        points, weights = [], []

        def bi(a, b, w):
            """Añade el punto medio de un segmento bilateral si es visible."""
            for prefix in [('l_', 'r_')]:
                la, ra = 'l_' + a, 'r_' + a
                lb, rb = 'l_' + b, 'r_' + b
                if _visible(kps, la) and _visible(kps, ra) and _visible(kps, lb) and _visible(kps, rb):
                    mx = (kps[la]['x'] + kps[ra]['x'] + kps[lb]['x'] + kps[rb]['x']) / 4
                    my = (kps[la]['y'] + kps[ra]['y'] + kps[lb]['y'] + kps[rb]['y']) / 4
                    points.append((mx, my))
                    weights.append(w)
                    return True
            return False

        # Pesos relativos basados en las tablas de Dempster (Normalización de Winter):
        # Tronco: ~55%, Muslos: ~20% total, Piernas: ~12% total.
        bi('shoulder', 'hip', 0.55)   # Tronco (Thorax+Abdomen+Pelvis)
        bi('hip', 'knee', 0.20)       # Muslos (Masa muscular principal)
        bi('knee', 'ankle', 0.12)     # Piernas (Pantorrillas)

        # Brazos: opcionales
        for side in ['l', 'r']:
            sh = kps.get(f'{side}_shoulder')
            el = kps.get(f'{side}_elbow')
            if sh and el and sh['conf'] > 0.5 and el['conf'] > 0.5:
                points.append(((sh['x'] + el['x']) / 2, (sh['y'] + el['y']) / 2))
                weights.append(0.065)

        if not points:
            return None

        total_w = sum(weights)
        return {
            'x': sum(p[0] * w for p, w in zip(points, weights)) / total_w,
            'y': sum(p[1] * w for p, w in zip(points, weights)) / total_w,
        }

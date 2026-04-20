"""
camera_calibration.py
Convierte píxeles a centímetros reales.
También captura la "Firma Biométrica" (BodyProfile) del usuario
usando una toma frontal, y la persiste en JSON.
"""

import json
import math
import os


def _euclidean_px(kps, name_a, name_b, conf_threshold=0.6):
    """Distancia en píxeles entre dos landmarks si ambos son visibles."""
    a = kps.get(name_a)
    b = kps.get(name_b)
    if a and b and a['conf'] > conf_threshold and b['conf'] > conf_threshold:
        return math.hypot(a['x'] - b['x'], a['y'] - b['y'])
    return None


class BodyProfile:
    """
    Contiene las medidas antropométricas en píxeles escaladas a CM.
    Se usa como "Ground Truth" anatómico para rechazar hallmarks imposibles
    en frames posteriores.
    """

    def __init__(self):
        self.segments_px: dict[str, float] = {}   # Longitudes en píxeles (frame de calibración)
        self.segments_cm: dict[str, float] = {}   # Longitudes en CM reales
        self.cm_per_pixel: float | None = None
        self.is_ready: bool = False

    # --- Mediciones en píxeles ---

    SEGMENT_PAIRS = {
        'torso':       ('l_shoulder', 'l_hip'),
        'femur_l':     ('l_hip', 'l_knee'),
        'femur_r':     ('r_hip', 'r_knee'),
        'tibia_l':     ('l_knee', 'l_ankle'),
        'tibia_r':     ('r_knee', 'r_ankle'),
        'shoulder_width': ('l_shoulder', 'r_shoulder'),
        'hip_width':   ('l_hip', 'r_hip'),
    }

    def measure_from_keypoints(self, kps: dict, cm_per_pixel: float) -> bool:
        """
        Intenta medir todos los segmentos a partir de los keypoints del frame actual.
        Retorna True si se pudo completar la firma biométrica.
        """
        measured = {}
        for name, (a, b) in self.SEGMENT_PAIRS.items():
            dist_px = _euclidean_px(kps, a, b)
            if dist_px is not None and dist_px > 10:
                measured[name] = dist_px
            else:
                return False  # Vista incompleta, esperamos un mejor frame

        self.segments_px = measured
        self.cm_per_pixel = cm_per_pixel
        self.segments_cm = {k: v * cm_per_pixel for k, v in measured.items()}
        self.is_ready = True
        return True

    def validate_keypoints(self, kps: dict, tolerance: float = 0.30) -> bool:
        """
        Compara los segmentos actuales del frame contra la firma biométrica guardada.
        Si algún segmento se desvía más del `tolerance` (30%), el frame es imposible
        anatómicamente → rechazar (False).
        """
        if not self.is_ready:
            return True  # Sin firma aún, dejar pasar

        for name, (a, b) in self.SEGMENT_PAIRS.items():
            expected_px = self.segments_px.get(name)
            if expected_px is None:
                continue
            current_px = _euclidean_px(kps, a, b, conf_threshold=0.4)
            if current_px is None:
                continue  # No visible → no podemos juzgar, dejar pasar ese segmento
            diff_ratio = (current_px - expected_px) / expected_px
            
            # Perspectiva (Foreshortening): Permitimos encogimiento casi total (90%)
            # Ghosting: Permitimos estiramiento de hasta el 100% (el doble) por dinámica
            if diff_ratio < -0.90 or diff_ratio > tolerance:
                return False  # Solo rechazamos si la distorsión es absurda

        return True  # Todo en orden

    def save(self, path: str):
        data = {
            'segments_cm': self.segments_cm,
            'segments_px': self.segments_px,
            'cm_per_pixel': self.cm_per_pixel,
        }
        with open(path, 'w') as f:
            json.dump(data, f, indent=2)
        print(f"[Perfil] Guardado en {path}")

    def load(self, path: str) -> bool:
        if not os.path.exists(path):
            return False
        with open(path) as f:
            data = json.load(f)
        self.segments_cm = data.get('segments_cm', {})
        self.segments_px = data.get('segments_px', {})
        self.cm_per_pixel = data.get('cm_per_pixel')
        self.is_ready = bool(self.segments_cm)
        return self.is_ready

    def init_local_segments(self, kps: dict):
        """
        Captura las longitudes en píxeles del video actual al inicio.
        Esto asegura que el esqueleto esté centrado en las articulaciones visuales.
        """
        temp_segments = {}
        for name, (a, b) in self.SEGMENT_PAIRS.items():
            dist = _euclidean_px(kps, a, b, conf_threshold=0.5)
            if dist: temp_segments[name] = dist
        
        if len(temp_segments) >= 3:
            self.segments_px = temp_segments
            print(f"[Anatomía] Sincronización local completada: {list(temp_segments.keys())}")
            return True
        return False

    def rectify_lateral(self, kps: dict) -> dict:
        """
        Usa las longitudes 'locales' (bloqueadas al inicio del video)
        para mantener la estabilidad sin desplazar los puntos de su centro visual.
        """
        if not self.is_ready:
            return kps
        
        new_kps = {k: v.copy() for k, v in kps.items()}
        l_sh, r_sh = new_kps.get('l_shoulder'), new_kps.get('r_shoulder')
        master_sh = None
        if l_sh and r_sh: master_sh = l_sh if l_sh['conf'] >= r_sh['conf'] else r_sh
        elif l_sh: master_sh = l_sh
        elif r_sh: master_sh = r_sh
        
        if not master_sh: return kps

        for side in ['l', 'r']:
            # 1. Torso
            hi = new_kps.get(f'{side}_hip')
            if hi and 'torso' in self.segments_px:
                hi['x'], hi['y'] = self._project_segment(master_sh, hi, self.segments_px['torso'])
            
            # 2. Tibia (Anclada al Tobillo)
            kn = new_kps.get(f'{side}_knee')
            an = new_kps.get(f'{side}_ankle')
            seg_tibia = f'tibia_{side}'
            if an and kn and seg_tibia in self.segments_px:
                kn['x'], kn['y'] = self._project_segment(an, kn, self.segments_px[seg_tibia])

        return new_kps

    def _project_segment(self, p_start: dict, p_end: dict, target_px: float):
        """Proyecta p_end a una distancia target_px desde p_start manteniendo el ángulo."""
        dx = p_end['x'] - p_start['x']
        dy = p_end['y'] - p_start['y']
        current_dist = math.sqrt(dx*dx + dy*dy)
        if current_dist < 1e-5: return p_end['x'], p_end['y']
        
        scale = target_px / current_dist
        new_x = p_start['x'] + dx * scale
        new_y = p_start['y'] + dy * scale
        return new_x, new_y


class CameraCalibrator:
    """
    Establece la conversión entre píxeles y centímetros usando la altura física del usuario.
    Después de calibrar, delega la firma biométrica a BodyProfile.
    """

    def __init__(self, physical_height_cm: float):
        self.physical_height_cm = physical_height_cm
        self.cm_per_pixel: float | None = None
        self.calibrated: bool = False
        self.profile = BodyProfile()

    def try_calibrate(self, kps: dict) -> bool:
        """
        Intenta calibrar usando la distancia vertical nariz→talón.
        Retorna True en el primer frame que logra una calibración válida.
        """
        nose = kps.get('nose')
        heel_l = kps.get('l_heel')
        heel_r = kps.get('r_heel')

        # Elige el talón más visible
        heel = None
        if heel_l and heel_l['conf'] > 0.65:
            heel = heel_l
        elif heel_r and heel_r['conf'] > 0.65:
            heel = heel_r

        if nose and heel and nose['conf'] > 0.70:
            pixel_height = abs(heel['y'] - nose['y'])
            if pixel_height > 150:
                self.cm_per_pixel = self.physical_height_cm / pixel_height
                self.calibrated = True
                print(f"[Calibrador] Altura detectada: {pixel_height:.1f} px | Ratio: {self.cm_per_pixel:.4f} cm/px")
                return True
        return False

    def px_to_cm(self, px_distance: float) -> float | None:
        if self.cm_per_pixel is None:
            return None
        return px_distance * self.cm_per_pixel

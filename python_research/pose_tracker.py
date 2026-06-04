"""
pose_tracker.py — Orquestador Principal LiftSense v2.0
Modos:
  calibrate        → extrae antropometría frontal y guarda user_profile.json
  analyze          → carga el perfil, valida anatómicamente y analiza la sentadilla
  export_training  → analiza + genera JSONL estructurado para ML
"""

import cv2
import math
import pandas as pd
import argparse
import os

from core.tracker import MediaPipePoseTracker
from core.filters import PoseFilterSession
from core.camera_calibration import CameraCalibrator, BodyProfile
from core.biomechanics import BiomechanicsEngine, ViewType
from core.plate_detector import PlateDetector
from core.barbell_detector import BarbellDetector
from core.ground_detector import GroundDetector
from core.inclination_analyzer import InclinationAnalyzer
from core.data_exporter import TrainingDataExporter

# ─── Definición de colores ────────────────────────────────────────────────────
CLR_KP       = (0, 220, 80)      # keypoints  → verde
CLR_BONE     = (200, 200, 200)   # huesos     → gris
CLR_COM      = (0, 230, 230)     # CoM        → cian
CLR_BAR      = (255, 80, 0)      # barra C7   → naranja
CLR_PLUMB    = (80, 80, 255)     # plumb line → azul
CLR_FOOT     = (255, 0, 200)     # platos / pie→ magenta
CLR_GROUND   = (0, 180, 60)      # suelo      → verde oscuro
CLR_ANGLE    = (255, 200, 0)     # ángulos    → amarillo

SKELETON_CONNECTIONS = [
    ('l_shoulder', 'r_shoulder'),
    ('l_shoulder', 'l_elbow'), ('l_elbow', 'l_wrist'),
    ('r_shoulder', 'r_elbow'), ('r_elbow', 'r_wrist'),
    ('l_shoulder', 'l_hip'), ('r_shoulder', 'r_hip'),
    ('l_hip', 'r_hip'),
    ('l_hip', 'l_knee'), ('l_knee', 'l_ankle'),
    ('r_hip', 'r_knee'), ('r_knee', 'r_ankle'),
    ('l_ankle', 'l_heel'), ('l_heel', 'l_foot_index'), ('l_ankle', 'l_foot_index'),
    ('r_ankle', 'r_heel'), ('r_heel', 'r_foot_index'), ('r_ankle', 'r_foot_index'),
]


# ─── Dibujado ────────────────────────────────────────────────────────────────

def _visible(kps: dict, name: str, threshold: float = 0.5) -> bool:
    p = kps.get(name)
    return p is not None and p['conf'] > threshold


def draw_skeleton(frame, kps: dict, current_view: str = 'unknown'):
    is_lat = current_view == 'lateral'
    draw_conf = 0.45  # Relajado para permitir ver hombros y nariz parcialmente ocluidos
    leg_strict_conf = 0.65 if is_lat else 0.45
    
    # En lateral, evitamos el "pie fantasma".
    # Solo dibujamos la pierna si la cadena (Hip-Knee-Ankle) es sólida.
    leg_visible = {'l': True, 'r': True}
    if is_lat:
        for side in ['l', 'r']:
            chain = [f'{side}_hip', f'{side}_knee', f'{side}_ankle']
            if not all(kps.get(p, {}).get('conf', 0) > leg_strict_conf for p in chain):
                leg_visible[side] = False

    for p1, p2 in SKELETON_CONNECTIONS:
        if p1 in kps and p2 in kps:
            # Filtro de segmento: si pertenece a una pierna "invisible", saltar
            side_p1 = p1[0] if p1[1] == '_' else None
            if is_lat and side_p1 in leg_visible and not leg_visible[side_p1]:
                # Solo bloqueamos segmentos de pierna (hip, knee, ankle, heel, foot_index)
                if any(x in p1 or x in p2 for x in ['knee', 'ankle', 'heel', 'foot_index']):
                    continue

            if kps[p1]['conf'] > draw_conf and kps[p2]['conf'] > draw_conf:
                cv2.line(frame,
                         (int(kps[p1]['x']), int(kps[p1]['y'])),
                         (int(kps[p2]['x']), int(kps[p2]['y'])),
                         CLR_BONE, 2)
    for name, kp in kps.items():
        if name == 'nose': continue
        side = name[0] if name[1] == '_' else None
        if is_lat and side in leg_visible and not leg_visible[side]:
             if any(x in name for x in ['knee', 'ankle', 'heel', 'foot_index']):
                 continue
                 
        if kp['conf'] > draw_conf:
            cv2.circle(frame, (int(kp['x']), int(kp['y'])), 5, CLR_KP, -1)


def draw_ground_line(frame, ground_y_px: float | None, method: str):
    """Dibuja la línea del suelo detectado."""
    if ground_y_px is None:
        return
    h, w = frame.shape[:2]
    y = int(ground_y_px)
    if 0 < y < h:
        # Línea punteada verde
        dash_len = 15
        for x_start in range(0, w, dash_len * 2):
            x_end = min(x_start + dash_len, w)
            cv2.line(frame, (x_start, y), (x_end, y), CLR_GROUND, 2)
        # Etiqueta
        label = f"SUELO ({method})"
        cv2.putText(frame, label, (w - 200, y - 8),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.45, CLR_GROUND, 1)


def draw_angle_arc(frame, kps: dict, trunk_angle: float | None,
                   shin_angle: float | None):
    """Dibuja arcos de ángulo sobre el esqueleto."""
    # ── Trunk angle (mid_shoulder → mid_hip) ─────────────────────────────
    if trunk_angle is not None:
        sh_pts = []
        hi_pts = []
        for side in ['l', 'r']:
            sh = kps.get(f'{side}_shoulder')
            hi = kps.get(f'{side}_hip')
            if sh and sh['conf'] > 0.4:
                sh_pts.append(sh)
            if hi and hi['conf'] > 0.4:
                hi_pts.append(hi)
        
        if sh_pts and hi_pts:
            mid_sh_x = sum(p['x'] for p in sh_pts) / len(sh_pts)
            mid_sh_y = sum(p['y'] for p in sh_pts) / len(sh_pts)
            mid_hi_x = sum(p['x'] for p in hi_pts) / len(hi_pts)
            mid_hi_y = sum(p['y'] for p in hi_pts) / len(hi_pts)

            # Dibujar arco indicando el ángulo del tronco
            center = (int(mid_hi_x), int(mid_hi_y))
            radius = 35
            # Ángulo del vector tronco (0° = arriba)
            angle_rad = math.atan2(mid_sh_x - mid_hi_x, mid_hi_y - mid_sh_y)
            start_angle = -90  # Vertical hacia arriba
            end_angle = int(-90 + trunk_angle * (1 if mid_sh_x > mid_hi_x else -1))
            
            cv2.ellipse(frame, center, (radius, radius),
                       0, min(start_angle, end_angle), max(start_angle, end_angle),
                       CLR_ANGLE, 2)
            
            # Label del ángulo
            label_x = int(mid_hi_x + 40)
            label_y = int(mid_hi_y - 10)
            cv2.putText(frame, f"{trunk_angle:.0f} deg", (label_x, label_y),
                       cv2.FONT_HERSHEY_SIMPLEX, 0.5, CLR_ANGLE, 2)

    # ── Shin angle (ankle → knee) ────────────────────────────────────────
    if shin_angle is not None:
        for side in ['l', 'r']:
            ankle = kps.get(f'{side}_ankle')
            knee = kps.get(f'{side}_knee')
            if ankle and knee and ankle['conf'] > 0.5 and knee['conf'] > 0.5:
                center = (int(ankle['x']), int(ankle['y']))
                cv2.putText(frame, f"T:{shin_angle:.0f}", 
                           (center[0] + 10, center[1] - 5),
                           cv2.FONT_HERSHEY_SIMPLEX, 0.4, (180, 220, 255), 1)
                break  # Solo dibujar uno


def draw_hud(frame, metrics: dict, incl_metrics: dict, ground_data: dict,
             frame_idx: int, calib_ok: bool, mode: str):
    h, w = frame.shape[:2]
    panel_w = 280
    
    # Calcular altura necesaria del panel
    num_rows = 5  # Base rows
    if incl_metrics.get('trunk_angle_deg') is not None:
        num_rows += 1
    if incl_metrics.get('shin_angle_deg') is not None:
        num_rows += 1
    if incl_metrics.get('squat_depth_pct') is not None:
        num_rows += 1
    if incl_metrics.get('hip_angle_deg') is not None:
        num_rows += 1
    if incl_metrics.get('knee_valgus_avg_deg') is not None:
        num_rows += 1
    if ground_data.get('ground_y_px') is not None:
        num_rows += 1
    
    panel_h = max(160, 22 + num_rows * 28 + 10)
    
    overlay = frame.copy()
    cv2.rectangle(overlay, (0, 0), (panel_w, panel_h), (0, 0, 0), -1)
    cv2.addWeighted(overlay, 0.50, frame, 0.50, 0, frame)

    row = [0]  # Mutable counter

    def txt(text, color=(220, 220, 220)):
        cv2.putText(frame, text, (10, 22 + row[0] * 28),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.58, color, 2)
        row[0] += 1

    txt(f"Frame {frame_idx}  [{mode.upper()}]")
    txt(f"Calib: {'OK' if calib_ok else 'Esperar...'}",
        (0, 200, 80) if calib_ok else (0, 80, 255))
    txt(f"Vista: {metrics.get('view_type', '?').upper()}", (200, 200, 0))
    bar_str = "Detectada" if metrics.get('has_barbell') else "No detectada"
    txt(f"Barra: {bar_str}", CLR_BAR if metrics.get('has_barbell') else (80, 80, 255))

    if 'bar_to_midfoot_cm' in metrics:
        txt(f"Bar-Midfoot: {metrics['bar_to_midfoot_cm']:.1f} cm", (255, 0, 200))

    # ── Ground info ──────────────────────────────────────────────────────
    if ground_data.get('ground_y_px') is not None:
        method = ground_data.get('ground_method', '?')
        txt(f"Suelo: {method} (Y={ground_data['ground_y_px']:.0f})", CLR_GROUND)

    # ── Inclination metrics ──────────────────────────────────────────────
    if incl_metrics.get('trunk_angle_deg') is not None:
        angle = incl_metrics['trunk_angle_deg']
        color = CLR_ANGLE if angle < 45 else (0, 80, 255)
        warning = ""
        if incl_metrics.get('trunk_warning') == 'good_morning_risk':
            warning = " ⚠"
            color = (0, 0, 255)
        txt(f"Tronco: {angle:.1f} deg{warning}", color)

    if incl_metrics.get('shin_angle_deg') is not None:
        txt(f"Tibia: {incl_metrics['shin_angle_deg']:.1f} deg", (180, 220, 255))

    if incl_metrics.get('hip_angle_deg') is not None:
        txt(f"Cadera: {incl_metrics['hip_angle_deg']:.1f} deg", (220, 180, 255))

    if incl_metrics.get('squat_depth_pct') is not None:
        depth = incl_metrics['squat_depth_pct']
        if depth < 50:
            dc = (200, 200, 200)
        elif depth < 90:
            dc = (0, 200, 200)
        else:
            dc = (0, 255, 0)
        txt(f"Profundidad: {depth:.0f}%", dc)

    if incl_metrics.get('knee_valgus_avg_deg') is not None:
        valgus = incl_metrics['knee_valgus_avg_deg']
        vc = (0, 200, 80) if abs(valgus) < 8 else (0, 80, 255)
        txt(f"Valgus: {valgus:.1f} deg", vc)

    # CoM
    if 'com_x' in metrics:
        cx, cy = int(metrics['com_x']), int(metrics['com_y'])
        cv2.circle(frame, (cx, cy), 8, CLR_COM, -1)
        cv2.putText(frame, "CoM", (cx + 10, cy),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.55, CLR_COM, 2)

    # Barra + plumb line + mid-foot
    if metrics.get('has_barbell') and 'bar_x' in metrics:
        bx, by = int(metrics['bar_x']), int(metrics['bar_y'])
        cv2.circle(frame, (bx, by), 9, CLR_BAR, -1)

        if 'mid_foot_x' in metrics:
            mfx = int(metrics['mid_foot_x'])
            bottom = min(h - 10, by + 600)
            cv2.line(frame, (bx, by), (bx, bottom), CLR_PLUMB, 2)
            cv2.line(frame, (bx, bottom), (mfx, bottom), CLR_FOOT, 2)


# ─── Modo: calibrate ─────────────────────────────────────────────────────────

def run_calibrate(input_path: str, profile_path: str, height_cm: float):
    """
    Analiza el video frontal, extrae la firma antropométrica y la guarda en JSON.
    Necesita que el usuario esté erguido y visible al frente.
    """
    print("\n=== MODO CALIBRACIÓN FRONTAL ===")
    tracker = MediaPipePoseTracker()
    filter_session = PoseFilterSession()
    calibrator = CameraCalibrator(height_cm)
    biomech = BiomechanicsEngine()
    profile = BodyProfile()

    cap = cv2.VideoCapture(input_path)
    if not cap.isOpened():
        print(f"Error abriendo: {input_path}")
        return

    width  = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    fps    = cap.get(cv2.CAP_PROP_FPS)

    # Generar video de calibración con anotaciones
    out_path = os.path.splitext(input_path)[0] + "_calibration.mp4"
    out = cv2.VideoWriter(out_path, cv2.VideoWriter_fourcc(*'mp4v'), fps, (width, height))

    stable_frames = 0
    FRAMES_NEEDED = 10  # Necesitamos 10 frames estables consecutivos para confiar
    frame_idx = 0

    while cap.isOpened():
        ret, frame = cap.read()
        if not ret:
            break

        timestamp_ms = int(cap.get(cv2.CAP_PROP_POS_MSEC))
        image_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        pose_result = tracker.process_frame(image_rgb)

        if pose_result.keypoints:
            filtered = filter_session.process(timestamp_ms, pose_result.keypoints)
            view = biomech._detect_view(filtered)

            # Solo calibramos en vista frontal
            if view == ViewType.FRONTAL:
                if not calibrator.calibrated:
                    calibrator.try_calibrate(filtered)

                if calibrator.calibrated and not profile.is_ready:
                    ok = profile.measure_from_keypoints(filtered, calibrator.cm_per_pixel)
                    if ok:
                        stable_frames += 1
                        if stable_frames >= FRAMES_NEEDED:
                            print(f"[Calibración] Firma biométrica obtenida en frame {frame_idx}.")
                    else:
                        stable_frames = 0

            draw_skeleton(frame, filtered)

            status = "BUSCANDO..."
            color = (0, 80, 255)
            if profile.is_ready:
                status = f"OK en {FRAMES_NEEDED} frames estables"
                color = (0, 200, 80)
            elif calibrator.calibrated:
                status = f"Distancia calibrada. Midiendo... ({stable_frames}/{FRAMES_NEEDED})"

            cv2.putText(frame, f"Vista: {view.value.upper()}", (10, 30),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.7, (200, 200, 0), 2)
            cv2.putText(frame, status, (10, 62),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.65, color, 2)

        out.write(frame)
        frame_idx += 1

    cap.release()
    out.release()
    tracker.close()

    if profile.is_ready:
        profile.save(profile_path)
        print(f"[OK] Perfil guardado en: {profile_path}")
        print("Segmentos medidos (cm):")
        for k, v in profile.segments_cm.items():
            print(f"  {k:20s}: {v:.1f} cm")
        print(f"\nVideo de calibración: {out_path}")
    else:
        print("[FALLO] No se pudo obtener la firma biometrica. Asegurate que el usuario este de frente y erguido.")


# ─── Modo: analyze / export_training ─────────────────────────────────────────

def run_analyze(input_path: str, output_video_path: str, output_csv_path: str,
                height_cm: float, profile_path: str | None, forced_view: str | None = None,
                export_training: bool = False):
    print(f"\n=== MODO {'EXPORT TRAINING' if export_training else 'ANÁLISIS'} ===")
    tracker = MediaPipePoseTracker()
    filter_session = PoseFilterSession()
    calibrator = CameraCalibrator(height_cm)
    biomech = BiomechanicsEngine()
    plate_detector = PlateDetector()
    barbell_detector = BarbellDetector()
    ground_detector = GroundDetector()
    inclination = InclinationAnalyzer()
    profile = BodyProfile()

    # Training exporter (solo si se solicita)
    training_exporter = None
    if export_training:
        training_path = os.path.splitext(input_path)[0] + "_training.jsonl"
        training_exporter = TrainingDataExporter(training_path)

    if profile_path and profile.load(profile_path):
        calibrator.cm_per_pixel = profile.cm_per_pixel
        calibrator.calibrated = True
        print(f"[Perfil] Cargado desde {profile_path}")
    else:
        print("[Perfil] Sin perfil cargado. La validacion anatomica estara inactiva.")

    # Forzar vista si se especifica via argumento
    if forced_view:
        view_map = {'frontal': ViewType.FRONTAL, 'posterior': ViewType.POSTERIOR, 'lateral': ViewType.LATERAL}
        if forced_view in view_map:
            biomech.set_view_lock(view_map[forced_view])
            print(f"[Vista] Forzada a: {forced_view.upper()}")

    cap = cv2.VideoCapture(input_path)
    if not cap.isOpened():
        print(f"Error abriendo: {input_path}")
        return

    width  = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    fps    = cap.get(cv2.CAP_PROP_FPS)

    out = cv2.VideoWriter(output_video_path, cv2.VideoWriter_fourcc(*'mp4v'), fps, (width, height))
    data_rows = []
    frame_idx = 0

    # View-lock: acumular votos en los primeros N frames
    view_votes = {v: 0 for v in ViewType}
    VIEW_LOCK_AFTER = 90  # 3 segundos a 30 FPS para decidir vista dominante
    VIEW_LOCK_MAJORITY = 0.55  # El 55% de votos debe ir a la misma vista

    # Persistencia temporal (para huecos en el fondo de la sentadilla)
    last_valid_filtered = None
    hold_counter = 0
    MAX_HOLD_FRAMES = 20  # Mantener la pose hasta por 0.6s si se pierde

    # Sincronización local para este video
    local_synched = False

    print(f"Procesando: {input_path}  ({width}x{height} @{fps:.1f} FPS)")

    while cap.isOpened():
        ret, frame = cap.read()
        if not ret:
            break

        timestamp_ms = int(cap.get(cv2.CAP_PROP_POS_MSEC))
        image_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        pose_result = tracker.process_frame(image_rgb)

        row_data = {'frame': frame_idx, 'time_ms': timestamp_ms}
        incl_metrics = {}
        ground_data = {'ground_y_px': None, 'ground_method': 'none', 'ground_confidence': 0.0}

        if pose_result.keypoints:
            # ── Validar que hay una persona real ────────────────────────────
            raw_kps = pose_result.keypoints
            # Muy permisivo: con que haya confianza en cualquier punto clave base
            has_body = any(raw_kps.get(pt, {}).get('conf', 0) > 0.15 for pt in ['l_shoulder', 'r_shoulder', 'l_hip', 'r_hip', 'l_knee', 'r_knee'])

            if not has_body:
                out.write(frame)
                frame_idx += 1
                data_rows.append(row_data)
                continue

            # ── Filtro One-Euro ──────────────────────────────────────────────
            filtered = filter_session.process(timestamp_ms, raw_kps)

            # ── Validación Anatómica (Firma Biométrica) ──────────────────────
            # Umbral ultra-relajado (100% de margen)
            anatomy_ok = not profile.is_ready or profile.validate_keypoints(filtered, tolerance=1.0)
            
            if not anatomy_ok:
                cv2.putText(frame, "ANATOMY WARNING (Distortion)", (10, 30),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 165, 255), 2)
            else:
                last_valid_filtered = filtered
                hold_counter = 0

            # ── Calibración de distancia (Escala fija por video) ─────────────
            if not calibrator.calibrated:
                calibrator.try_calibrate(filtered)

            # ── Sincronización Local (Ajuste Fino de articulaciones) ────────
            # Si ya tenemos escala, ajustamos los huesos a lo que se ve en el video
            if calibrator.calibrated and not local_synched:
                if profile.init_local_segments(filtered):
                    local_synched = True

            # ── View-Lock ────────────────────────────────────────────────────
            if biomech._view_lock is None and frame_idx < VIEW_LOCK_AFTER:
                current_view = biomech._detect_view(filtered)
                view_votes[current_view] += 1

                # Intentar bloquear cuando el voto alcanza la mayoría o al final de la ventana
                total_votes = sum(view_votes.values())
                dominant = max(view_votes, key=view_votes.get)
                majority_reached = (view_votes[dominant] / max(total_votes, 1)) > VIEW_LOCK_MAJORITY

                if majority_reached or frame_idx == VIEW_LOCK_AFTER - 1:
                    if dominant != ViewType.UNKNOWN:
                        biomech.set_view_lock(dominant)
            
            # ── Rectificación Anatómica (Rigor Biomecánico) ─────────────────
            # Detectar vista primero para saber qué rectificación aplicar
            current_view = biomech._detect_view(filtered)
            
            rectified = filtered
            if current_view == ViewType.LATERAL:
                rectified = profile.rectify_lateral(filtered)

            # ── Detección de Suelo ───────────────────────────────────────────
            gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
            ground_data = ground_detector.detect(
                gray, rectified,
                cm_per_pixel=calibrator.cm_per_pixel,
                height_cm=height_cm
            )

            # ── Análisis de Inclinación ──────────────────────────────────────
            incl_metrics = inclination.analyze(
                rectified,
                view_type=current_view.value,
                ground_y_px=ground_data.get('ground_y_px')
            )
            
            # ── Biomecánica ──────────────────────────────────────────────────
            metrics = biomech.calculate_metrics(rectified, gray, calibrator.px_to_cm, barbell_detector)
            view_type = ViewType(metrics.get('view_type', 'unknown'))

            # ── Guardar CSV ──────────────────────────────────────────────────
            for name, kp in filtered.items():
                row_data[f"{name}_x"] = round(kp['x'], 2)
                row_data[f"{name}_y"] = round(kp['y'], 2)
                row_data[f"{name}_conf"] = round(kp['conf'], 3)
            row_data.update(metrics)
            
            # Agregar datos de suelo e inclinación al CSV
            row_data.update(ground_data)
            row_data.update(incl_metrics)

            # ── Dibujar ──────────────────────────────────────────────────────
            # Pasamos la vista actual para que sepa si debe ocultar el lado lejano
            draw_skeleton(frame, rectified, current_view=view_type.value)
            draw_ground_line(frame, ground_data.get('ground_y_px'), ground_data.get('ground_method', '?'))
            draw_angle_arc(frame, rectified,
                          incl_metrics.get('trunk_angle_deg'),
                          incl_metrics.get('shin_angle_deg'))
            draw_hud(frame, metrics, incl_metrics, ground_data,
                    frame_idx, calibrator.calibrated, "analyze")
            
            # Platos: Los discos pueden confirmar la barra incluso si el brazo no se ve claro.
            plate_observed = False
            active_plate = None

            if view_type == ViewType.LATERAL:
                expected_radius_px = None
                if calibrator.cm_per_pixel:
                    expected_radius_px = int(22.5 / calibrator.cm_per_pixel)

                for side, direction in [('l', 'left'), ('r', 'right')]:
                    sh_kp = filtered.get(f'{side}_shoulder')
                    if _visible(filtered, f'{side}_shoulder', 0.4):
                        plate = plate_detector.detect(
                            gray, sh_kp['x'], sh_kp['y'], direction,
                            expected_radius_px=expected_radius_px
                        )
                        if plate:
                            px, py, pr = plate
                            y_diff_cm = abs(py - sh_kp['y']) * (calibrator.cm_per_pixel or 0)
                            if y_diff_cm < 12:
                                plate_observed = True
                                active_plate = (px, py, pr)
                                break # Basta con detectar un disco sólido

            # Integración de observaciones: Frontal (rod) + Lateral (platos) + Posterior (flare)
            raw_obs = metrics.get('barbell_observed', False) or plate_observed
            
            # Validamos con el buffer de persistencia
            has_barbell_final = barbell_detector.verify_with_buffer(raw_obs)
            metrics['has_barbell'] = has_barbell_final
            row_data['has_barbell'] = has_barbell_final

            # SÓLO dibujamos si la barra es estable según el buffer
            if has_barbell_final and active_plate:
                px, py, pr = active_plate
                cv2.circle(frame, (px, py), pr, CLR_FOOT, 2)

            # ── Export Training Data ─────────────────────────────────────────
            if training_exporter:
                training_exporter.add_frame(
                    frame_idx=frame_idx,
                    timestamp_ms=timestamp_ms,
                    view_type=view_type.value,
                    keypoints=filtered,
                    ground_data=ground_data,
                    inclination_data=incl_metrics,
                    biomech_data=metrics,
                )

        data_rows.append(row_data)
        out.write(frame)
        frame_idx += 1

    cap.release()
    out.release()
    tracker.close()

    if data_rows:
        pd.DataFrame(data_rows).to_csv(output_csv_path, index=False)
        print(f"Exportado: {output_csv_path}")
    
    if training_exporter:
        training_exporter.flush()
        summary = training_exporter.get_summary()
        print(f"\n[Training Export] Resumen:")
        print(f"  Frames totales: {summary['total_frames']}")
        print(f"  Vistas: {summary['views']}")
        print(f"  Con suelo: {summary['frames_with_ground']}")
        print(f"  Con inclinación: {summary['frames_with_inclination']}")

    print("Proceso completado.")


# ─── Entry Point ─────────────────────────────────────────────────────────────

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="LiftSense — Motor Biomecánico v2.0")
    parser.add_argument("input",  help="Ruta del video de entrada")
    parser.add_argument("--mode",    choices=["calibrate", "analyze", "export_training"], default="analyze",
                        help="Modo de operación (calibrate = frontal, analyze = ejecución, export_training = análisis + JSONL)")
    parser.add_argument("--height",  type=float, default=175.0,
                        help="Altura del usuario en CM")
    parser.add_argument("--profile", default=None,
                        help="Ruta al user_profile.json (obligatorio en modo analyze si se tiene)")
    parser.add_argument("--view", choices=["frontal", "posterior", "lateral"], default=None,
                        help="Forzar vista especifica (omite la detección automática)")
    args = parser.parse_args()

    base = os.path.splitext(os.path.basename(args.input))[0]
    dir_ = os.path.dirname(args.input) or "."

    if args.mode == "calibrate":
        profile_out = args.profile or os.path.join(dir_, "user_profile.json")
        run_calibrate(args.input, profile_out, args.height)
    else:
        out_vid = os.path.join(dir_, f"{base}_lstrack.mp4")
        out_csv = os.path.join(dir_, f"{base}_lstrack.csv")
        export_training = args.mode == "export_training"
        run_analyze(args.input, out_vid, out_csv, args.height, args.profile,
                   forced_view=args.view, export_training=export_training)

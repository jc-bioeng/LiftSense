"""
pose_tracker.py — Orquestador Principal LiftSense
Modos:
  calibrate → extrae antropometría frontal y guarda user_profile.json
  analyze   → carga el perfil, valida anatómicamente y analiza la sentadilla
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

# ─── Definición de colores ────────────────────────────────────────────────────
CLR_KP       = (0, 220, 80)      # keypoints  → verde
CLR_BONE     = (200, 200, 200)   # huesos     → gris
CLR_COM      = (0, 230, 230)     # CoM        → cian
CLR_BAR      = (255, 80, 0)      # barra C7   → naranja
CLR_PLUMB    = (80, 80, 255)     # plumb line → azul
CLR_FOOT     = (255, 0, 200)     # platos / pie→ magenta

SKELETON_CONNECTIONS = [
    ('nose', 'l_shoulder'), ('nose', 'r_shoulder'),
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

def draw_skeleton(frame, kps: dict, conf: float = 0.50):
    for p1, p2 in SKELETON_CONNECTIONS:
        if p1 in kps and p2 in kps:
            if kps[p1]['conf'] > conf and kps[p2]['conf'] > conf:
                cv2.line(frame,
                         (int(kps[p1]['x']), int(kps[p1]['y'])),
                         (int(kps[p2]['x']), int(kps[p2]['y'])),
                         CLR_BONE, 2)
    for name, kp in kps.items():
        if kp['conf'] > conf:
            cv2.circle(frame, (int(kp['x']), int(kp['y'])), 5, CLR_KP, -1)


def draw_hud(frame, metrics: dict, frame_idx: int, calib_ok: bool, mode: str):
    h, w = frame.shape[:2]
    panel_w = 260
    overlay = frame.copy()
    cv2.rectangle(overlay, (0, 0), (panel_w, 160), (0, 0, 0), -1)
    cv2.addWeighted(overlay, 0.45, frame, 0.55, 0, frame)

    def txt(text, row, color=(220, 220, 220)):
        cv2.putText(frame, text, (10, 22 + row * 28),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.65, color, 2)

    txt(f"Frame {frame_idx}  [{mode.upper()}]", 0)
    txt(f"Calib: {'OK' if calib_ok else 'Esperar...'}", 1,
        (0, 200, 80) if calib_ok else (0, 80, 255))
    txt(f"Vista: {metrics.get('view_type', '?').upper()}", 2, (200, 200, 0))
    bar_str = "Detectada" if metrics.get('has_barbell') else "No detectada"
    txt(f"Barra: {bar_str}", 3, CLR_BAR if metrics.get('has_barbell') else (80, 80, 255))

    if 'bar_to_midfoot_cm' in metrics:
        txt(f"Bar-Midfoot: {metrics['bar_to_midfoot_cm']:.1f} cm", 4, (255, 0, 200))

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


# ─── Modo: analyze ───────────────────────────────────────────────────────────

def run_analyze(input_path: str, output_video_path: str, output_csv_path: str,
                height_cm: float, profile_path: str | None):
    print("\n=== MODO ANÁLISIS ===")
    tracker = MediaPipePoseTracker()
    filter_session = PoseFilterSession()
    calibrator = CameraCalibrator(height_cm)
    biomech = BiomechanicsEngine()
    plate_detector = PlateDetector()
    profile = BodyProfile()

    if profile_path and profile.load(profile_path):
        # La firma ya tiene cm_per_pixel guardado, sincronizar con el calibrador
        calibrator.cm_per_pixel = profile.cm_per_pixel
        calibrator.calibrated = True
        print(f"[Perfil] Cargado desde {profile_path}")
    else:
        print("[Perfil] Sin perfil cargado. La validación anatómica estará inactiva.")

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
    VIEW_LOCK_AFTER = 30  # Frames para decidir la vista dominante

    print(f"Procesando: {input_path}  ({width}x{height} @{fps:.1f} FPS)")

    while cap.isOpened():
        ret, frame = cap.read()
        if not ret:
            break

        timestamp_ms = int(cap.get(cv2.CAP_PROP_POS_MSEC))
        image_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        pose_result = tracker.process_frame(image_rgb)

        row_data = {'frame': frame_idx, 'time_ms': timestamp_ms}

        if pose_result.keypoints:
            # ── Validar que hay una persona real ────────────────────────────
            raw_kps = pose_result.keypoints
            base_points = ['l_shoulder', 'r_shoulder', 'l_hip', 'r_hip']
            has_body = any(raw_kps.get(pt, {}).get('conf', 0) > 0.60 for pt in base_points)

            if not has_body:
                out.write(frame)
                frame_idx += 1
                data_rows.append(row_data)
                continue

            # ── Filtro One-Euro ──────────────────────────────────────────────
            filtered = filter_session.process(timestamp_ms, raw_kps)

            # ── Validación Anatómica (Firma Biométrica) ──────────────────────
            if profile.is_ready and not profile.validate_keypoints(filtered):
                # Esqueleto anatómicamente imposible → ignorar frame
                cv2.putText(frame, "FRAME INVALIDO (anatomy check)", (10, 30),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 0, 255), 2)
                out.write(frame)
                frame_idx += 1
                data_rows.append(row_data)
                continue

            # ── Calibración de distancia si no hay perfil ────────────────────
            if not calibrator.calibrated:
                calibrator.try_calibrate(filtered)

            # ── View-Lock ────────────────────────────────────────────────────
            if frame_idx < VIEW_LOCK_AFTER:
                current_view = biomech._detect_view(filtered)
                view_votes[current_view] += 1
                if frame_idx == VIEW_LOCK_AFTER - 1:
                    dominant = max(view_votes, key=view_votes.get)
                    biomech.set_view_lock(dominant)
            
            # ── Biomecánica ──────────────────────────────────────────────────
            metrics = biomech.calculate_metrics(filtered, calibrator.px_to_cm)
            view_type = ViewType(metrics.get('view_type', 'unknown'))

            # ── Guardar CSV ──────────────────────────────────────────────────
            for name, kp in filtered.items():
                row_data[f"{name}_x"] = round(kp['x'], 2)
                row_data[f"{name}_y"] = round(kp['y'], 2)
                row_data[f"{name}_conf"] = round(kp['conf'], 3)
            row_data.update(metrics)

            # ── Dibujar ──────────────────────────────────────────────────────
            draw_skeleton(frame, filtered)
            draw_hud(frame, metrics, frame_idx, calibrator.calibrated, "analyze")

            # Platos: solo en vista lateral
            if metrics.get('has_barbell') and view_type == ViewType.LATERAL:
                gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
                # Escalar radio esperado de disco olímpico (~22cm)
                expected_radius_px = None
                if calibrator.cm_per_pixel:
                    expected_radius_px = int(22.0 / calibrator.cm_per_pixel)

                for side, direction in [('l', 'left'), ('r', 'right')]:
                    wrist = filtered.get(f'{side}_wrist')
                    if wrist and wrist['conf'] > 0.50:
                        plate = plate_detector.detect(
                            gray, wrist['x'], wrist['y'], direction,
                            expected_radius_px=expected_radius_px
                        )
                        if plate:
                            px, py, pr = plate
                            cv2.circle(frame, (px, py), pr, CLR_FOOT, 2)

        data_rows.append(row_data)
        out.write(frame)
        frame_idx += 1

    cap.release()
    out.release()
    tracker.close()

    if data_rows:
        pd.DataFrame(data_rows).to_csv(output_csv_path, index=False)
        print(f"Exportado: {output_csv_path}")
    print("Proceso completado.")


# ─── Entry Point ─────────────────────────────────────────────────────────────

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="LiftSense — Motor Biomecánico")
    parser.add_argument("input",  help="Ruta del video de entrada")
    parser.add_argument("--mode",    choices=["calibrate", "analyze"], default="analyze",
                        help="Modo de operación (calibrate = frontal, analyze = ejecución)")
    parser.add_argument("--height",  type=float, default=175.0,
                        help="Altura del usuario en CM")
    parser.add_argument("--profile", default=None,
                        help="Ruta al user_profile.json (obligatorio en modo analyze si se tiene)")
    args = parser.parse_args()

    base = os.path.splitext(os.path.basename(args.input))[0]
    dir_ = os.path.dirname(args.input) or "."

    if args.mode == "calibrate":
        profile_out = args.profile or os.path.join(dir_, "user_profile.json")
        run_calibrate(args.input, profile_out, args.height)
    else:
        out_vid = os.path.join(dir_, f"{base}_lstrack.mp4")
        out_csv = os.path.join(dir_, f"{base}_lstrack.csv")
        run_analyze(args.input, out_vid, out_csv, args.height, args.profile)

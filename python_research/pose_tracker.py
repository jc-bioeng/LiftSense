import cv2
from ultralytics import YOLO
import pandas as pd
import argparse
import os

# Definir conexiones COCO clásicas para extremidades (Excluímos conexiones cruzadas de torso por estética)
SKELETON_CONNECTIONS = [(15, 13), (13, 11), (16, 14), (14, 12), 
                        (5, 7), (7, 9), (6, 8), (8, 10), 
                        (1, 2), (0, 1), (0, 2), (1, 3), (2, 4), (3, 5), (4, 6)]

def draw_custom_skeleton_with_spine(image, keypoints, conf_threshold=0.5):
    # keypoints es un tensor/array de shape [17, 3] (x, y, conf)
    
    # 1. Dibujar conexiones normales (brazos, piernas, rostro)
    for p1, p2 in SKELETON_CONNECTIONS:
        conf1 = keypoints[p1][2].item()
        conf2 = keypoints[p2][2].item()
        
        # Solo dibujar si AMBOS puntos son visibles
        if conf1 > conf_threshold and conf2 > conf_threshold:
            x1, y1 = int(keypoints[p1][0].item()), int(keypoints[p1][1].item())
            x2, y2 = int(keypoints[p2][0].item()), int(keypoints[p2][1].item())
            cv2.line(image, (x1, y1), (x2, y2), (0, 255, 0), 2)  # Línea verde para extremidades
            
    # 2. Dibujar puntos (articulaciones COCO)
    for i, pt in enumerate(keypoints):
        conf = pt[2].item()
        if conf > conf_threshold:
            x, y = int(pt[0].item()), int(pt[1].item())
            cv2.circle(image, (x, y), 4, (0, 0, 255), -1)  # Punto rojo

    # 3. SEGMENTACIÓN VIRTUAL DE COLUMNA (SPINE)
    # Extraer variables con sus respectivas confianzas
    l_sh, r_sh = keypoints[5], keypoints[6]
    l_hip, r_hip = keypoints[11], keypoints[12]

    # Calcular "Centro de Cuello / C7" (donde apoyaría la barra)
    if l_sh[2] > conf_threshold and r_sh[2] > conf_threshold:
        neck_x = int((l_sh[0] + r_sh[0]) / 2)
        neck_y = int((l_sh[1] + r_sh[1]) / 2)
        neck_conf = min(l_sh[2], r_sh[2])
    elif l_sh[2] > conf_threshold: # Perfil izquierdo
        neck_x, neck_y, neck_conf = int(l_sh[0]), int(l_sh[1]), l_sh[2]
    elif r_sh[2] > conf_threshold: # Perfil derecho
        neck_x, neck_y, neck_conf = int(r_sh[0]), int(r_sh[1]), r_sh[2]
    else:
        neck_conf = 0

    # Calcular "Centro de Pelvis / Sacro"
    if l_hip[2] > conf_threshold and r_hip[2] > conf_threshold:
        pelvis_x = int((l_hip[0] + r_hip[0]) / 2)
        pelvis_y = int((l_hip[1] + r_hip[1]) / 2)
        pelvis_conf = min(l_hip[2], r_hip[2])
    elif l_hip[2] > conf_threshold:
        pelvis_x, pelvis_y, pelvis_conf = int(l_hip[0]), int(l_hip[1]), l_hip[2]
    elif r_hip[2] > conf_threshold:
        pelvis_x, pelvis_y, pelvis_conf = int(r_hip[0]), int(r_hip[1]), r_hip[2]
    else:
        pelvis_conf = 0

    # Si tenemos ambos extremos de la columna, trazamos la línea central biomecánica
    if neck_conf > conf_threshold and pelvis_conf > conf_threshold:
        # Dibujar Columna (Cian, con línea gruesa)
        cv2.line(image, (neck_x, neck_y), (pelvis_x, pelvis_y), (255, 255, 0), 4)
        cv2.circle(image, (neck_x, neck_y), 6, (255, 150, 0), -1) # Punto C7
        cv2.circle(image, (pelvis_x, pelvis_y), 6, (255, 150, 0), -1) # Punto Sacro

    return neck_x if neck_conf > conf_threshold else None, neck_y if neck_conf > conf_threshold else None, pelvis_x if pelvis_conf > conf_threshold else None, pelvis_y if pelvis_conf > conf_threshold else None

def process_video_yolo(input_video_path, output_video_path, output_csv_path):
    print("Cargando modelo YOLOv8m-pose...")
    model = YOLO("yolov8m-pose.pt")

    cap = cv2.VideoCapture(input_video_path)
    if not cap.isOpened():
        print(f"Error: No se pudo abrir el video {input_video_path}")
        return

    width  = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    fps    = cap.get(cv2.CAP_PROP_FPS)

    fourcc = cv2.VideoWriter_fourcc(*'mp4v')
    out = cv2.VideoWriter(output_video_path, fourcc, fps, (width, height))

    frame_data = []
    frame_idx = 0

    print(f"Procesando video con YOLOv8 Biomécanico... ({width}x{height} a {fps} FPS)")

    VISIBILITY_THRESHOLD = 0.60
    DRAW_THRESHOLD = 0.50 
    STABLE_FRAMES_REQ = 5
    consecutive_valid_frames = 0

    while cap.isOpened():
        ret, frame = cap.read()
        if not ret:
            break

        timestamp_ms = int(cap.get(cv2.CAP_PROP_POS_MSEC))
        results = model(frame, verbose=False)
        annotated_frame = frame.copy()

        valid_pose_found = False

        if len(results) > 0 and results[0].keypoints is not None and len(results[0].keypoints.data) > 0:
            for idx_person, keypoints in enumerate(results[0].keypoints.data):
                if len(keypoints) >= 15:
                    l_shoulder_conf = keypoints[5][2].item()
                    r_shoulder_conf = keypoints[6][2].item()
                    l_hip_conf = keypoints[11][2].item()
                    r_hip_conf = keypoints[12][2].item()
                    l_knee_conf = keypoints[13][2].item()
                    r_knee_conf = keypoints[14][2].item()
                    
                    has_shoulder = (l_shoulder_conf > VISIBILITY_THRESHOLD) or (r_shoulder_conf > VISIBILITY_THRESHOLD)
                    has_hip = (l_hip_conf > VISIBILITY_THRESHOLD) or (r_hip_conf > VISIBILITY_THRESHOLD)
                    has_knee = (l_knee_conf > VISIBILITY_THRESHOLD) or (r_knee_conf > VISIBILITY_THRESHOLD)

                    if has_shoulder and has_hip and has_knee:
                        valid_pose_found = True
                        consecutive_valid_frames += 1
                        
                        if consecutive_valid_frames >= STABLE_FRAMES_REQ:
                            # Dibujamos manualmente el esqueleto y la COLUMNA VIRTUAL
                            res = draw_custom_skeleton_with_spine(annotated_frame, keypoints, conf_threshold=DRAW_THRESHOLD)
                            n_x, n_y, p_x, p_y = res
                            
                            row = {'frame': frame_idx, 'timestamp_ms': timestamp_ms}
                            for idx, point in enumerate(keypoints):
                                row[f'landmark_{idx}_x'] = point[0].item()
                                row[f'landmark_{idx}_y'] = point[1].item()
                                row[f'landmark_{idx}_conf'] = point[2].item()
                            
                            # Agregamos los puntos biomecánicos al CSV para cálculos futuros de Torque y Barras
                            row['spine_neck_x'] = n_x if n_x is not None else ""
                            row['spine_neck_y'] = n_y if n_y is not None else ""
                            row['spine_pelvis_x'] = p_x if p_x is not None else ""
                            row['spine_pelvis_y'] = p_y if p_y is not None else ""
                            
                            frame_data.append(row)
                        break

        if not valid_pose_found:
            consecutive_valid_frames = 0
            
        out.write(annotated_frame)
        frame_idx += 1

    cap.release()
    out.release()

    if frame_data:
        df = pd.DataFrame(frame_data)
        df.to_csv(output_csv_path, index=False)
        print(f"Procesamiento completado. Datos guardados en {output_csv_path}")
    else:
        print("No se encontraron posturas válidas (según el filtro estricto) en todo el video.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Analizar video de sentadilla con segmento de columna')
    parser.add_argument('input', help='Ruta del video de entrada o carpeta de videos')
    args = parser.parse_args()

    input_path = args.input

    if os.path.isfile(input_path):
        video_name = os.path.splitext(os.path.basename(input_path))[0]
        out_video = f"{video_name}_biomechanic_output.mp4"
        out_csv = f"{video_name}_biomechanic_landmarks.csv"
        
        dir_name = os.path.dirname(input_path)
        if dir_name:
            out_video = os.path.join(dir_name, out_video)
            out_csv = os.path.join(dir_name, out_csv)
            
        process_video_yolo(input_path, out_video, out_csv)
    elif os.path.isdir(input_path):
        out_dir = os.path.join(input_path, 'output')
        os.makedirs(out_dir, exist_ok=True)
        for file in os.listdir(input_path):
            if file.lower().endswith(('.mp4', '.mov', '.avi')):
                print(f"\n--- Procesando: {file} ---")
                in_filepath = os.path.join(input_path, file)
                video_name = os.path.splitext(file)[0]
                out_video = os.path.join(out_dir, f"{video_name}_biomechanic_output.mp4")
                out_csv = os.path.join(out_dir, f"{video_name}_biomechanic_landmarks.csv")
                process_video_yolo(in_filepath, out_video, out_csv)
    else:
        print("La ruta especificada no existe o no es válida.")

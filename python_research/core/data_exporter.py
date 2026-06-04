"""
data_exporter.py
Exportador de datos estructurados para entrenamiento de modelos de ML.
Genera archivos JSONL con estructura optimizada por frame.
"""

import json
import os


class TrainingDataExporter:
    """
    Genera un archivo .jsonl con datos estructurados por frame,
    listos para entrenar modelos de clasificación, regresión o detección.
    """

    def __init__(self, output_path: str):
        self.output_path = output_path
        self._buffer: list[dict] = []
        self._frame_count = 0

    def add_frame(self, frame_idx: int, timestamp_ms: int,
                  view_type: str, keypoints: dict,
                  ground_data: dict | None = None,
                  inclination_data: dict | None = None,
                  biomech_data: dict | None = None):
        """
        Registra un frame completo con todos los datos disponibles.

        Args:
            frame_idx: Índice del frame
            timestamp_ms: Timestamp en milisegundos
            view_type: Tipo de vista detectada
            keypoints: Keypoints filtrados (dict de dicts)
            ground_data: Datos del suelo detectado
            inclination_data: Ángulos de inclinación
            biomech_data: Métricas biomecánicas (CoM, barra, etc.)
        """
        record = {
            'frame': frame_idx,
            'time_ms': timestamp_ms,
            'view': view_type,
        }

        # ── Ground ───────────────────────────────────────────────────────────
        if ground_data:
            record['ground_y_px'] = ground_data.get('ground_y_px')
            record['ground_method'] = ground_data.get('ground_method')
            record['ground_confidence'] = ground_data.get('ground_confidence')

        # ── Inclination ──────────────────────────────────────────────────────
        if inclination_data:
            record['inclination'] = inclination_data

        # ── Biomechanics ─────────────────────────────────────────────────────
        if biomech_data:
            record['biomechanics'] = {
                k: v for k, v in biomech_data.items()
                if k not in ('view_type',)  # Ya guardado arriba
            }

        # ── Keypoints (formato compacto) ─────────────────────────────────────
        kp_compact = {}
        for name, kp in keypoints.items():
            kp_compact[name] = {
                'x': round(kp['x'], 1),
                'y': round(kp['y'], 1),
                'conf': round(kp['conf'], 3),
            }
        record['keypoints'] = kp_compact

        # ── Label placeholder ────────────────────────────────────────────────
        record['label'] = None  # Para etiquetado posterior

        self._buffer.append(record)
        self._frame_count += 1

    def flush(self):
        """Escribe el buffer a disco en formato JSONL."""
        if not self._buffer:
            return

        with open(self.output_path, 'w', encoding='utf-8') as f:
            for record in self._buffer:
                f.write(json.dumps(record, ensure_ascii=False) + '\n')

        print(f"[Exporter] {self._frame_count} frames exportados a: {self.output_path}")

    def get_summary(self) -> dict:
        """Devuelve estadísticas del dataset exportado."""
        if not self._buffer:
            return {'frames': 0}

        views = {}
        has_ground = 0
        has_inclination = 0

        for r in self._buffer:
            v = r.get('view', 'unknown')
            views[v] = views.get(v, 0) + 1
            if r.get('ground_y_px') is not None:
                has_ground += 1
            if r.get('inclination'):
                has_inclination += 1

        return {
            'total_frames': self._frame_count,
            'views': views,
            'frames_with_ground': has_ground,
            'frames_with_inclination': has_inclination,
            'output_path': self.output_path,
        }

# 🏋️ LiftSense - Motor de Investigación Biomecánica

Este directorio es el núcleo científico de LiftSense. Implementa un pipeline de visión artificial optimizado para el análisis clínico de la sentadilla, utilizando una combinación de Deep Learning (MediaPipe) y Visión Computacional clásica (OpenCV).

## 📂 Estructura del Proyecto

```text
python_research/
├── core/                        # Núcleo del Motor Biomecánico
│   ├── tracker.py               # Wrapper de MediaPipe Pose (33 landmarks)
│   ├── filters.py               # Implementación de One-Euro y Deadzones
│   ├── camera_calibration.py    # Perfil antropométrico, Escala y Rectificación
│   ├── biomechanics.py          # Lógica de ángulos, CoM e inferencia de barra
│   ├── plate_detector.py        # CV clásica para discos (Hough Circles + Textura)
│   └── barbell_detector.py      # CV clásica para vara (Hough Lines + Tracking)
├── pose_tracker.py              # Orquestador Principal (Interfaz CLI)
├── user_profile.json            # Firma biométrica guardada (Privado)
├── ENGINE_ARCHITECTURE.md       # Documentación técnica avanzada (UML/Flujos)
└── README.md                    # Esta guía
```

## 🛡️ Estrategia de Estabilización (The Protection Onion)

La estabilidad del esqueleto en LiftSense no es producto del azar, sino de un pipeline de suavizado en capas:

### 1. Filtro One-Euro (Adaptativo)
*   **Referencia**: [Casiez, G. et al. (2012). "1€ Filter: A Simple Algorithm for Filtering Noisy Signals in Real Time"](https://hal.inria.fr/hal-00670496/document).
*   **Lógica**: Utiliza una frecuencia de corte dinámica $f_c$ que varía según la velocidad del landmark.
    - **En reposo ($v \approx 0$)**: La frecuencia de corte mínima ($f_{c\_min} = 0.01$ para pies) elimina el temblor electrónico de la cámara.
    - **En movimiento**: El parámetro $\beta$ permite que el filtro se "abra", eliminando el retraso (lag) y siguiendo el movimiento humano explosivo.

### 2. Foot Locking (Deadzone Espacial)
*   **Lógica**: Filtro de histéresis de 1.5px. Si el desplazamiento euclídeo del tobillo es menor al umbral, el punto se bloquea.
*   **Objetivo**: "Clavar" el centro del pie al suelo, evitando el efecto de patinaje sobre hielo común en visiones artificiales.

### 3. Sincronización Local (Local-Frame Sync)
*   **Lógica**: En los primeros frames del video, el sistema "mapea" las proporciones visuales que MediaPipe otorga a los huesos del usuario.
*   **Objetivo**: Corregir desfases de 1-2cm debidos a la perspectiva, alineando el esqueleto perfectamente con el centro visual de la articulación.

### 4. Rectificación Cinemática (Cascada Inversa)
*   **Lógica**: Proyección trigonométrica que mantiene la magnitud de los vectores óseos constante basada en la firma biométrica.
*   **Innovación**: En lateral, rectificamos de **Tobillo hacia Rodilla**. El pie es el ancla, y el fémur absorbe la discrepancia, protegiendo la base de la sentadilla.

---

## 🛠️ Stack Tecnológico

*   **Motor de Pose**: Google MediaPipe Pose (Modelo BlazePose GHUM).
*   **Motor de Visión**: OpenCV 4.x.
*   **Matemáticas**: NumPy (Álgebra vectorial) y Pandas (Exportación).
*   **Licencia**: MIT.

---
**LiftSense Research Group** - *Poniendo ciencia en cada repetición.*

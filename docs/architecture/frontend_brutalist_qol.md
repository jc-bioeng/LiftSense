# Frontend - Arquitectura y Brutalist QoL

## Visión General
Esta documentación define el diseño arquitectónico y visual de la aplicación móvil de **LiftSense**. Para diferenciarnos de estándares pasivos o "amigables", la aplicación aborda el análisis deportivo de fuerza desde una perspectiva forense, implementando un diseño **Studio Brutalist Dark** y lógicas modales dinámicas (QoL) para optimizar el flujo de usuarios e investigadores.

## Decisiones de Diseño Principal (Studio Brutalist Dark)
1. **Colores:** Se optó por utilizar una paleta hiper-profunda.
   - **Background:** `#000000` (Negro Puro).
   - **Acento Primario (Destaque):** `#FF2A4D` (Cyber Crimson) para evocar profesionalismo médico/mecánico y urgencia métrica.
   - **Interfases / Card Surfaces:** `#0C0C0C`, delineadas con trazos grises estrictamente sin redondear (`BorderRadius.zero`).
2. **Tipografía Dual de Ingeniería:**
   - **Oswald:** Títulos, Acciones principales (Llamativo e industrial).
   - **IBM Plex Mono:** Cifras, Datos analíticos, y labels secundarios (Simulación de "terminal" científica sin sacrificar legibilidad).

## Reestructuración Quality of Life (QoL)
Durante la fase del prototipado (Sprint 1), se implementaron flujos para preservar la inmersión:
- **No-Navegación Intrusiva en Acciones Base:** El acto de Capturar o Importar no redirige a pantallas completas dedicadas, sino que se alza un control _Bottom Sheet Modal_ agresivo para no separar al usuario visualmente del marco de _Meta-Trendings_ en el Dashboard.
- **Widgets Inteligentes en AnalysisScreen:** 
  - *Scrubbing Táctil Inmersivo y Control Avanzado.* La pestaña de investigación de cinemática utiliza un `InteractiveViewer` que permite al analista hacer "Pinch-To-Zoom" al jugador interactuando orgánicamente con el clip sin botones estorbosos, y `Haptics` de control de video.

## Arquitectura de Directorios (Frontend)
El código de vistas se organiza primordialmente desvinculado de la capa de estado (A la espera de inyectar los gestores de Riverpod/Bloc a futuro) y respetando las configuraciones `l10n`.
- `/ui`: Contiene las "Screens" funcionales (Dashboard, Analysis) y las BottomSheets.
- `/models`: Modelos atómicos nativos, inicialmente adaptados vía Hive DB para soporte local aislado (`squat_session.dart`).
- `/assets`: Recursos fijos de simulación (e.j., outputs pre-renderizados del YOLO Tracker en python).

## Migración al Motor ML Local (Pendiente)
Bajo los cánones de latencia Zero (0-delay), la carga biomecánica y el layout CustomPainter en Flutter heredará dinámicamente los tensores que ya fueron modelados rigurosamente por el CLI en `python_research/pose_tracker.py`. La extracción ocurrirá on-device usando los localizadores de `google_mlkit_pose_detection`.

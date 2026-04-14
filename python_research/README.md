# LiftSense - Investigación de Pose Tracking

Este directorio contiene el código y la experimentación inicial para la extracción biomecánica de coordenadas (Tracking) de sentadillas utilizando técnicas de Pose Estimation.

## 📁 Archivos principales
* `pose_tracker.py`: Script principal de tracking biomecánico.
* `run_tracker.bat`: Ejecutable para procesar los videos de forma automatizada usando el entorno virtual.
* `requirements.txt`: Dependencias del entorno de Python.

---

## 🛠️ Decisiones Técnicas Tomadas

### 1. Cambio de Arquitectura: de MediaPipe a YOLOv8
**Contexto inicial:** Se implementó `MediaPipe Pose` ya que es de la vieja escuela y ofrece buena segmentación 2D. 
**Problema:** MediaPipe demostró un desempeño pobre y caídas completas de predicción durante las sentadillas laterales completas (donde se ocluía parte del cuerpo por completo) y en vistas posteriores puras debido a la ausencia de reconocimiento facial. 
**Solución:** Se migró a **Ultralytics YOLOv8-Pose**. YOLOv8 no depende de un rostro humano como ancla geométrica, solucionando el problema lateral y entregando predicción robusta en escenarios severamente ocluidos y espaldas puras.

### 2. Filtrado de Falsos Positivos
**Contexto:** Los modelos basados en YOLO y MediaPipe, al configurarse con confianza baja, detectan frecuentemente geometría de fondo como si fuesen partes del cuerpo para intentar "calzar" el esqueleto en el plano (Falsos Positivos).
**Solución:** Se implementó un algoritmo estricto de visibilidad (`VISIBILITY_THRESHOLD = 0.60`) que requiere que los puntos clave absolutos (hombros, cadera y rodillas) de una persona estén visibles; de lo contrario, el frame entero se rechaza. 
**Mejora de Estabilidad (Warm-up):** Para evitar fallos iniciales en fotogramas borrosos, el algoritmo espera detectar consistentemente la pose validada por al menos 5 frames seguidos antes de empezar a grabar un esqueleto en los videos de salida.

### 3. Exclusión Visual de Brazos Ocluidos
**Problema:** Al hacer Backsquat con vista lateral, el brazo opuesto pierde por completo visibilidad, causando que las librerías fuercen a la línea virtual a dibujar hacia la esquina superior del video (Coordenada 0,0 en casos de pérdida grave).
**Solución:** Se desactivó la función nativa `.plot()` de YOLOv8 que interconecta todo ciegamente. Se programó a medida un método `draw_custom_skeleton_with_spine` para aplicar filtros individualizados a cada conexión ósea en COCO. Si las extremidades poseen un `DRAW_THRESHOLD` < 0.50, los huesos virtualmente se ocultan para lograr un procesamiento visual ultra-limpio. Las caderas, piernas y espalda nunca sufren disrupción gráfica.

### 4. Segmentación Biomecánica: "Columna Virtual"
**Problema:** Ninguno de los modelos populares de Machine Learning (COCO, MediaPipe, MPII) tienen puntos vertebrales exactos para segmentar la columna en sentadillas.
**Solución e Implementación:** 
- Se derivaron dos puntos virtuales vitales mediante cálculo geométrico. 
- *Punto Cervical (C7):* Punto de apoyo típico de la barra de High Bar. (Punto medio entre Hombro Derecho e Izquierdo).
- *Punto del Sacro:* Estimación del límite inferior lumbar (Punto medio entre Cadera Derecha e Izquierda).
- Estas coordenadas (`spine_neck` y `spine_pelvis`) ahora se dibujan explícitamente en color cian y se exportan nativamente al archivo CSV, listas para ser convertidas a metros y generar **Reacciones de Fuerzas / Momentum Crítico Lumbopélvico**.

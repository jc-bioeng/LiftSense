# Arquitectura de la Base de Datos y Captación de Datos

Este documento describe el diseño de la base de datos local y el sistema de captación de datos de **LiftSense**. La base de datos está diseñada utilizando **SQLAlchemy** como ORM y **Alembic** para el control de migraciones. Actualmente utiliza **SQLite** para el desarrollo local, pero la estructura está totalmente desacoplada y lista para migrar a **PostgreSQL** mediante Docker.

---

## 1. Modelo de Datos y Separación de Responsabilidades

El diseño sigue estrictamente los principios de separación de responsabilidades estipulados en la arquitectura del sistema:
- **Metadatos e Identidad**: Gestionados a través de las tablas `users` y `analysis_jobs`.
- **Datos Crudos (Raw Data)**: Captura directa de los 33 landmarks de MediaPipe por fotograma en la tabla `raw_data`. Para cumplir con el requerimiento de almacenamiento en tabla cruda de manera eficiente, se utiliza una columna JSON que almacena el arreglo de coordenadas $(x, y, z, v)$ de cada landmark, evitando la creación redundante de más de 130 columnas y optimizando el rendimiento de indexación y consulta.
- **Resultados Biomecánicos Procesados**: Almacenados en `processed_results`, conteniendo las métricas calculadas como el Centro de Masa (CoM), la posición de la vértebra C7, alineación del pie medio (`mid_foot_x`) y detección de barra.

```mermaid
erDiagram
    users ||--o{ analysis_jobs : "crea"
    analysis_jobs ||--o{ raw_data : "contiene"
    analysis_jobs ||--o{ processed_results : "genera"

    users {
        string id PK
        string name
        datetime created_at
    }

    analysis_jobs {
        string id PK
        string user_id FK
        string video_path
        string status
        datetime created_at
    }

    raw_data {
        string id PK
        string job_id FK
        int frame
        float time_ms
        json landmarks_json
    }

    processed_results {
        string id PK
        string job_id FK
        int frame
        float time_ms
        float com_x
        float com_y
        float c7_x
        float c7_y
        float mid_foot_x
        string view_type
        boolean has_barbell
    }
```

---

## 2. Diccionario de Datos (Esquema Físico)

### 2.1. Tabla: `users`
Almacena la información de los usuarios que realizan levantamientos.
| Campo | Tipo | Restricciones | Descripción |
| :--- | :--- | :--- | :--- |
| `id` | `VARCHAR` | PK, Index | Identificador único (UUID v4 auto-generado) |
| `name` | `VARCHAR` | Index | Nombre completo o identificador del usuario |
| `created_at` | `DATETIME` | Default: `now()` | Fecha y hora de registro del usuario |

### 2.2. Tabla: `analysis_jobs`
Registra cada sesión de análisis de video o captura en vivo de levantamientos.
| Campo | Tipo | Restricciones | Descripción |
| :--- | :--- | :--- | :--- |
| `id` | `VARCHAR` | PK, Index | Identificador único del trabajo (UUID v4) |
| `user_id` | `VARCHAR` | FK (`users.id`) | Relación con el usuario propietario |
| `video_path` | `VARCHAR` | Nullable | Ruta del video analizado en el servidor/dispositivo |
| `status` | `VARCHAR` | Default: `'pending'` | Estado del análisis (`pending`, `processing`, `completed`, `failed`) |
| `created_at` | `DATETIME` | Default: `now()` | Fecha y hora de creación de la sesión |

### 2.3. Tabla: `raw_data`
Almacena los datos crudos extraídos directamente del estimador de pose (MediaPipe).
| Campo | Tipo | Restricciones | Descripción |
| :--- | :--- | :--- | :--- |
| `id` | `VARCHAR` | PK, Index | Identificador único del registro (UUID v4) |
| `job_id` | `VARCHAR` | FK (`analysis_jobs.id`), Index | Relación con la sesión de análisis |
| `frame` | `INTEGER` | Index | Número de fotograma secuencial (0-N) |
| `time_ms` | `FLOAT` | - | Marca de tiempo del fotograma en milisegundos |
| `landmarks_json` | `JSON` (Texto) | - | Lista JSON de los 33 landmarks de MediaPipe: `[{x, y, z, v}, ...]` |

### 2.4. Tabla: `processed_results`
Contiene los resultados biomecánicos procesados y métricas calculadas.
| Campo | Tipo | Restricciones | Descripción |
| :--- | :--- | :--- | :--- |
| `id` | `VARCHAR` | PK, Index | Identificador único del registro (UUID v4) |
| `job_id` | `VARCHAR` | FK (`analysis_jobs.id`), Index | Relación con la sesión de análisis |
| `frame` | `INTEGER` | Index | Número de fotograma secuencial |
| `time_ms` | `FLOAT` | - | Marca de tiempo del fotograma en milisegundos |
| `com_x` | `FLOAT` | Nullable | Coordenada X calculada del Centro de Masa (CoM) |
| `com_y` | `FLOAT` | Nullable | Coordenada Y calculada del Centro de Masa (CoM) |
| `c7_x` | `FLOAT` | Nullable | Coordenada X de la vértebra C7 |
| `c7_y` | `FLOAT` | Nullable | Coordenada Y de la vértebra C7 |
| `mid_foot_x` | `FLOAT` | Nullable | Coordenada X del centro del pie de apoyo |
| `view_type` | `VARCHAR` | Nullable | Tipo de vista detectada/configurada (`sagittal`, `frontal`) |
| `has_barbell` | `BOOLEAN` | Default: `False` | Indica si se detectó una barra en este fotograma |

---

## 3. Captación e Ingesta de Datos (Modelo de Carga)

Para la ingesta inicial y validación del sistema, se construyó el script automatizado [import_csv.py](file:///c:/flutter_projects/LiftSense/backend/import_csv.py). Este script demuestra cómo capturar datos de fuentes externas o en tiempo real e insertarlos eficientemente:

1. **Creación del Contexto**: Genera un usuario de pruebas y un trabajo de análisis asociado en estado completado.
2. **Procesamiento de Archivos CSV Crudos**: Lee el archivo `1_landmarks.csv` que contiene las columnas de landmarks plano (`landmark_i_x`, `landmark_i_y`, etc.), agrupa estos puntos en un arreglo estructurado de diccionarios, y los guarda masivamente mediante `bulk_save_objects` en formato JSON en `raw_data`.
3. **Procesamiento de Métricas Biomecánicas**: Lee `frontal_lstrack.csv` mapeando las variables físicas (CoM, C7, Pie Medio) a la tabla `processed_results`.
4. **Resultados de Validación**: Durante la carga inicial, el script validó con éxito la inserción de **472 fotogramas crudos** y **434 fotogramas procesados**.

Este flujo sirve de plantilla para el desarrollo de los endpoints de la API de FastAPI que recibirán capturas en tiempo real desde la aplicación de Flutter.

---

## 4. Gestión de Migraciones con Alembic

El control de versiones del esquema de la base de datos se maneja a través de Alembic. Esto permite que el esquema evolucione de manera segura y sincronizada con el equipo de desarrollo.

### 4.1. Comandos Esenciales de Alembic
Para operar el sistema de migraciones, asegúrate de estar dentro del entorno virtual (`.venv`) y posicionado en la carpeta `backend`:

*   **Crear una nueva migración automáticamente** (después de modificar cualquier modelo en `app/models/`):
    ```bash
    alembic revision --autogenerate -m "describir_el_cambio"
    ```
*   **Aplicar migraciones pendientes a la base de datos**:
    ```bash
    alembic upgrade head
    ```
*   **Revertir la última migración aplicada**:
    ```bash
    alembic downgrade -1
    ```

### 4.2. Configuración de Migraciones
Las migraciones están configuradas en `backend/alembic.ini` y el entorno en `backend/alembic/env.py`. Se configuró `target_metadata` para apuntar a `Base.metadata` de SQLAlchemy, lo que permite la detección automática de cambios en los modelos al ejecutar revisiones.

---

## 5. Escalabilidad y Futura Migración a Producción

La base de datos local SQLite (`lift_sense.db`) proporciona un entorno de desarrollo ágil y sin dependencias externas complejas. Sin embargo, para producción:

1. **Configuración de Variables de Entorno**: El archivo `app/infrastructure/database.py` está configurado para leer la URL de conexión desde una variable de entorno (`DATABASE_URL`).
2. **Soporte PostgreSQL**: Simplemente cambiando el valor de `DATABASE_URL` a un string de conexión de PostgreSQL (por ejemplo, en un archivo `.env` o variable de entorno de Docker: `postgresql://user:password@localhost:5432/liftsense`), SQLAlchemy y Alembic se adaptarán automáticamente sin requerir cambios de código en los modelos de dominio.
3. **Contenedores Docker**: El `Dockerfile` del backend ya se encuentra preparado en la carpeta raíz del backend para empaquetar la aplicación y conectarse a un contenedor Docker de PostgreSQL o Supabase de manera inmediata.

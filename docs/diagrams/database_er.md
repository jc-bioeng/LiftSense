# Database ER Diagram

The database is built on PostgreSQL (Supabase) and follows a relational structure optimized for biomechanical time-series data and session management.

```mermaid
erDiagram
    PROFILES ||--o{ SESSIONS : performs
    PROFILES ||--o{ ANTHROPOMETRY_PROFILES : has

    PROFILES {
        uuid id PK
        string email
        user_role role
        timestamp created_at
        jsonb metadata
    }

    ANTHROPOMETRY_PROFILES ||--o{ SESSIONS : used_in

    ANTHROPOMETRY_PROFILES {
        uuid id PK
        uuid user_id FK
        float height_cm
        float weight_kg
        jsonb segment_lengths
        anthropometry_model model
        timestamp valid_from
        timestamp valid_to
        boolean is_active
    }

    SESSIONS ||--o{ LANDMARKS : contains
    SESSIONS ||--o{ METRICS : results_in

    SESSIONS {
        uuid id PK
        uuid user_id FK
        uuid anthropometry_profile_id FK
        string exercise
        capture_mode capture_mode
        boolean has_depth
        int fps
        string model_version
        timestamp created_at
    }

    LANDMARKS {
        uuid id PK
        uuid session_id FK
        coordinate_system coordinate_system
        jsonb data
    }

    METRICS {
        uuid id PK
        uuid session_id FK
        string metric_type
        biomech_phase phase
        float value
        string unit
        float timestamp
    }
```

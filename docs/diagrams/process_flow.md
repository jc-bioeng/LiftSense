# Biomechanical Analysis Process Flow

This diagram illustrates the lifecycle of a biomechanical capture session, from video acquisition on the mobile device to final metric storage.

```mermaid
sequenceDiagram
    participant U as User (Athlete/Trainer)
    participant F as Flutter App (MediaPipe)
    participant S as Supabase (DB/Auth)
    participant B as Python Backend (FastAPI)

    U->>F: Start Capture (e.g., Back Squat)
    F->>F: Real-time Landmark Detection
    F->>U: Feedback (Real-time Overlay)
    U->>F: End Capture
    
    F->>S: Store Session Meta & Raw Landmarks
    Note over F,S: Landmarks saved as JSONB in 'landmarks' table

    U->>F: Request Advanced Analysis
    F->>B: Trigger Analysis Pipeline (Session ID)
    
    B->>S: Fetch landmarks & anthropometry
    S-->>B: Landmark Data
    
    B->>B: Preprocessing (Filtering/Smoothing)
    B->>B: Kinematic Engine (Joint Angles/Velocities)
    B->>B: Peak/Phase Detection
    
    B->>S: Store calculated 'metrics'
    B-->>F: Analysis Complete (JSON Report)
    
    F->>U: Display Dashboard (Graphs/ROM)
```

## Key Stages

1. **Acquisition**: MediaPipe runs locally on the edge for immediate feedback and privacy.
2. **Offloading**: Only extracted landmark data (not necessarily the full video) is pushed to Supabase to save bandwidth, unless "Lab" mode is selected.
3. **Refinement**: The Python backend applies scientific-grade signal processing (e.g., Butterworth filters, spline interpolation) that is too heavy or complex to implement reliably in cross-platform Dart.
4. **Insight**: Results are persisted in the `metrics` table for longitudinal progress tracking.

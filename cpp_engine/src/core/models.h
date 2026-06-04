#ifndef LIFTSENSE_MODELS_H
#define LIFTSENSE_MODELS_H

#include <vector>

namespace liftsense {
namespace core {

    enum class ViewType { FRONTAL, LATERAL, OBLIQUE };
    enum class WarningLevel { NONE, LOW, MEDIUM, HIGH, CRITICAL };
    enum class ExerciseType { SQUAT, DEADLIFT, BENCH_PRESS };

    // Fases del movimiento de Back Squat
    enum class MovementPhase {
        IDLE = 0,
        DESCENDING = 1,
        BOTTOM = 2,      // Máxima profundidad
        ASCENDING = 3,
        STICKING_POINT = 4,
        FAIL = 5
    };

    // Representa un punto clave (Landmark) detectado por MediaPipe
    struct Landmark {
        float x;
        float y;
        float z;
        float conf; // Nivel de confianza (0.0 a 1.0)
    };

    // Representa un frame completo de datos capturados
    struct PoseFrame {
        int frame_index;
        long time_ms;
        std::vector<Landmark> landmarks; // MediaPipe 33 landmarks
        
        // Coordenadas calculadas externamente (ej. CSV) o extraídas
        float com_x = 0.0f;
        float com_y = 0.0f;
        float mid_hip_x = 0.0f;
        float mid_hip_y = 0.0f;
        float mid_foot_x = 0.0f;
        float heel_x = 0.0f;
        float foot_index_x = 0.0f;
    };

    // Salida geométrica del motor base
    struct JointAngles {
        float left_knee;
        float right_knee;
        float left_hip;
        float right_hip;
        float trunk_flexion;
        float tibia_angle;
        float valgus_angle;
        float com_projection; // Distancia COM a la base de soporte
        float hip_knee_ratio; // Dominancia de cadena posterior (HKR)
        
        // Advanced Metrics (Clinical Proxies via FLU)
        float lumbar_loading_proxy;       // Proximal Torque en Lumbar (Distance / FLU)
        float patellofemoral_stress_proxy;// Proximal Torque en Rodilla (Distance / FLU)
        float butt_wink_probability;      // Probabilidad [0.0 - 1.0] heurística
    };

    // Resultado consolidado para ser retornado por el motor de métricas
    struct BiomechanicalMetrics {
        JointAngles angles;
        MovementPhase phase;
        WarningLevel warning_level;
        float vertical_velocity;
        float asymmetry_index;
        bool is_risk_detected;
    };

} // namespace core
} // namespace liftsense

#endif // LIFTSENSE_MODELS_H

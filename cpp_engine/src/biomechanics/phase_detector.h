#ifndef LIFTSENSE_PHASE_DETECTOR_H
#define LIFTSENSE_PHASE_DETECTOR_H

#include "../core/models.h"
#include <vector>

namespace liftsense {
namespace biomechanics {

    struct KinematicState {
        float y_pos;
        float v_y;
        float a_y;
        float knee_angle;
        long time_ms;
    };

    class ButterworthFilter {
    public:
        ButterworthFilter();
        // Filtro pasabajos de 2do orden.
        float process(float input);
        void reset();
    private:
        float v1_, v2_;
        // Coeficientes precalculados para fc=5Hz, fs=30Hz (Aprox)
        // En producción, estos deben calcularse según el fs real (1 / dt)
        float a1_, a2_, b0_, b1_, b2_; 
    };

    class PhaseDetector {
    public:
        PhaseDetector();
        ~PhaseDetector() = default;

        // Determina la fase usando coordenadas suavizadas y ángulos
        core::MovementPhase detectPhase(long time_ms, float hip_y, float knee_angle);
        
        // Permite resetear la máquina de estados
        void reset();

        // Acceso a las cinemáticas actuales para las métricas
        KinematicState getCurrentKinematics() const;

    private:
        core::MovementPhase current_phase_ = core::MovementPhase::IDLE;
        
        ButterworthFilter y_filter_;
        std::vector<KinematicState> history_;
        
        // Parámetros de detección
        const float V_DEADBAND = 0.05f; // m/s (asumiendo y normalizado o en metros)
        const float KNEE_LOCKOUT_ANGLE = 160.0f; 
        const int HOLD_FRAMES = 5;

        int state_hold_counter_ = 0;
        long phase_start_time_ = 0;

        void transitionTo(core::MovementPhase new_phase, long time_ms);
        KinematicState calculateKinematics(long time_ms, float current_y, float knee_angle);
    };

} // namespace biomechanics
} // namespace liftsense

#endif // LIFTSENSE_PHASE_DETECTOR_H

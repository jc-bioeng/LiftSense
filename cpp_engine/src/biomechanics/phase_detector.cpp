#include "phase_detector.h"
#include <cmath>
#include <algorithm>

namespace liftsense {
namespace biomechanics {

    // ==========================================
    // Butterworth Filter Implementation
    // ==========================================
    ButterworthFilter::ButterworthFilter() {
        reset();
        // Fc = 5Hz, Fs = 30Hz
        // Coeficientes precalculados (bilinear transform)
        // b: [0.0976, 0.1953, 0.0976], a: [1.0, -0.9428, 0.3333]
        b0_ = 0.0976f;
        b1_ = 0.1953f;
        b2_ = 0.0976f;
        a1_ = -0.9428f;
        a2_ = 0.3333f;
    }

    void ButterworthFilter::reset() {
        v1_ = 0.0f;
        v2_ = 0.0f;
    }

    float ButterworthFilter::process(float input) {
        float v = input - a1_ * v1_ - a2_ * v2_;
        float output = b0_ * v + b1_ * v1_ + b2_ * v2_;
        v2_ = v1_;
        v1_ = v;
        return output;
    }

    // ==========================================
    // Phase Detector Implementation
    // ==========================================
    PhaseDetector::PhaseDetector() {
        reset();
    }

    void PhaseDetector::reset() {
        current_phase_ = core::MovementPhase::IDLE;
        history_.clear();
        y_filter_.reset();
        state_hold_counter_ = 0;
        phase_start_time_ = 0;
    }

    KinematicState PhaseDetector::getCurrentKinematics() const {
        if (history_.empty()) return {0,0,0,0,0};
        return history_.back();
    }

    void PhaseDetector::transitionTo(core::MovementPhase new_phase, long time_ms) {
        state_hold_counter_++;
        if (state_hold_counter_ >= HOLD_FRAMES) {
            current_phase_ = new_phase;
            phase_start_time_ = time_ms;
            state_hold_counter_ = 0;
        }
    }

    KinematicState PhaseDetector::calculateKinematics(long time_ms, float current_y, float knee_angle) {
        KinematicState st = {current_y, 0.0f, 0.0f, knee_angle, time_ms};
        if (history_.empty()) return st;
        
        const auto& prev = history_.back();
        float dt = (time_ms - prev.time_ms) / 1000.0f; // a segundos
        
        if (dt > 0.001f) {
            st.v_y = (current_y - prev.y_pos) / dt;
            st.a_y = (st.v_y - prev.v_y) / dt;
        } else {
            st.v_y = prev.v_y;
            st.a_y = prev.a_y;
        }
        return st;
    }

    core::MovementPhase PhaseDetector::detectPhase(long time_ms, float hip_y, float knee_angle) {
        // 1. Filtrar ruido de la posición y (MediaPipe jitter)
        float smoothed_y = history_.empty() ? hip_y : y_filter_.process(hip_y);

        // 2. Calcular Cinemática
        KinematicState state = calculateKinematics(time_ms, smoothed_y, knee_angle);
        history_.push_back(state);
        
        if (history_.size() > 50) {
            history_.erase(history_.begin());
        }

        // 3. State Machine Biomecánico
        switch (current_phase_) {
            case core::MovementPhase::IDLE:
                // Si la cadera baja (y aumenta/disminuye dependiendo del sistema de coordenadas)
                // Asumimos que Y desciende físicamente (hacia el suelo), por tanto y_pos disminuye.
                // En MediaPipe de imagen, Y aumenta al ir abajo. Asumamos que está corregido a físico (v_y < 0 es bajar)
                if (state.v_y < -V_DEADBAND && state.knee_angle < KNEE_LOCKOUT_ANGLE) {
                    transitionTo(core::MovementPhase::DESCENDING, time_ms);
                } else {
                    state_hold_counter_ = 0;
                }
                break;
                
            case core::MovementPhase::DESCENDING:
                // Llegamos al bottom cuando la velocidad vertical frena (v_y se acerca a 0) y hay aceleración positiva
                if (state.v_y >= -V_DEADBAND && state.a_y > 0) {
                    transitionTo(core::MovementPhase::BOTTOM, time_ms);
                } else {
                    state_hold_counter_ = 0;
                }
                break;
                
            case core::MovementPhase::BOTTOM:
                // Salimos del bottom cuando la velocidad ascendente es clara (v_y > 0)
                if (state.v_y > V_DEADBAND) {
                    transitionTo(core::MovementPhase::ASCENDING, time_ms);
                } else {
                    state_hold_counter_ = 0;
                }
                break;
                
            case core::MovementPhase::ASCENDING:
                // Si la velocidad cae drásticamente a cerca de 0 pero la rodilla no está extendida: Sticking Point
                if (state.v_y < V_DEADBAND && state.knee_angle < KNEE_LOCKOUT_ANGLE) {
                    transitionTo(core::MovementPhase::STICKING_POINT, time_ms);
                }
                // Si la rodilla se bloquea y la velocidad se estabiliza cerca a 0: Lockout (IDLE)
                else if (state.knee_angle >= KNEE_LOCKOUT_ANGLE && std::abs(state.v_y) < V_DEADBAND) {
                    transitionTo(core::MovementPhase::IDLE, time_ms);
                } else {
                    state_hold_counter_ = 0;
                }
                break;

            case core::MovementPhase::STICKING_POINT:
                // Si recupera la velocidad ascendente, vuelve a ASCENDING
                if (state.v_y > V_DEADBAND) {
                    transitionTo(core::MovementPhase::ASCENDING, time_ms);
                }
                // Si la rodilla se bloquea (termina el levantamiento de alguna forma)
                else if (state.knee_angle >= KNEE_LOCKOUT_ANGLE) {
                    transitionTo(core::MovementPhase::IDLE, time_ms);
                } else {
                    state_hold_counter_ = 0;
                }
                break;
        }

        return current_phase_;
    }

} // namespace biomechanics
} // namespace liftsense

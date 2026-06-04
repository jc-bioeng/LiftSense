#ifndef LIFTSENSE_KINEMATICS_SOLVER_H
#define LIFTSENSE_KINEMATICS_SOLVER_H

#include "../core/models.h"

namespace liftsense {
namespace biomechanics {

    class KinematicsSolver {
    public:
        KinematicsSolver() = default;

        // Calcula todos los ángulos geométricos según la vista
        core::JointAngles calculateAngles(const core::PoseFrame& pose, core::ViewType view);

    private:
        float calculateAngleWithVertical(const core::Landmark& top, const core::Landmark& bottom);
        float calculate3PointAngle(const core::Landmark& a, const core::Landmark& b, const core::Landmark& c);
        
        // Memoria histórica para derivadas (Butt Wink y HKR)
        float prev_hip_angle_ = 0.0f;
        float prev_knee_angle_ = 0.0f;
        float prev_trunk_angle_ = 0.0f;
        long prev_time_ms_ = 0;
        
        // Calcula heurística de pérdida de rigidez torácica
        float calculateButtWinkProbability(float current_trunk, float current_hip, float dt);
        
        // Distancia Horizontal proxy relativa (requiere que el frame ya esté normalizado en FLU)
        float calculateMomentArmProxy(const core::Landmark& joint, float gravity_line_x);
    };

} // namespace biomechanics
} // namespace liftsense

#endif // LIFTSENSE_KINEMATICS_SOLVER_H

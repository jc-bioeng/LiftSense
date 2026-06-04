#include "kinematics_solver.h"
#include <cmath>

namespace liftsense {
namespace biomechanics {

    float KinematicsSolver::calculateAngleWithVertical(const core::Landmark& top, const core::Landmark& bottom) {
        float dx = top.x - bottom.x;
        float dy = top.y - bottom.y; // Asumiendo Y crece hacia abajo en la imagen
        // Ángulo con respecto al eje Y vertical
        return std::atan2(std::abs(dx), std::abs(dy)) * 180.0f / M_PI;
    }

    float KinematicsSolver::calculate3PointAngle(const core::Landmark& a, const core::Landmark& b, const core::Landmark& c) {
        float ab_x = a.x - b.x;
        float ab_y = a.y - b.y;
        float cb_x = c.x - b.x;
        float cb_y = c.y - b.y;

        float dot = (ab_x * cb_x + ab_y * cb_y);
        float cross = (ab_x * cb_y - ab_y * cb_x);

        float alpha = std::atan2(cross, dot);
        return std::abs(alpha * 180.0f / M_PI);
    }

    float KinematicsSolver::calculateMomentArmProxy(const core::Landmark& joint, float gravity_line_x) {
        // Distancia horizontal absoluta. Como las coordenadas ya están normalizadas por CoordinateNormalizer (FLU),
        // este valor ya representa una fracción de la longitud del fémur.
        return std::abs(joint.x - gravity_line_x);
    }

    float KinematicsSolver::calculateButtWinkProbability(float current_trunk, float current_hip, float dt) {
        if (dt <= 0.0f || prev_trunk_angle_ == 0.0f) return 0.0f;
        
        // Butt wink se caracteriza por una flexión lumbar repentina (pérdida de rigidez torácica)
        // mientras la cadera entra en flexión profunda.
        float trunk_velocity = (current_trunk - prev_trunk_angle_) / dt;
        float hip_velocity = (current_hip - prev_hip_angle_) / dt;
        
        // Heurística: Si el tronco cede bruscamente hacia adelante o colapsa el ángulo relativo de la pelvis.
        // Probabilidad crece si el trunk_velocity es inusualmente alto respecto al hip_velocity en profundidad.
        float ratio = std::abs(trunk_velocity) / (std::abs(hip_velocity) + 0.1f);
        
        float probability = 0.0f;
        if (ratio > 2.0f && current_hip < 70.0f) { // < 70 grados = flexión profunda
            probability = std::fmin(1.0f, (ratio - 2.0f) * 0.2f);
        }
        return probability;
    }

    core::JointAngles KinematicsSolver::calculateAngles(const core::PoseFrame& pose, core::ViewType view) {
        core::JointAngles angles = {0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f};

        // Si no hay suficientes landmarks, abortar cálculo
        if (pose.landmarks.size() < 29) return angles;

        const auto& left_hip = pose.landmarks[23];
        const auto& right_hip = pose.landmarks[24];
        const auto& left_knee = pose.landmarks[25];
        const auto& right_knee = pose.landmarks[26];
        const auto& left_ankle = pose.landmarks[27];
        const auto& right_ankle = pose.landmarks[28];
        const auto& left_shoulder = pose.landmarks[11];
        const auto& right_shoulder = pose.landmarks[12];

        // Calcular ángulos básicos
        angles.left_knee = calculate3PointAngle(left_hip, left_knee, left_ankle);
        angles.right_knee = calculate3PointAngle(right_hip, right_knee, right_ankle);
        angles.left_hip = calculate3PointAngle(left_shoulder, left_hip, left_knee);
        angles.right_hip = calculate3PointAngle(right_shoulder, right_hip, right_knee);

        // Trunk Angle & Tibia Angle (Lateral predominante)
        if (view == core::ViewType::LATERAL) {
            // Usando lado visible (ej. Derecho si la cámara enfoca el perfil derecho)
            angles.trunk_flexion = calculateAngleWithVertical(right_shoulder, right_hip);
            angles.tibia_angle = calculateAngleWithVertical(right_knee, right_ankle);
            
            // COM Projection
            angles.com_projection = pose.com_x; // Ya está normalizado relativo al mid_foot(0)
            
            // Moment Arms (Clinical Proxies via FLU)
            // La línea de gravedad se asume que pasa por el mid_foot (x=0 en local_pose)
            angles.lumbar_loading_proxy = calculateMomentArmProxy(right_hip, pose.mid_foot_x);
            angles.patellofemoral_stress_proxy = calculateMomentArmProxy(right_knee, pose.mid_foot_x);

            // Butt Wink Heuristic Probability
            float dt = (pose.time_ms - prev_time_ms_) / 1000.0f;
            angles.butt_wink_probability = calculateButtWinkProbability(angles.trunk_flexion, angles.right_hip, dt);
            
            // Hip/Knee Ratio (Dominance Index Factor)
            if (dt > 0.001f && prev_hip_angle_ > 0) {
                float d_hip = std::abs(angles.right_hip - prev_hip_angle_);
                float d_knee = std::abs(angles.right_knee - prev_knee_angle_);
                if (d_knee > 0.5f) { // Evitar division por cero o muy pequeño
                    angles.hip_knee_ratio = d_hip / d_knee;
                }
            } else {
                angles.hip_knee_ratio = 1.0f;
            }
        } 
        else if (view == core::ViewType::FRONTAL) {
            // Valgus (3D proyectado a plano Frontal)
            angles.valgus_angle = calculate3PointAngle(right_hip, right_knee, right_ankle); 
            angles.com_projection = pose.com_x; // Sway lateral
            angles.lumbar_loading_proxy = 0.0f;
            angles.patellofemoral_stress_proxy = 0.0f;
            angles.butt_wink_probability = 0.0f;
        }

        prev_hip_angle_ = angles.right_hip;
        prev_knee_angle_ = angles.right_knee;
        prev_trunk_angle_ = angles.trunk_flexion;
        prev_time_ms_ = pose.time_ms;

        return angles;
    }

} // namespace biomechanics
} // namespace liftsense

#include "coordinate_normalizer.h"
#include <cmath>

namespace liftsense {
namespace biomechanics {

    CoordinateNormalizer::CoordinateNormalizer() {
        reset();
    }

    void CoordinateNormalizer::reset() {
        scale_reference_ = 1.0f;
        stable_origin_ = {0.0f, 0.0f, 0.0f, 0.0f};
        is_origin_initialized_ = false;
        perspective_confidence_ = 1.0f;
    }

    void CoordinateNormalizer::initializeScale(const core::PoseFrame& setup_pose) {
        // En un esqueleto MediaPipe, estimar la longitud del fémur
        // Usualmente: cadera (23/24) a rodilla (25/26). Asumimos 24 y 26 como lado derecho
        if (setup_pose.landmarks.size() > 26) {
            float dx = setup_pose.landmarks[24].x - setup_pose.landmarks[26].x;
            float dy = setup_pose.landmarks[24].y - setup_pose.landmarks[26].y;
            float femur_len = std::sqrt(dx*dx + dy*dy);
            if (femur_len > 0.0f) {
                scale_reference_ = femur_len;
            }
        }
    }

    core::PoseFrame CoordinateNormalizer::compensateDrift(const core::PoseFrame& raw) {
        core::PoseFrame local = raw;

        // 1. Determinar Origen
        float origin_x = 0.0f;
        float origin_y = 0.0f; // Asumiremos 0 en y si no hay ancla vertical estable, o el mismo mid_foot_y
        
        if (raw.mid_foot_x != 0.0f) {
            origin_x = raw.mid_foot_x;
        } else if (raw.heel_x != 0.0f) {
            origin_x = raw.heel_x;
        } else if (raw.foot_index_x != 0.0f) {
            origin_x = raw.foot_index_x;
        }

        // 2. Filtro EMA pesado en el ancla para estabilizar (Drift Elimination)
        if (!is_origin_initialized_) {
            stable_origin_.x = origin_x;
            is_origin_initialized_ = true;
        } else {
            // alpha = 0.05 para anclar fuertemente al piso y absorber saltos de cámara
            float alpha = 0.05f;
            stable_origin_.x = (alpha * origin_x) + ((1.0f - alpha) * stable_origin_.x);
        }

        // 3. Traslación al origen local
        for (auto& lm : local.landmarks) {
            lm.x -= stable_origin_.x;
        }
        local.com_x -= stable_origin_.x;
        local.mid_hip_x -= stable_origin_.x;
        local.mid_foot_x -= stable_origin_.x; 
        local.heel_x -= stable_origin_.x;
        local.foot_index_x -= stable_origin_.x;

        // 4. Normalización espacial (Convertir a unidades relativas al fémur)
        // Esto previene que zoom in/out afecten las distancias lineales
        if (scale_reference_ > 0.0f && scale_reference_ != 1.0f) {
            for (auto& lm : local.landmarks) {
                lm.x /= scale_reference_;
                lm.y /= scale_reference_; // Importante para normalizar profundidades
            }
            local.com_x /= scale_reference_;
            local.com_y /= scale_reference_;
            local.mid_hip_x /= scale_reference_;
            local.mid_hip_y /= scale_reference_;
        }

        return local;
    }

} // namespace biomechanics
} // namespace liftsense

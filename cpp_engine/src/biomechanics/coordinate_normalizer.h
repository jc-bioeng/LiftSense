#ifndef LIFTSENSE_COORDINATE_NORMALIZER_H
#define LIFTSENSE_COORDINATE_NORMALIZER_H

#include "../core/models.h"

namespace liftsense {
namespace biomechanics {

    class CoordinateNormalizer {
    public:
        CoordinateNormalizer();
        
        // Define la escala a partir del frame inicial (SETUP)
        void initializeScale(const core::PoseFrame& setup_pose);

        // Aplica Drift Compensation y Normalización
        core::PoseFrame compensateDrift(const core::PoseFrame& raw);

        void reset();

    private:
        float scale_reference_ = 1.0f;
        core::Landmark stable_origin_;
        bool is_origin_initialized_ = false;
        
        // Heurística de perspectiva
        float perspective_confidence_ = 1.0f;
    };

} // namespace biomechanics
} // namespace liftsense

#endif // LIFTSENSE_COORDINATE_NORMALIZER_H

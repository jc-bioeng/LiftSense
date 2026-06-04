#ifndef LIFTSENSE_ENGINE_H
#define LIFTSENSE_ENGINE_H

#include "../core/models.h"
#include "../metrics/imetrics.h"
#include "phase_detector.h"
#include "filters.h"
#include "coordinate_normalizer.h"
#include "kinematics_solver.h"
#include <memory>
#include <vector>

namespace liftsense {
namespace biomechanics {

    class BiomechanicalEngine {
    public:
        BiomechanicalEngine(int viewType);
        ~BiomechanicalEngine() = default;

        // Procesa un frame individual y devuelve las métricas completas
        core::BiomechanicalMetrics processFrame(const core::PoseFrame& raw_pose);

        // Procesa un lote completo (para la carga de CSV offline)
        std::vector<core::BiomechanicalMetrics> processBatch(const std::vector<core::PoseFrame>& poses);

    private:
        core::ViewType view_type_;
        
        // Pipeline modules
        PoseFilterBank filter_bank_;
        CoordinateNormalizer normalizer_;
        KinematicsSolver kinematics_solver_;
        std::unique_ptr<PhaseDetector> phase_detector_;
        std::unique_ptr<metrics::IMetricsCalculator> metrics_calculator_;

        bool is_initialized_ = false;
    };

} // namespace biomechanics
} // namespace liftsense

#endif // LIFTSENSE_ENGINE_H

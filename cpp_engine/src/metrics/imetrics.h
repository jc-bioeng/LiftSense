#ifndef LIFTSENSE_IMETRICS_H
#define LIFTSENSE_IMETRICS_H

#include "../core/models.h"

namespace liftsense {
namespace metrics {

    class IMetricsCalculator {
    public:
        virtual ~IMetricsCalculator() = default;

        // Calcula métricas específicas de la vista a partir de la pose, ángulos en bruto y la fase actual
        virtual core::BiomechanicalMetrics calculate(
            const core::PoseFrame& pose, 
            const core::JointAngles& baseAngles, 
            core::MovementPhase currentPhase
        ) = 0;
    };

} // namespace metrics
} // namespace liftsense

#endif // LIFTSENSE_IMETRICS_H

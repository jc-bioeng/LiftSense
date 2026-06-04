#ifndef LIFTSENSE_LATERAL_METRICS_H
#define LIFTSENSE_LATERAL_METRICS_H

#include "imetrics.h"

namespace liftsense {
namespace metrics {

    class LateralMetricsCalculator : public IMetricsCalculator {
    public:
        LateralMetricsCalculator() = default;
        ~LateralMetricsCalculator() override = default;

        core::BiomechanicalMetrics calculate(
            const core::PoseFrame& pose, 
            const core::JointAngles& baseAngles, 
            core::MovementPhase currentPhase
        ) override;

    private:
        float calculateHipHinge(const core::JointAngles& angles);
        float calculateTrunkAngle(const core::PoseFrame& pose);
        float calculateDepth(const core::JointAngles& angles);
    };

} // namespace metrics
} // namespace liftsense

#endif // LIFTSENSE_LATERAL_METRICS_H

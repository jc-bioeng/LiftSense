#ifndef LIFTSENSE_FRONTAL_METRICS_H
#define LIFTSENSE_FRONTAL_METRICS_H

#include "imetrics.h"

namespace liftsense {
namespace metrics {

    class FrontalMetricsCalculator : public IMetricsCalculator {
    public:
        FrontalMetricsCalculator() = default;
        ~FrontalMetricsCalculator() override = default;

        core::BiomechanicalMetrics calculate(
            const core::PoseFrame& pose, 
            const core::JointAngles& baseAngles, 
            core::MovementPhase currentPhase
        ) override;
        
    private:
        float calculateDynamicValgus(const core::PoseFrame& pose);
        float calculateAsymmetry(const core::JointAngles& angles);
    };

} // namespace metrics
} // namespace liftsense

#endif // LIFTSENSE_FRONTAL_METRICS_H

#include "frontal_metrics.h"
#include <cmath>

namespace liftsense {
namespace metrics {

    core::BiomechanicalMetrics FrontalMetricsCalculator::calculate(
        const core::PoseFrame& pose, 
        const core::JointAngles& baseAngles, 
        core::MovementPhase currentPhase) {
        
        core::BiomechanicalMetrics metrics;
        metrics.angles = baseAngles;
        metrics.phase = currentPhase;
        
        // Calcular Valgo Dinámico (Frontal)
        metrics.angles.valgus_angle = calculateDynamicValgus(pose);
        
        // Estabilidad: Usando COM como referencia primaria y Mid-Hip como secundaria
        float stability_reference_x = pose.com_x;
        
        // Si COM no es válido o no está presente, hacer fallback al Mid-Hip
        if (stability_reference_x == 0.0f && pose.mid_hip_x != 0.0f) {
            stability_reference_x = pose.mid_hip_x;
        }
        
        // El asymmetry_index representa qué tan alejado está la referencia de la línea central (mid_foot_x)
        if (pose.mid_foot_x != 0.0f) {
            metrics.asymmetry_index = stability_reference_x - pose.mid_foot_x;
        } else {
            metrics.asymmetry_index = 0.0f;
        }

        // Detección de Riesgo: Si el valgo es severo o la asimetría es muy alta durante el ascenso
        metrics.is_risk_detected = false;
        if (currentPhase == core::MovementPhase::ASCENDING || currentPhase == core::MovementPhase::BOTTOM) {
            // Ejemplo de umbral de riesgo clínico (los valores reales dependen del modelo antropométrico)
            if (std::abs(metrics.angles.valgus_angle) > 15.0f || std::abs(metrics.asymmetry_index) > 0.1f) {
                metrics.is_risk_detected = true;
            }
        }

        return metrics;
    }

    float FrontalMetricsCalculator::calculateDynamicValgus(const core::PoseFrame& pose) {
        // Cálculo geométrico del ángulo Q / Valgo dinámico
        // En una implementación real, sería arccos del producto punto entre los vectores Femur y Tibia proyectados al plano frontal.
        return 5.0f; // Mock
    }

    float FrontalMetricsCalculator::calculateAsymmetry(const core::JointAngles& angles) {
        return std::abs(angles.left_knee - angles.right_knee);
    }

} // namespace metrics
} // namespace liftsense

#include "engine.h"
#include "../metrics/frontal_metrics.h"
#include "../metrics/lateral_metrics.h"
#include <cmath>

namespace liftsense {
namespace biomechanics {

    BiomechanicalEngine::BiomechanicalEngine(int viewType) {
        if (viewType == 1) { // 1 = Frontal
            view_type_ = core::ViewType::FRONTAL;
            metrics_calculator_ = std::make_unique<metrics::FrontalMetricsCalculator>();
        } else { // 2 = Lateral
            view_type_ = core::ViewType::LATERAL;
            metrics_calculator_ = std::make_unique<metrics::LateralMetricsCalculator>();
        }
        
        phase_detector_ = std::make_unique<PhaseDetector>();
    }

    core::BiomechanicalMetrics BiomechanicalEngine::processFrame(const core::PoseFrame& raw_pose) {
        // 0. Inicialización de escala si es el primer frame
        if (!is_initialized_) {
            normalizer_.initializeScale(raw_pose);
            is_initialized_ = true;
        }

        // 1. Filtrado de Ruido (1-Euro) y preprocesamiento de confidencia
        core::PoseFrame filtered_pose = filter_bank_.processFrame(raw_pose);

        // 2. Compensación de Deriva (Drift) y Normalización de Escala
        core::PoseFrame local_pose = normalizer_.compensateDrift(filtered_pose);

        // 3. Resolución Geométrica y Cinemática
        core::JointAngles angles = kinematics_solver_.calculateAngles(local_pose, view_type_);

        // 4. Detector de Fases (usando la posición suavizada y anclada)
        core::MovementPhase currentPhase = phase_detector_->detectPhase(
            local_pose.time_ms, 
            local_pose.com_y, 
            angles.left_knee // o right_knee, dependiendo de la vista lateral
        );

        // 5. Cálculo de Métricas y Riesgos
        core::BiomechanicalMetrics result = metrics_calculator_->calculate(local_pose, angles, currentPhase);

        // Incorporar cinemáticas del phase detector
        KinematicState kin = phase_detector_->getCurrentKinematics();
        result.vertical_velocity = kin.v_y;
        
        return result;
    }

    std::vector<core::BiomechanicalMetrics> BiomechanicalEngine::processBatch(const std::vector<core::PoseFrame>& poses) {
        std::vector<core::BiomechanicalMetrics> results;
        results.reserve(poses.size());
        
        phase_detector_->reset();
        filter_bank_.reset();
        normalizer_.reset();
        is_initialized_ = false;
        
        for (const auto& pose : poses) {
            results.push_back(processFrame(pose));
        }
        
        return results;
    }

} // namespace biomechanics
} // namespace liftsense

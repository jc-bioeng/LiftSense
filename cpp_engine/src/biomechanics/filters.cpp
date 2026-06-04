#include "filters.h"
#include <cmath>

namespace liftsense {
namespace biomechanics {

    // =======================================
    // One-Euro Filter
    // =======================================
    OneEuroFilter::OneEuroFilter(double freq, double mincutoff, double beta, double dcutoff)
        : freq_(freq), mincutoff_(mincutoff), beta_(beta), dcutoff_(dcutoff), 
          x_prev_(0), dx_prev_(0), t_prev_(-1.0), first_time_(true) {}

    void OneEuroFilter::reset() {
        first_time_ = true;
        t_prev_ = -1.0;
    }

    double OneEuroFilter::alpha(double cutoff) {
        double te = 1.0 / freq_;
        double tau = 1.0 / (2.0 * M_PI * cutoff);
        return 1.0 / (1.0 + tau / te);
    }

    float OneEuroFilter::filter(float x, double timestamp) {
        if (first_time_) {
            first_time_ = false;
            x_prev_ = x;
            dx_prev_ = 0.0;
            t_prev_ = timestamp;
            return x;
        }

        double dt = (timestamp - t_prev_) / 1000.0; // asumiendo time_ms
        if (dt <= 0) dt = 1.0 / freq_; // fallback
        
        // freq_ se actualiza dinámicamente según el dt real
        freq_ = 1.0 / dt;
        t_prev_ = timestamp;

        // Estimar velocidad
        double dx = (x - x_prev_) / dt;
        
        // Filtrar velocidad
        double edx = alpha(dcutoff_) * dx + (1.0 - alpha(dcutoff_)) * dx_prev_;
        dx_prev_ = edx;

        // Calcular cutoff adaptativo
        double cutoff = mincutoff_ + beta_ * std::abs(edx);

        // Filtrar posición
        double ex = alpha(cutoff) * x + (1.0 - alpha(cutoff)) * x_prev_;
        x_prev_ = ex;

        return static_cast<float>(ex);
    }

    // =======================================
    // Pose Filter Bank
    // =======================================
    PoseFilterBank::PoseFilterBank() {
        // Configuraciones base del 1-Euro. beta pequeño reduce jitter pero puede añadir ligero lag
        // Si hay mucho movimiento rápido, aumentar beta.
    }

    void PoseFilterBank::reset() {
        landmark_filters_.clear();
        last_valid_landmarks_.clear();
        com_x_filter_.reset();
        com_y_filter_.reset();
    }

    core::PoseFrame PoseFilterBank::processFrame(const core::PoseFrame& raw_pose) {
        core::PoseFrame clean_pose = raw_pose;

        for (size_t i = 0; i < raw_pose.landmarks.size(); ++i) {
            const auto& raw_lm = raw_pose.landmarks[i];
            
            // Si el confidence es mayor al umbral, procesamos y guardamos memoria
            if (raw_lm.conf >= 0.5f) {
                // Initialize filters lazily if needed
                if (landmark_filters_.find(i) == landmark_filters_.end()) {
                    landmark_filters_[i] = {
                        OneEuroFilter(30.0, 1.0, 0.005, 1.0),
                        OneEuroFilter(30.0, 1.0, 0.005, 1.0),
                        OneEuroFilter(30.0, 1.0, 0.005, 1.0)
                    };
                }

                auto& filters = landmark_filters_[i];
                clean_pose.landmarks[i].x = filters.x_filter.filter(raw_lm.x, raw_pose.time_ms);
                clean_pose.landmarks[i].y = filters.y_filter.filter(raw_lm.y, raw_pose.time_ms);
                clean_pose.landmarks[i].z = filters.z_filter.filter(raw_lm.z, raw_pose.time_ms);
                
                last_valid_landmarks_[i] = clean_pose.landmarks[i];
            } else {
                // MISSING LANDMARK: Imputar último válido si existe
                if (last_valid_landmarks_.find(i) != last_valid_landmarks_.end()) {
                    clean_pose.landmarks[i] = last_valid_landmarks_[i];
                    clean_pose.landmarks[i].conf = 0.0f; // Marcar como interpolado
                }
            }
        }

        // Filtrar COM también
        if (clean_pose.com_x != 0.0f) {
            clean_pose.com_x = com_x_filter_.filter(raw_pose.com_x, raw_pose.time_ms);
            clean_pose.com_y = com_y_filter_.filter(raw_pose.com_y, raw_pose.time_ms);
        }

        return clean_pose;
    }

} // namespace biomechanics
} // namespace liftsense

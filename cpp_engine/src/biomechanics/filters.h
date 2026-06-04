#ifndef LIFTSENSE_FILTERS_H
#define LIFTSENSE_FILTERS_H

#include "../core/models.h"
#include <map>

namespace liftsense {
namespace biomechanics {

    // One-Euro Filter Implementation para Landmarks
    class OneEuroFilter {
    public:
        OneEuroFilter(double freq = 30.0, double mincutoff = 1.0, double beta = 0.0, double dcutoff = 1.0);
        float filter(float x, double timestamp);
        void reset();

    private:
        double freq_;
        double mincutoff_;
        double beta_;
        double dcutoff_;
        
        double x_prev_;
        double dx_prev_;
        double t_prev_;
        bool first_time_;

        double alpha(double cutoff);
    };

    class PoseFilterBank {
    public:
        PoseFilterBank();
        // Filtra un frame completo. Aplica imputación si conf es bajo.
        core::PoseFrame processFrame(const core::PoseFrame& raw_pose);
        void reset();

    private:
        // Mantenemos un filtro por coordenada por landmark
        struct LandmarkFilters {
            OneEuroFilter x_filter;
            OneEuroFilter y_filter;
            OneEuroFilter z_filter;
        };
        
        std::map<int, LandmarkFilters> landmark_filters_;
        OneEuroFilter com_x_filter_;
        OneEuroFilter com_y_filter_;
        
        // Memoria para imputación
        std::map<int, core::Landmark> last_valid_landmarks_;
    };

} // namespace biomechanics
} // namespace liftsense

#endif // LIFTSENSE_FILTERS_H

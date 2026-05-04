/**
 * coordinate_mapper.cpp — Video→Viewport coordinate transformation.
 * 
 * Implements the same "cover" scaling as Flutter's FittedBox(fit: BoxFit.cover):
 *   scale = max(viewport_w/video_w, viewport_h/video_h)
 *   offset = (viewport - video*scale) / 2
 */

#include "coordinate_mapper.h"

#include <algorithm>
#include <cmath>

namespace liftsense {

void CoordinateMapper::configure(float video_w, float video_h,
                                  float viewport_w, float viewport_h) {
    if (video_w <= 0 || video_h <= 0 || viewport_w <= 0 || viewport_h <= 0) {
        scale_ = 1.0f;
        offset_x_ = 0.0f;
        offset_y_ = 0.0f;
        return;
    }

    // BoxFit.contain: scale up until the video fits the viewport without cropping
    scale_ = std::min(viewport_w / video_w, viewport_h / video_h);
    
    // Center the video in the viewport (pillarbox/letterbox)
    offset_x_ = (viewport_w - video_w * scale_) / 2.0f;
    offset_y_ = (viewport_h - video_h * scale_) / 2.0f;
}

void CoordinateMapper::map_point(float video_x, float video_y,
                                  float& out_x, float& out_y) const {
    out_x = video_x * scale_ + offset_x_;
    out_y = video_y * scale_ + offset_y_;
}

} // namespace liftsense

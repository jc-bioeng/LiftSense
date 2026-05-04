/**
 * coordinate_mapper.h — Video-space to viewport-space coordinate transformation.
 */

#ifndef LIFTSENSE_COORDINATE_MAPPER_H
#define LIFTSENSE_COORDINATE_MAPPER_H

namespace liftsense {

/**
 * Coordinate mapper that implements the same "cover" scaling as
 * Flutter's FittedBox(fit: BoxFit.cover).
 * 
 * Given a video of size (video_w × video_h) displayed in a viewport
 * of size (viewport_w × viewport_h), computes the scale and offset
 * to center-crop the video to fill the viewport.
 */
class CoordinateMapper {
public:
    CoordinateMapper() = default;

    /**
     * Configure the mapper for a specific video→viewport transform.
     * Must be called before map_point().
     */
    void configure(float video_w, float video_h, 
                   float viewport_w, float viewport_h);

    /** Transform a point from video coordinates to viewport coordinates. */
    void map_point(float video_x, float video_y,
                   float& out_x, float& out_y) const;

    float scale() const { return scale_; }

private:
    float scale_ = 1.0f;
    float offset_x_ = 0.0f;
    float offset_y_ = 0.0f;
};

} // namespace liftsense

#endif // LIFTSENSE_COORDINATE_MAPPER_H

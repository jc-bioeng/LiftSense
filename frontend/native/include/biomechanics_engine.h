/**
 * biomechanics_engine.h — Joint angle computation and center of mass estimation.
 * 
 * Production C++ port of the key calculations from python_research/core/biomechanics.py.
 * Python remains the research/truth source; this is the on-device runtime version.
 */

#ifndef LIFTSENSE_BIOMECHANICS_ENGINE_H
#define LIFTSENSE_BIOMECHANICS_ENGINE_H

#include "csv_parser.h"

namespace liftsense {

/** Result of biomechanical analysis for a single frame. */
struct BiomechanicsResult {
    float hip_angle = 0.0f;
    float knee_angle = 0.0f;
    float ankle_angle = 0.0f;
    float trunk_angle = 0.0f;
    float com_x = 0.0f;
    float com_y = 0.0f;
    bool  valid = false;
};

/**
 * Compute the angle at vertex B formed by segments BA and BC.
 * Returns angle in degrees [0, 180].
 * Returns -1 if any point is invalid.
 */
float compute_joint_angle(const RawPoint& a, const RawPoint& vertex, const RawPoint& b,
                          float conf_threshold = 0.45f);

/**
 * Compute segmental center of mass using Dempster's method (Winter normalization).
 * Matches the Python BiomechanicsEngine._estimate_center_of_mass().
 * 
 * @param frame           Frame with raw points
 * @param conf_threshold  Minimum confidence for inclusion
 * @param out_x, out_y    Output center of mass coordinates
 * @return true if CoM was computed (at least one segment visible)
 */
bool compute_center_of_mass(const FrameRecord& frame, float conf_threshold,
                            float& out_x, float& out_y);

/**
 * Run full biomechanical analysis on a frame.
 * Computes hip, knee, ankle, and trunk angles plus CoM.
 */
BiomechanicsResult analyze_frame(const FrameRecord& frame, float conf_threshold = 0.45f);

/**
 * Compute angular velocity via finite differences.
 * @param angle_prev Previous angle in degrees
 * @param angle_curr Current angle in degrees
 * @param dt_ms      Time delta in milliseconds
 * @return Angular velocity in degrees/second
 */
float compute_angular_velocity(float angle_prev, float angle_curr, float dt_ms);

} // namespace liftsense

#endif // LIFTSENSE_BIOMECHANICS_ENGINE_H

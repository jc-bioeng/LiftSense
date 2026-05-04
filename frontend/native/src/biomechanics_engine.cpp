/**
 * biomechanics_engine.cpp — Joint angle and CoM computation.
 * 
 * Production C++ port of python_research/core/biomechanics.py.
 * Implements:
 *   - Joint angle calculation (3-point angle at vertex)
 *   - Segmental center of mass (Dempster/Winter normalization)
 *   - Angular velocity via finite differences
 * 
 * Node indices (matching csv_parser.h kNodeNames):
 *   0=nose, 1=l_shoulder, 2=r_shoulder, 3=l_elbow, 4=r_elbow,
 *   5=l_wrist, 6=r_wrist, 7=l_hip, 8=r_hip, 9=l_knee, 10=r_knee,
 *   11=l_ankle, 12=r_ankle, 13=l_heel, 14=r_heel, 15=l_foot_index, 16=r_foot_index
 */

#include "biomechanics_engine.h"

#include <cmath>

namespace liftsense {

namespace {

constexpr float kPI = 3.14159265358979323846f;

// Check if a point meets the confidence threshold
inline bool valid(const RawPoint& p, float thresh) {
    return p.confidence > thresh;
}

// Midpoint of two points (for bilateral segments)
inline RawPoint midpoint(const RawPoint& a, const RawPoint& b) {
    return {
        (a.x + b.x) / 2.0f,
        (a.y + b.y) / 2.0f,
        std::min(a.confidence, b.confidence)
    };
}

} // anonymous namespace

float compute_joint_angle(const RawPoint& a, const RawPoint& vertex, const RawPoint& b,
                          float conf_threshold) {
    if (!valid(a, conf_threshold) || !valid(vertex, conf_threshold) || !valid(b, conf_threshold)) {
        return -1.0f;
    }

    // Vectors from vertex to a and b
    float va_x = a.x - vertex.x;
    float va_y = a.y - vertex.y;
    float vb_x = b.x - vertex.x;
    float vb_y = b.y - vertex.y;

    // Dot product and magnitudes
    float dot = va_x * vb_x + va_y * vb_y;
    float mag_a = std::sqrt(va_x * va_x + va_y * va_y);
    float mag_b = std::sqrt(vb_x * vb_x + vb_y * vb_y);

    if (mag_a < 1e-6f || mag_b < 1e-6f) return -1.0f;

    // Clamp to [-1, 1] to avoid NaN from acos
    float cos_angle = dot / (mag_a * mag_b);
    cos_angle = std::max(-1.0f, std::min(1.0f, cos_angle));

    return std::acos(cos_angle) * (180.0f / kPI);
}

bool compute_center_of_mass(const FrameRecord& frame, float conf_threshold,
                            float& out_x, float& out_y) {
    // Dempster segmental analysis (Winter normalization)
    // Weight fractions for major body segments:
    //   Trunk (shoulders→hips): ~0.55
    //   Thighs (hips→knees):    ~0.20
    //   Shanks (knees→ankles):  ~0.12
    //   Upper arms (each):      ~0.065

    struct WeightedPoint {
        float x, y, weight;
    };

    WeightedPoint segments[6]; // max segments
    int count = 0;

    const auto& pts = frame.points;

    // Trunk: midpoint of (l_shoulder+r_shoulder) to midpoint of (l_hip+r_hip)
    // Indices: l_shoulder=1, r_shoulder=2, l_hip=7, r_hip=8
    if (valid(pts[1], conf_threshold) && valid(pts[2], conf_threshold) &&
        valid(pts[7], conf_threshold) && valid(pts[8], conf_threshold)) {
        float mx = (pts[1].x + pts[2].x + pts[7].x + pts[8].x) / 4.0f;
        float my = (pts[1].y + pts[2].y + pts[7].y + pts[8].y) / 4.0f;
        segments[count++] = {mx, my, 0.55f};
    }

    // Thighs: midpoint of (l_hip+r_hip) to midpoint of (l_knee+r_knee)
    // Indices: l_hip=7, r_hip=8, l_knee=9, r_knee=10
    if (valid(pts[7], conf_threshold) && valid(pts[8], conf_threshold) &&
        valid(pts[9], conf_threshold) && valid(pts[10], conf_threshold)) {
        float mx = (pts[7].x + pts[8].x + pts[9].x + pts[10].x) / 4.0f;
        float my = (pts[7].y + pts[8].y + pts[9].y + pts[10].y) / 4.0f;
        segments[count++] = {mx, my, 0.20f};
    }

    // Shanks: midpoint of (l_knee+r_knee) to midpoint of (l_ankle+r_ankle)
    // Indices: l_knee=9, r_knee=10, l_ankle=11, r_ankle=12
    if (valid(pts[9], conf_threshold) && valid(pts[10], conf_threshold) &&
        valid(pts[11], conf_threshold) && valid(pts[12], conf_threshold)) {
        float mx = (pts[9].x + pts[10].x + pts[11].x + pts[12].x) / 4.0f;
        float my = (pts[9].y + pts[10].y + pts[11].y + pts[12].y) / 4.0f;
        segments[count++] = {mx, my, 0.12f};
    }

    // Upper arms (optional — each side independently)
    // Left arm: l_shoulder=1, l_elbow=3
    if (valid(pts[1], conf_threshold) && valid(pts[3], conf_threshold)) {
        float mx = (pts[1].x + pts[3].x) / 2.0f;
        float my = (pts[1].y + pts[3].y) / 2.0f;
        segments[count++] = {mx, my, 0.065f};
    }
    // Right arm: r_shoulder=2, r_elbow=4
    if (valid(pts[2], conf_threshold) && valid(pts[4], conf_threshold)) {
        float mx = (pts[2].x + pts[4].x) / 2.0f;
        float my = (pts[2].y + pts[4].y) / 2.0f;
        segments[count++] = {mx, my, 0.065f};
    }

    if (count == 0) return false;

    float total_w = 0.0f;
    float sum_x = 0.0f, sum_y = 0.0f;
    for (int i = 0; i < count; i++) {
        sum_x += segments[i].x * segments[i].weight;
        sum_y += segments[i].y * segments[i].weight;
        total_w += segments[i].weight;
    }

    out_x = sum_x / total_w;
    out_y = sum_y / total_w;
    return true;
}

BiomechanicsResult analyze_frame(const FrameRecord& frame, float conf_threshold) {
    BiomechanicsResult result;
    const auto& pts = frame.points;

    // Hip angle: shoulder → hip → knee
    // Using right side primarily: r_shoulder=2, r_hip=8, r_knee=10
    // Fallback to left: l_shoulder=1, l_hip=7, l_knee=9
    result.hip_angle = compute_joint_angle(pts[2], pts[8], pts[10], conf_threshold);
    if (result.hip_angle < 0) {
        result.hip_angle = compute_joint_angle(pts[1], pts[7], pts[9], conf_threshold);
    }

    // Knee angle: hip → knee → ankle
    // Right: r_hip=8, r_knee=10, r_ankle=12
    result.knee_angle = compute_joint_angle(pts[8], pts[10], pts[12], conf_threshold);
    if (result.knee_angle < 0) {
        result.knee_angle = compute_joint_angle(pts[7], pts[9], pts[11], conf_threshold);
    }

    // Ankle angle: knee → ankle → foot_index
    // Right: r_knee=10, r_ankle=12, r_foot_index=16
    result.ankle_angle = compute_joint_angle(pts[10], pts[12], pts[16], conf_threshold);
    if (result.ankle_angle < 0) {
        result.ankle_angle = compute_joint_angle(pts[9], pts[11], pts[15], conf_threshold);
    }

    // Trunk angle: vertical reference vs shoulder→hip
    // Approximate: nose(0) → midpoint(shoulders) → midpoint(hips)
    if (valid(pts[0], conf_threshold) && 
        valid(pts[1], conf_threshold) && valid(pts[2], conf_threshold) &&
        valid(pts[7], conf_threshold) && valid(pts[8], conf_threshold)) {
        RawPoint mid_sh = midpoint(pts[1], pts[2]);
        RawPoint mid_hip = midpoint(pts[7], pts[8]);
        result.trunk_angle = compute_joint_angle(pts[0], mid_sh, mid_hip, 0.0f);
    }

    // Center of mass
    result.valid = compute_center_of_mass(frame, conf_threshold, 
                                           result.com_x, result.com_y);

    return result;
}

float compute_angular_velocity(float angle_prev, float angle_curr, float dt_ms) {
    if (dt_ms <= 0.0f) return 0.0f;
    return (angle_curr - angle_prev) / (dt_ms / 1000.0f);
}

} // namespace liftsense

/**
 * ffi_api.cpp — extern "C" entry points for Dart FFI.
 * 
 * This is the ONLY file that exposes symbols to the Dart side.
 * It orchestrates the internal C++ modules (csv_parser, frame_query,
 * coordinate_mapper, biomechanics_engine) behind a stable C ABI.
 * 
 * Thread safety: All functions assume single-threaded access from the
 * Dart main isolate. The engine holds internal state via static globals.
 */

#include "liftsense_core.h"
#include "csv_parser.h"
#include "frame_query.h"
#include "coordinate_mapper.h"
#include "biomechanics_engine.h"

#include <vector>
#include <string>
#include <cstring>

#ifdef __ANDROID__
#include <android/log.h>
#define LOG_TAG "LiftsenseFFI"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)
#else
#include <cstdio>
#define LOGI(...) fprintf(stdout, __VA_ARGS__)
#define LOGE(...) fprintf(stderr, __VA_ARGS__)
#endif

// ─── Internal State ─────────────────────────────────────────
namespace {

bool g_initialized = false;
std::vector<liftsense::FrameRecord> g_frames;
liftsense::CoordinateMapper g_mapper;
float g_video_w = 1080.0f;
float g_video_h = 1920.0f;

// Connection topology — matches the Dart SkeletonPainterView exactly
struct ConnectionDef {
    int from;
    int to;
    int group; // 0=torso, 1=arms, 2=legs
};

static constexpr ConnectionDef kConnections[LS_MAX_CONNECTIONS] = {
    // Torso (group 0)
    {0, 1, 0}, {0, 2, 0}, {1, 2, 0},
    // Arms (group 1)
    {1, 3, 1}, {3, 5, 1}, {2, 4, 1}, {4, 6, 1},
    // Torso hips (group 0)
    {1, 7, 0}, {2, 8, 0}, {7, 8, 0},
    // Legs (group 2)
    {7, 9, 2}, {9, 11, 2}, {8, 10, 2}, {10, 12, 2},
    // Feet (group 2)
    {11, 13, 2}, {13, 15, 2}, {11, 15, 2},
    {12, 14, 2}, {14, 16, 2}, {12, 16, 2},
};

} // anonymous namespace

// ─── API Implementation ─────────────────────────────────────

extern "C" {

EXPORT int32_t ls_init(const char* csv_path, float video_w, float video_h) {
    if (g_initialized) {
        LOGE("ls_init: Already initialized. Call ls_dispose() first.");
        return -3;
    }

    if (!csv_path) {
        LOGE("ls_init: null csv_path");
        return -1;
    }

    g_video_w = video_w;
    g_video_h = video_h;

    int result = liftsense::parse_csv(std::string(csv_path), g_frames);
    if (result < 0) {
        LOGE("ls_init: CSV parse failed with code %d", result);
        return result;
    }

    g_initialized = true;
    LOGI("ls_init: Loaded %d frames from %s (video %.0fx%.0f)", 
         result, csv_path, video_w, video_h);
    return result;
}

EXPORT void ls_dispose(void) {
    g_frames.clear();
    g_frames.shrink_to_fit();
    g_initialized = false;
    LOGI("ls_dispose: Engine released");
}

EXPORT LsTrackInfo ls_get_info(void) {
    LsTrackInfo info;
    memset(&info, 0, sizeof(info));

    if (!g_initialized || g_frames.empty()) return info;

    info.frame_count = static_cast<int32_t>(g_frames.size());
    info.first_timestamp_ms = g_frames.front().timestamp_ms;
    info.last_timestamp_ms = g_frames.back().timestamp_ms;
    info.video_width = g_video_w;
    info.video_height = g_video_h;
    return info;
}

EXPORT LsFrameResult ls_query_frame(
    int32_t timestamp_ms,
    float viewport_width,
    float viewport_height,
    float conf_threshold
) {
    LsFrameResult result;
    memset(&result, 0, sizeof(result));
    result.num_points = LS_MAX_NODES;
    result.num_connections = LS_MAX_CONNECTIONS;

    if (!g_initialized || g_frames.empty()) {
        result.status = -1;
        return result;
    }

    // ── 1. Find nearest frame by timestamp (O(log n)) ──────
    int idx = liftsense::find_frame_index(g_frames, timestamp_ms);
    if (idx < 0) {
        result.status = -2;
        return result;
    }

    result.status = 0;
    result.frame_index = idx;
    result.timestamp_ms = g_frames[idx].timestamp_ms;

    // ── 2. Configure coordinate mapper ─────────────────────
    g_mapper.configure(g_video_w, g_video_h, viewport_width, viewport_height);

    // ── 3. Transform all points to viewport space ──────────
    const auto& frame = g_frames[idx];
    for (int i = 0; i < LS_MAX_NODES; i++) {
        const auto& raw = frame.points[i];
        result.points[i].confidence = raw.confidence;

        if (raw.confidence > conf_threshold) {
            float vx, vy;
            g_mapper.map_point(raw.x, raw.y, vx, vy);
            result.points[i].x = vx;
            result.points[i].y = vy;
            result.points[i].valid = 1;
        } else {
            result.points[i].valid = 0;
        }
    }

    // ── 4. Copy connection topology ────────────────────────
    for (int i = 0; i < LS_MAX_CONNECTIONS; i++) {
        result.connections[i].from_idx = kConnections[i].from;
        result.connections[i].to_idx = kConnections[i].to;
        result.connections[i].group = kConnections[i].group;
    }

    return result;
}

EXPORT LsBiomechanicsResult ls_compute_biomechanics(int32_t frame_index) {
    LsBiomechanicsResult result;
    memset(&result, 0, sizeof(result));

    if (!g_initialized || frame_index < 0 || 
        frame_index >= static_cast<int32_t>(g_frames.size())) {
        result.status = -1;
        return result;
    }

    auto bio = liftsense::analyze_frame(g_frames[frame_index]);
    result.status = bio.valid ? 0 : -1;
    result.hip_angle = bio.hip_angle;
    result.knee_angle = bio.knee_angle;
    result.ankle_angle = bio.ankle_angle;
    result.trunk_angle = bio.trunk_angle;
    result.com_x = bio.com_x;
    result.com_y = bio.com_y;

    // Angular velocities — need previous frame
    if (frame_index > 0) {
        auto prev = liftsense::analyze_frame(g_frames[frame_index - 1]);
        float dt = static_cast<float>(
            g_frames[frame_index].timestamp_ms - g_frames[frame_index - 1].timestamp_ms
        );
        if (dt > 0 && prev.valid) {
            result.knee_velocity = liftsense::compute_angular_velocity(
                prev.knee_angle, bio.knee_angle, dt);
            result.hip_velocity = liftsense::compute_angular_velocity(
                prev.hip_angle, bio.hip_angle, dt);
        }
    }

    return result;
}

/**
 * Buffer-based variant of ls_query_frame for reliable Dart FFI interop.
 * Writes the LsFrameResult into a caller-provided buffer, avoiding
 * ABI-dependent struct-return conventions.
 * 
 * Buffer layout (532 bytes):
 *   [0..19]   5 × int32: status, frame_index, timestamp_ms, num_points, num_connections
 *   [20..291] 17 × LsPoint2D: each 16 bytes (3 floats + 1 int32)
 *   [292..531] 20 × LsConnection: each 12 bytes (3 int32s)
 * 
 * @param out_buf  Pre-allocated buffer, minimum 532 bytes
 */
EXPORT void ls_query_frame_buf(
    void* out_buf,
    int32_t timestamp_ms,
    float viewport_width,
    float viewport_height,
    float conf_threshold
) {
    LsFrameResult result = ls_query_frame(timestamp_ms, viewport_width, 
                                           viewport_height, conf_threshold);
    memcpy(out_buf, &result, sizeof(LsFrameResult));
}

/**
 * Buffer-based variant of ls_compute_biomechanics.
 * @param out_buf  Pre-allocated buffer, minimum sizeof(LsBiomechanicsResult) = 36 bytes
 */
EXPORT void ls_compute_biomechanics_buf(void* out_buf, int32_t frame_index) {
    LsBiomechanicsResult result = ls_compute_biomechanics(frame_index);
    memcpy(out_buf, &result, sizeof(LsBiomechanicsResult));
}

EXPORT const char* ls_version(void) {
    return "liftsense_core 1.0.0";
}

} // extern "C"

/**
 * liftsense_core.h
 * 
 * Public C API for the LiftSense Native Biomechanics Engine.
 * All functions use extern "C" linkage for Dart FFI compatibility.
 * 
 * Architecture:
 *   - CSV tracking data is loaded once via ls_init()
 *   - Per-frame queries via ls_query_frame() return pre-transformed
 *     skeleton points mapped to the current viewport coordinates.
 *   - Biomechanical computations via ls_compute_biomechanics()
 *     return joint angles and center of mass.
 *   - All heavy computation happens in C++; Dart only receives results.
 * 
 * Memory: The engine owns all internal state. Call ls_dispose() to free.
 * Thread Safety: NOT thread-safe. Call from a single thread (Dart main isolate).
 */

#ifndef LIFTSENSE_CORE_H
#define LIFTSENSE_CORE_H

#include <stdint.h>

// ─── Symbol Export Macro ────────────────────────────────────
#if defined(_WIN32) || defined(__CYGWIN__)
  #define EXPORT __declspec(dllexport)
#else
  #define EXPORT __attribute__((visibility("default"))) __attribute__((used))
#endif

// ─── Constants ──────────────────────────────────────────────
#define LS_MAX_NODES       17
#define LS_MAX_CONNECTIONS 20

// ─── Data Structures ────────────────────────────────────────

/** A 2D point in viewport coordinates with confidence score. */
typedef struct {
    float x;
    float y;
    float confidence;
    int32_t valid;  // 1 if point passes confidence threshold, 0 otherwise
} LsPoint2D;

/** Connection between two node indices, with group ID for coloring. */
typedef struct {
    int32_t from_idx;
    int32_t to_idx;
    int32_t group;  // 0=torso, 1=arms, 2=legs
} LsConnection;

/**
 * Result of a frame query — contains all data needed to draw one skeleton frame.
 * Points are already transformed to viewport coordinates.
 */
typedef struct {
    int32_t  status;          // 0=ok, -1=no data, -2=out of range
    int32_t  frame_index;     // Resolved frame index in the CSV
    int32_t  timestamp_ms;    // Actual timestamp of the resolved frame
    int32_t  num_points;      // Always LS_MAX_NODES (17)
    int32_t  num_connections;  // Always LS_MAX_CONNECTIONS (20)
    LsPoint2D points[LS_MAX_NODES];
    LsConnection connections[LS_MAX_CONNECTIONS];
} LsFrameResult;

/** Biomechanical analysis result for a single frame. */
typedef struct {
    int32_t  status;           // 0=ok, -1=no data
    float    hip_angle;        // Degrees
    float    knee_angle;       // Degrees
    float    ankle_angle;      // Degrees
    float    trunk_angle;      // Degrees
    float    com_x;            // Center of mass viewport X
    float    com_y;            // Center of mass viewport Y
    float    knee_velocity;    // Degrees/second
    float    hip_velocity;     // Degrees/second
    float    tibia_angle;      // Degrees relative to vertical
    float    hip_bias;         // Difference (trunk - tibia)
    int32_t  rep_id;           // Current repetition index (1-based, 0 if none)
    int32_t  phase_type;       // Current phase (0=Desc, 1=Bottom, 2=Asc, 3=Lock)
} LsBiomechanicsResult;

/** Summary information about the loaded tracking data. */
typedef struct {
    int32_t  frame_count;
    int32_t  first_timestamp_ms;
    int32_t  last_timestamp_ms;
    float    video_width;
    float    video_height;
} LsTrackInfo;

/** A discrete segment of the movement (phase or repetition). */
typedef struct {
    int32_t start_ms;
    int32_t end_ms;
    int32_t type;   // 0=DESCENDING, 1=BOTTOM, 2=ASCENDING, 3=LOCKOUT
    int32_t rep_id;
} LsSegment;

// ─── API Functions ──────────────────────────────────────────

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Initialize the engine by loading and parsing a CSV tracking file.
 * Must be called before any other function.
 * 
 * @param csv_path  Absolute path to the CSV file (UTF-8)
 * @param video_w   Original video width in pixels (e.g. 1080)
 * @param video_h   Original video height in pixels (e.g. 1920)
 * @return  Number of frames loaded, or negative on error:
 *          -1 = file not found
 *          -2 = parse error
 *          -3 = already initialized (call ls_dispose first)
 */
EXPORT int32_t ls_init(const char* csv_path, float video_w, float video_h);

/**
 * Release all resources. Safe to call multiple times.
 */
EXPORT void ls_dispose(void);

/**
 * Get summary info about the loaded tracking data.
 */
EXPORT LsTrackInfo ls_get_info(void);

/**
 * Query skeleton data for a given video timestamp.
 * Returns points already transformed to viewport coordinates.
 * Uses binary search for O(log n) lookup.
 * 
 * @param timestamp_ms    Current video position in milliseconds
 * @param viewport_width  Current Flutter widget width in logical pixels
 * @param viewport_height Current Flutter widget height in logical pixels
 * @param conf_threshold  Minimum confidence to consider a point valid (e.g. 0.45)
 * @return LsFrameResult with transformed points and connection data
 */
EXPORT LsFrameResult ls_query_frame(
    int32_t timestamp_ms,
    float viewport_width,
    float viewport_height,
    float conf_threshold
);

/**
 * Compute biomechanical metrics for a specific frame index.
 * Can be called after ls_query_frame to get detailed analysis.
 * 
 * @param frame_index  Frame index (0-based, from LsFrameResult.frame_index)
 * @return LsBiomechanicsResult with joint angles and CoM
 */
EXPORT LsBiomechanicsResult ls_compute_biomechanics(int32_t frame_index);

/**
 * Get the version string of the native library.
 * @return Static string, do not free.
 */
EXPORT const char* ls_version(void);

/**
 * Buffer-based variant of ls_query_frame for reliable Dart FFI interop.
 * Writes LsFrameResult into a caller-provided buffer (min 532 bytes).
 */
EXPORT void ls_query_frame_buf(
    void* out_buf,
    int32_t timestamp_ms,
    float viewport_width,
    float viewport_height,
    float conf_threshold
);

/**
 * Get the entire time-series for a specific metric.
 * @param metric_id 0=hip, 1=knee, 2=ankle, 3=trunk, 8=tibia, 9=hip_bias
 * @param out_buf   Caller-provided float buffer
 * @param max_len   Maximum number of floats to write
 * @return Number of floats written, or negative on error.
 */
EXPORT int32_t ls_get_metric_series(int32_t metric_id, float* out_buf, int32_t max_len);

/**
 * Detect repetitions and phases in the loaded movement.
 * @param out_segments Caller-provided LsSegment buffer
 * @param max_len      Maximum number of segments to write
 * @return Number of segments detected, or negative on error.
 */
EXPORT int32_t ls_detect_segments(LsSegment* out_segments, int32_t max_len);

#ifdef __cplusplus
}
#endif

#endif // LIFTSENSE_CORE_H

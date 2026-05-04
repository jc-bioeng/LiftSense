/**
 * csv_parser.h — Internal header for CSV tracking data parser.
 */

#ifndef LIFTSENSE_CSV_PARSER_H
#define LIFTSENSE_CSV_PARSER_H

#include <string>
#include <vector>
#include <cstdint>

namespace liftsense {

/** Raw point from CSV — in video pixel coordinates. */
struct RawPoint {
    float x = 0.0f;
    float y = 0.0f;
    float confidence = 0.0f;
};

/** One row of the CSV — a single frame of tracking data. */
struct FrameRecord {
    int32_t timestamp_ms = 0;
    RawPoint points[17]; // Indexed by node order (see kNodeNames)
};

/** Node name to index mapping, matching the Python tracker output. */
static constexpr int kNumNodes = 17;
static const char* kNodeNames[kNumNodes] = {
    "nose", "l_shoulder", "r_shoulder", "l_elbow", "r_elbow",
    "l_wrist", "r_wrist", "l_hip", "r_hip", "l_knee", "r_knee",
    "l_ankle", "r_ankle", "l_heel", "r_heel", "l_foot_index", "r_foot_index"
};

/**
 * Parse a CSV tracking file into a vector of FrameRecords.
 * 
 * Expected columns: time_ms, {node}_x, {node}_y, {node}_conf
 * Columns can be in any order. Missing columns result in zero-confidence points.
 * Optional z-depth columns ({node}_z) are silently ignored for now.
 * 
 * @param path     Absolute file path (UTF-8)
 * @param frames   Output vector, cleared before use
 * @return         Number of frames parsed, or negative on error
 */
int parse_csv(const std::string& path, std::vector<FrameRecord>& frames);

} // namespace liftsense

#endif // LIFTSENSE_CSV_PARSER_H

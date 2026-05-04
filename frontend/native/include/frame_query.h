/**
 * frame_query.h — Binary search and interpolation for frame lookup by timestamp.
 */

#ifndef LIFTSENSE_FRAME_QUERY_H
#define LIFTSENSE_FRAME_QUERY_H

#include "csv_parser.h"
#include <vector>
#include <cstdint>

namespace liftsense {

/**
 * Find the frame index closest to the given timestamp using binary search.
 * O(log n) complexity.
 * 
 * @param frames        Sorted vector of FrameRecords
 * @param timestamp_ms  Target timestamp in milliseconds
 * @return              Index of the nearest frame, or -1 if frames is empty
 */
int find_frame_index(const std::vector<FrameRecord>& frames, int32_t timestamp_ms);

} // namespace liftsense

#endif // LIFTSENSE_FRAME_QUERY_H

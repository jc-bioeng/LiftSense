/**
 * frame_query.cpp — Binary search for frame lookup by timestamp.
 * 
 * The frames vector is guaranteed to be sorted by timestamp_ms
 * (the CSV is produced frame-by-frame in temporal order by the Python tracker).
 */

#include "frame_query.h"

#include <algorithm>
#include <cstdlib>

namespace liftsense {

int find_frame_index(const std::vector<FrameRecord>& frames, int32_t timestamp_ms) {
    if (frames.empty()) return -1;

    // Binary search for the first frame with timestamp >= target
    int lo = 0;
    int hi = static_cast<int>(frames.size()) - 1;

    while (lo < hi) {
        int mid = lo + (hi - lo) / 2;
        if (frames[mid].timestamp_ms < timestamp_ms) {
            lo = mid + 1;
        } else {
            hi = mid;
        }
    }

    // lo now points to the first frame >= timestamp_ms.
    // Check if the previous frame is actually closer.
    if (lo > 0) {
        int32_t diff_lo = std::abs(frames[lo].timestamp_ms - timestamp_ms);
        int32_t diff_prev = std::abs(frames[lo - 1].timestamp_ms - timestamp_ms);
        if (diff_prev < diff_lo) {
            return lo - 1;
        }
    }

    return lo;
}

} // namespace liftsense

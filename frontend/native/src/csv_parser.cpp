/**
 * csv_parser.cpp — High-performance CSV tracking data parser.
 * 
 * Design decisions:
 *   - Reads entire file into memory buffer for contiguous parsing
 *   - Resolves column indices from header once, then uses direct indexing
 *   - Pre-allocates output vector based on estimated line count
 *   - Tolerant of extra columns (future z-depth, angular data)
 */

#include "csv_parser.h"

#include <fstream>
#include <sstream>
#include <cstring>
#include <algorithm>
#include <cstdlib>

#ifdef __ANDROID__
#include <android/log.h>
#define LOG_TAG "LiftsenseCSV"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)
#else
#include <cstdio>
#define LOGI(...) fprintf(stdout, __VA_ARGS__)
#define LOGE(...) fprintf(stderr, __VA_ARGS__)
#endif

namespace liftsense {

namespace {

// Trim whitespace/CR from a string
std::string trim(const std::string& s) {
    size_t start = s.find_first_not_of(" \t\r\n");
    if (start == std::string::npos) return "";
    size_t end = s.find_last_not_of(" \t\r\n");
    return s.substr(start, end - start + 1);
}

// Split a line by comma, respecting performance
void split_line(const std::string& line, std::vector<std::string>& out) {
    out.clear();
    std::istringstream ss(line);
    std::string token;
    while (std::getline(ss, token, ',')) {
        out.push_back(trim(token));
    }
}

// Fast float parsing (avoids locale issues with strtof)
float fast_float(const char* s) {
    char* end;
    float v = strtof(s, &end);
    return (end != s) ? v : 0.0f;
}

} // anonymous namespace

int parse_csv(const std::string& path, std::vector<FrameRecord>& frames) {
    frames.clear();

    // ─── Read entire file ───────────────────────────────────
    std::ifstream file(path, std::ios::binary);
    if (!file.is_open()) {
        LOGE("CSV: Cannot open file: %s", path.c_str());
        return -1;
    }

    // Get file size for pre-allocation
    file.seekg(0, std::ios::end);
    size_t file_size = static_cast<size_t>(file.tellg());
    file.seekg(0, std::ios::beg);

    std::string content(file_size, '\0');
    file.read(&content[0], file_size);
    file.close();

    // ─── Split into lines ───────────────────────────────────
    std::vector<std::string> lines;
    {
        // Estimate ~50 bytes per line for pre-allocation
        lines.reserve(file_size / 50);
        std::istringstream ss(content);
        std::string line;
        while (std::getline(ss, line)) {
            if (!line.empty() && line.back() == '\r') {
                line.pop_back();
            }
            if (!line.empty()) {
                lines.push_back(std::move(line));
            }
        }
    }

    if (lines.size() < 2) {
        LOGE("CSV: File has fewer than 2 lines");
        return -2;
    }

    // ─── Parse header ───────────────────────────────────────
    std::vector<std::string> header;
    split_line(lines[0], header);

    // Find time_ms column
    int time_ms_col = -1;
    for (int i = 0; i < static_cast<int>(header.size()); i++) {
        if (header[i] == "time_ms") {
            time_ms_col = i;
            break;
        }
    }
    if (time_ms_col < 0) {
        LOGE("CSV: 'time_ms' column not found in header");
        return -2;
    }

    // Build column index map for each node: x, y, conf
    struct NodeColumns {
        int x_col = -1;
        int y_col = -1;
        int conf_col = -1;
    };
    NodeColumns node_cols[kNumNodes];

    for (int i = 0; i < static_cast<int>(header.size()); i++) {
        const std::string& col = header[i];
        for (int n = 0; n < kNumNodes; n++) {
            std::string name(kNodeNames[n]);
            if (col == name + "_x") node_cols[n].x_col = i;
            else if (col == name + "_y") node_cols[n].y_col = i;
            else if (col == name + "_conf") node_cols[n].conf_col = i;
        }
    }

    // ─── Parse data rows ────────────────────────────────────
    frames.reserve(lines.size() - 1);
    std::vector<std::string> parts;
    int num_cols = static_cast<int>(header.size());

    for (size_t i = 1; i < lines.size(); i++) {
        split_line(lines[i], parts);
        if (static_cast<int>(parts.size()) < num_cols) continue;

        FrameRecord record;
        record.timestamp_ms = static_cast<int32_t>(fast_float(parts[time_ms_col].c_str()));

        for (int n = 0; n < kNumNodes; n++) {
            const auto& nc = node_cols[n];
            if (nc.x_col >= 0 && nc.y_col >= 0 && nc.conf_col >= 0) {
                record.points[n].x = fast_float(parts[nc.x_col].c_str());
                record.points[n].y = fast_float(parts[nc.y_col].c_str());
                record.points[n].confidence = fast_float(parts[nc.conf_col].c_str());
            }
        }

        frames.push_back(record);
    }

    LOGI("CSV: Parsed %zu frames from %s", frames.size(), path.c_str());
    return static_cast<int>(frames.size());
}

} // namespace liftsense

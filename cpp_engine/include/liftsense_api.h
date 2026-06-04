#ifndef LIFTSENSE_API_H
#define LIFTSENSE_API_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// ============================================================================
// STRUCTS PARA COMUNICACIÓN FFI (C-API)
// ============================================================================

typedef struct {
    float x;
    float y;
    float z;
    float conf;
} NativeLandmark;

typedef struct {
    int frame_index;
    long time_ms;
    NativeLandmark landmarks[33];
    
    float com_x;
    float com_y;
    float mid_hip_x;
    float mid_hip_y;
    float mid_foot_x;
    float heel_x;
    float foot_index_x;
} NativePoseFrame;

typedef struct {
    float left_knee;
    float right_knee;
    float left_hip;
    float right_hip;
    float trunk_flexion;
    float tibia_angle;
    float valgus_angle;
    float com_projection;
    float hip_knee_ratio;
    float lumbar_loading_proxy;
    float patellofemoral_stress_proxy;
    float butt_wink_probability;
} NativeJointAngles;

typedef struct {
    NativeJointAngles angles;
    int phase;         // 0=IDLE, 1=DESCENDING, 2=BOTTOM, 3=ASCENDING, 4=STICKING, 5=FAIL
    int warning_level; // 0=NONE, 1=LOW, 2=MEDIUM, 3=HIGH, 4=CRITICAL
    float vertical_velocity;
    float asymmetry_index;
    bool is_risk_detected;
} NativeBiomechanicalMetrics;

// ============================================================================
// FUNCIONES EXPUESTAS (FFI BINDINGS)
// ============================================================================

__attribute__((visibility("default"))) __attribute__((used))
void* create_engine(int view_type);

__attribute__((visibility("default"))) __attribute__((used))
void destroy_engine(void* engine_ptr);

__attribute__((visibility("default"))) __attribute__((used))
NativeBiomechanicalMetrics process_frame(void* engine_ptr, NativePoseFrame* frame);

#ifdef __cplusplus
}
#endif

#endif // LIFTSENSE_API_H

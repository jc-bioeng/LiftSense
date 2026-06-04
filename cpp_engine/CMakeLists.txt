cmake_minimum_required(VERSION 3.10)
project(cpp_engine)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED True)

# Definir archivos fuente
set(SOURCES
    src/api/liftsense_api.cpp
    src/biomechanics/engine.cpp
    src/biomechanics/phase_detector.cpp
    src/biomechanics/filters.cpp
    src/biomechanics/coordinate_normalizer.cpp
    src/biomechanics/kinematics_solver.cpp
    src/metrics/frontal_metrics.cpp
    src/metrics/lateral_metrics.cpp
)

# Incluir headers
include_directories(include src)

# Crear librería compartida (shared) para que Flutter FFI pueda cargarla
add_library(cpp_engine SHARED ${SOURCES})

# Opcional: Configuraciones para Android NDK (logging, etc)
if(ANDROID)
    target_link_libraries(cpp_engine log)
endif()

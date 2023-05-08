# Add common test utilities library
add_library(tb_common STATIC
    common/tb_base.cpp
)

target_include_directories(tb_common PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/common
    ${VERILATOR_ROOT}/include
    ${VERILATOR_ROOT}/include/vltstd
)

# Add unit tests
add_subdirectory(unit)

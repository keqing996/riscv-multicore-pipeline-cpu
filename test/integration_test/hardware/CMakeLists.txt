# Hardware Integration Tests - All depend on shared verilated RTL libraries

# Integration tests using chip_top (depend on verilated_chip_top)
function(add_chip_top_integration_test TEST_NAME)
    cmake_parse_arguments(ARG "" "" "SOURCES;LABELS" ${ARGN})
    
    # Create test executable
    add_executable(${TEST_NAME} ${ARG_SOURCES})
    
    # Link with shared verilated chip_top library (NO re-compilation of RTL!)
    target_link_libraries(${TEST_NAME} PRIVATE 
        verilated_chip_top
        tb_common
    )
    
    # Include directories
    target_include_directories(${TEST_NAME} PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/../../common
    )
    
    # Add to CTest with hierarchical naming
    add_test(NAME integration_test/hardware/${TEST_NAME} 
             COMMAND ${TEST_NAME}
             WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR})
    
    # Set test properties
    set_tests_properties(integration_test/hardware/${TEST_NAME} PROPERTIES 
        TIMEOUT 120
        LABELS "integration_test;integration_test.hardware;hardware;${ARG_LABELS}"
    )
    
    message(STATUS "Added integration test: ${TEST_NAME}")
endfunction()

# Backend integration test (depends on verilated_backend)
function(add_backend_integration_test TEST_NAME)
    cmake_parse_arguments(ARG "" "" "SOURCES;LABELS" ${ARGN})
    
    # Create test executable
    add_executable(${TEST_NAME} ${ARG_SOURCES})
    
    # Link with shared verilated backend library
    target_link_libraries(${TEST_NAME} PRIVATE 
        verilated_backend
        tb_common
    )
    
    # Include directories
    target_include_directories(${TEST_NAME} PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/../../common
    )
    
    # Add to CTest with hierarchical naming
    add_test(NAME integration_test/hardware/${TEST_NAME} 
             COMMAND ${TEST_NAME}
             WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR})
    
    # Set test properties
    set_tests_properties(integration_test/hardware/${TEST_NAME} PROPERTIES 
        TIMEOUT 120
        LABELS "integration_test;integration_test.hardware;hardware.backend;${ARG_LABELS}"
    )
    
    message(STATUS "Added integration test: ${TEST_NAME}")
endfunction()

# Add all chip_top integration tests
add_chip_top_integration_test(test_basic_ops
    SOURCES test_basic_ops.cpp
    LABELS "basic"
)

add_chip_top_integration_test(test_arithmetic
    SOURCES test_arithmetic.cpp
    LABELS "arithmetic"
)

add_chip_top_integration_test(test_memory_ops
    SOURCES test_memory_ops.cpp
    LABELS "memory"
)

add_chip_top_integration_test(test_control_flow
    SOURCES test_control_flow.cpp
    LABELS "control_flow"
)

add_chip_top_integration_test(test_forwarding
    SOURCES test_forwarding.cpp
    LABELS "forwarding"
)

add_chip_top_integration_test(test_hazards
    SOURCES test_hazards.cpp
    LABELS "hazards"
)

add_chip_top_integration_test(test_mdu
    SOURCES test_mdu.cpp
    LABELS "mdu"
)

add_chip_top_integration_test(test_csr_rw
    SOURCES test_csr_rw.cpp
    LABELS "csr"
)

add_chip_top_integration_test(test_csr_exception
    SOURCES test_csr_exception.cpp
    LABELS "csr;exception"
)

add_chip_top_integration_test(test_csr_interrupt
    SOURCES test_csr_interrupt.cpp
    LABELS "csr;interrupt"
)

add_chip_top_integration_test(test_csr_mret
    SOURCES test_csr_mret.cpp
    LABELS "csr;mret"
)

# Backend unit test (tests backend module in isolation)
add_backend_integration_test(test_backend
    SOURCES test_backend.cpp
    LABELS "backend"
)

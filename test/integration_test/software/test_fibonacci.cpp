#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include "doctest.h"
#include "chip_top_tb.h"

TEST_CASE("Fibonacci") {
ChipTopTestbench tb;
    
    // Load program binary
    tb.load_binary(PROGRAM_BIN_PATH);
    
    // Reset
    tb.reset();
    
    REQUIRE(tb.run_until_halted(200000));
    CHECK(tb.read_reg(10) == 55);
}

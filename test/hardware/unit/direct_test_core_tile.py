#!/usr/bin/env python3
"""
Direct test of core_tile without pytest wrapper.
This bypasses pytest to see if the issue is with pytest or with VVP/cocotb.
"""
import os
import sys
import subprocess
from pathlib import Path

# Add project to path
project_root = Path(__file__).parent.parent.parent.parent
sys.path.insert(0, str(project_root))

from test.env import get_rtl_dir, get_build_dir

def main():
    print("=" * 70)
    print("Direct Core Tile Test (bypassing pytest)")
    print("=" * 70)
    
    rtl_dir = get_rtl_dir()
    build_dir = get_build_dir() / "test_core_tile_direct"
    build_dir.mkdir(parents=True, exist_ok=True)
    
    # Collect Verilog files
    verilog_sources = (
        list((rtl_dir / "core").rglob("*.v")) +
        list((rtl_dir / "cache").rglob("*.v")) +
        list((rtl_dir / "interconnect").rglob("*.v"))
    )
    
    print(f"Found {len(verilog_sources)} Verilog files")
    
    # Create dump file
    dump_file = build_dir / "dump.v"
    dump_file.write_text("""
module dump_waves;
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, core_tile);
    end
endmodule
""")
    
    # Compile with iverilog
    vvp_file = build_dir / "core_tile.vvp"
    cmd_compile = [
        "iverilog",
        "-o", str(vvp_file),
        "-g2012",
        "-s", "core_tile",
        "-s", "dump_waves",
    ] + [str(f) for f in verilog_sources] + [str(dump_file)]
    
    print("Compiling...")
    result = subprocess.run(cmd_compile, capture_output=True, text=True)
    if result.returncode != 0:
        print("COMPILE FAILED:")
        print(result.stderr)
        return 1
    print("Compilation successful")
    
    # Run VVP without cocotb first
    print("\n--- Test 1: Run VVP without cocotb (should exit immediately) ---")
    result = subprocess.run(
        ["vvp", "-n", str(vvp_file)],
        cwd=build_dir,
        capture_output=True,
        text=True,
        timeout=5
    )
    print("VVP exit code:", result.returncode)
    print("VVP output:", result.stdout[:200] if result.stdout else "(none)")
    
    # Now try with cocotb
    print("\n--- Test 2: Run VVP with cocotb (may hang) ---")
    cocotb_libs = project_root / "venv/lib/python3.13/site-packages/cocotb/libs"
    env = os.environ.copy()
    env["MODULE"] = "test_core_tile"
    env["TOPLEVEL"] = "core_tile"
    env["PYTHONPATH"] = str(project_root)
    
    try:
        result = subprocess.run(
            ["vvp", "-M", str(cocotb_libs), "-m", "libcocotbvpi_icarus", str(vvp_file)],
            cwd=build_dir,
            capture_output=True,
            text=True,
            timeout=10,
            env=env
        )
        print("VVP+cocotb exit code:", result.returncode)
        print("Output (first 500 chars):")
        print(result.stdout[:500] if result.stdout else "(none)")
        if "No tests" in result.stdout or "No tests" in result.stderr:
            print("\n!!! COCOTB CANNOT FIND TESTS !!!")
    except subprocess.TimeoutExpired:
        print("\n!!! VVP+COCOTB HUNG (timeout after 10s) !!!")
        print("This confirms the hang issue")
        return 1
    
    print("\n" + "=" * 70)
    print("Direct test completed")
    return 0

if __name__ == "__main__":
    sys.exit(main())

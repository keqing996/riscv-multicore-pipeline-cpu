import os
import shutil
import subprocess
from pathlib import Path
from typing import List, Optional, Dict, Any, Union

from cocotb_test.simulator import run as cocotb_run

# Root directory
# tests/infrastructure.py -> tests/ -> root
ROOT_DIR = Path(__file__).resolve().parent.parent
RTL_DIR = ROOT_DIR / "rtl"
TESTS_DIR = ROOT_DIR / "tests"
TOOLS_DIR = ROOT_DIR / "tools"
BUILD_DIR = ROOT_DIR / "build"




LINKER_SCRIPT = TESTS_DIR / "software" / "common" / "link.ld"
RISCV_LDFLAGS = ["-T", str(LINKER_SCRIPT)]
HEX_GEN_SCRIPT = TOOLS_DIR / "make_hex.py"

def run_test(
    test_name: str,
    toplevel: str,
    module_name: str,
    verilog_sources: Optional[List[Union[str, Path]]] = None,
    python_search: Optional[List[Union[str, Path]]] = None,
    program_hex_path: Optional[Union[str, Path]] = None,
    **kwargs: Any
) -> None:
    """
    Wrapper around cocotb_test.simulator.run to enforce consistent build directories.
    """
    if verilog_sources is None:
        # Convert Path objects to strings for cocotb
        v_sources = [str(p) for p in VERILOG_SOURCES]
    else:
        v_sources = [str(p) for p in verilog_sources]
        
    if python_search is None:
        p_search = []
    else:
        p_search = [str(p) for p in python_search]
        
    # Centralized build directory: build/<test_name>
    sim_build = BUILD_DIR / test_name

    # Clean up sim_build directory if it exists
    if sim_build.exists():
        shutil.rmtree(sim_build)
    
    # Ensure PYTHONDONTWRITEBYTECODE is passed to the simulator process
    extra_env = kwargs.get("extra_env", {})
    extra_env["PYTHONDONTWRITEBYTECODE"] = "1"
    kwargs["extra_env"] = extra_env

    # Manually generate wave dump module to ensure VCD generation
    sim_build.mkdir(parents=True, exist_ok=True)

    # Copy program.hex if provided
    if program_hex_path:
        src_hex = Path(program_hex_path)
        dst_hex = sim_build / "program.hex"
        if src_hex.exists():
            shutil.copy(src_hex, dst_hex)
        else:
            print(f"Warning: program_hex_path provided but file not found: {src_hex}")

    dump_file = sim_build / f"dump_{test_name}.v"
    
    dump_vars_content = f"        $dumpvars(0, {toplevel});"

    dump_file_content = f"""
module dump_waves;
    initial begin
        $dumpfile("dump.vcd");
{dump_vars_content}
    end
endmodule
"""
    dump_file.write_text(dump_file_content)
    
    v_sources.append(str(dump_file))

    # Remove waves from kwargs if present to avoid conflict
    kwargs.pop("waves", None)

    # Add dump_waves to toplevel to ensure it is simulated
    sim_toplevel = [toplevel, "dump_waves"]

    cocotb_run(
        verilog_sources=v_sources,
        toplevel=sim_toplevel,
        module=module_name,
        python_search=p_search,
        sim_build=str(sim_build),
        waves=False,
        timescale="1ns/1ps",
        **kwargs
    )

def run_test_simple(
    module_name: str,
    toplevel: str,
    rtl_files: List[Union[str, Path]],
    file_path: Union[str, Path],
    **kwargs: Any
) -> None:
    """
    Simplified wrapper for running hardware tests.
    Resolves RTL paths relative to RTL_DIR.
    """
    # Ensure file_path is a Path object
    test_file_path = Path(file_path).resolve()
    tests_dir = test_file_path.parent
    
    # Resolve RTL files, handling both absolute and relative paths
    abs_rtl_files: List[Union[str, Path]] = []
    for f in rtl_files:
        path_f = Path(f)
        if path_f.is_absolute():
            abs_rtl_files.append(str(path_f))
        else:
            abs_rtl_files.append(str(RTL_DIR / path_f))

    run_test(
        test_name=module_name,
        toplevel=toplevel,
        module_name=module_name,
        python_search=[tests_dir],
        verilog_sources=abs_rtl_files,
        **kwargs
    )

def compile_software_test(test_name: str, test_dir: Union[str, Path], output_dir: Union[str, Path]) -> str:
    """Compiles C code to Hex."""
    print(f"Compiling {test_name}...")
    
    test_dir_path = Path(test_dir)
    output_dir_path = Path(output_dir)
    
    # Source files
    srcs = [
        str(test_dir_path / "start.S"),
        str(test_dir_path / "main.c"),
        str(TESTS_DIR / "software" / "common" / "common.c")
    ]
    
    elf_file = output_dir_path / f"{test_name}.elf"
    bin_file = output_dir_path / f"{test_name}.bin"
    hex_file = output_dir_path / "program.hex"
    
    # 1. Compile to ELF
    cmd_compile = [str(RISCV_CC)] + RISCV_CFLAGS + RISCV_LDFLAGS + srcs + ["-o", str(elf_file)]
    subprocess.check_call(cmd_compile)
    
    # 2. Objcopy to Binary
    cmd_objcopy = [str(RISCV_OBJCOPY), "-O", "binary", str(elf_file), str(bin_file)]
    subprocess.check_call(cmd_objcopy)
    
    # 3. Generate Hex
    with open(hex_file, "w") as f:
        subprocess.check_call(["python3", str(HEX_GEN_SCRIPT), str(bin_file)], stdout=f)
        
    return str(hex_file)

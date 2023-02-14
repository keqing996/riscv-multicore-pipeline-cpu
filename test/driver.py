import os
import shutil
import subprocess
from pathlib import Path
from typing import List, Optional, Dict, Any, Union
from test import env
from test.util import toolchain
from test.util import program
from cocotb_test.simulator import run as cocotb_run

def _internal_resolve_path(
        path_list: List[Union[str, Path]], 
        relative_parent: Union[str, Path]
) -> List[str]:
    abs_path_list: List[Union[str, Path]] = []
    for f in path_list:
        path_f = Path(f)
        if path_f.is_absolute():
            abs_path_list.append(str(path_f))
        else:
            abs_path_list.append(str(relative_parent / path_f))
    return abs_path_list

def _internal_run_test(
        build_dir: Path,
        module_name: str,
        verilog_sources: List[Union[str, Path]],
        toplevel: str,
        **kwargs: Any
):
    # Ensure PYTHONDONTWRITEBYTECODE is passed to the simulator process
    extra_env = kwargs.get("extra_env", {})
    extra_env["PYTHONDONTWRITEBYTECODE"] = "1"
    kwargs["extra_env"] = extra_env

    # Resolve RTL files, handling both absolute and relative paths
    abs_rtl_files = _internal_resolve_path(verilog_sources, env.get_rtl_dir())

    # VCD file generator
    dump_file = build_dir / f"dump_{module_name}.v"
    dump_file_content = f"""
module dump_waves;
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, {toplevel});
    end
endmodule
"""
    dump_file.write_text(dump_file_content)

    # Add vcd helper
    abs_rtl_files.append(str(dump_file))

    # Remove waves from kwargs if present to avoid conflict
    kwargs.pop("waves", None)

    # Add dump_waves to toplevel to ensure it is simulated
    sim_toplevel = [toplevel, "dump_waves"]

    # Setup python_search to include test directories
    python_search = kwargs.pop("python_search", [])
    if not isinstance(python_search, list):
        python_search = [python_search]
    
    project_root = env.get_project_root()
    python_search.append(str(project_root))

    # Add all subdirectories under test/ to python_search
    test_root = project_root / "test"
    if test_root.exists():
        python_search.append(str(test_root))
        for root, dirs, files in os.walk(test_root):
            if "__pycache__" in dirs:
                dirs.remove("__pycache__")
            for d in dirs:
                python_search.append(os.path.join(root, d))

    cocotb_run(
        verilog_sources=abs_rtl_files,
        toplevel=sim_toplevel,
        module=module_name,
        python_search=python_search,
        sim_build=str(build_dir),
        waves=False,
        timescale="1ns/1ps",
        **kwargs
    )

def run_hardware_test(
        module_name: str,
        verilog_sources: List[Union[str, Path]],
        toplevel: str,
        **kwargs: Any
) -> None:
    """
    Wrapper around cocotb_test.simulator.run to enforce consistent build directories.
    """
    # Centralized build directory: build/<test_name>
    build_dir = env.get_build_dir() / module_name
    if build_dir.exists():
        shutil.rmtree(build_dir)
    build_dir.mkdir(parents=True, exist_ok=True)

    _internal_run_test(build_dir, module_name, verilog_sources, toplevel, **kwargs)


def run_software_test(
        module_name: str,
        verilog_sources: List[Union[str, Path]],
        c_sources: List[Union[str, Path]],
        c_includes: List[Union[str, Path]],
        toplevel: str,
        **kwargs: Any
) -> None:
    # Centralized build directory: build/<test_name>
    build_dir = env.get_build_dir() / module_name
    if build_dir.exists():
        shutil.rmtree(build_dir)
    build_dir.mkdir(parents=True, exist_ok=True)

    elf_file = build_dir / "program.elf"
    bin_file = build_dir / "program.bin"
    hex_file = build_dir / "program.hex"

    # Resolve C files, handling both absolute and relative paths
    abs_c_sources = _internal_resolve_path(c_sources, env.get_software_dir())
    abs_c_includes = _internal_resolve_path(c_includes, env.get_software_dir())

    # Compile C files
    cmd_compile: List[str] = []
    cmd_compile += [str(toolchain.get_riscv_compiler())]
    cmd_compile += toolchain.get_riscv_cflags(abs_c_includes)
    cmd_compile += [str(env.get_linker_script())]
    cmd_compile += abs_c_sources
    cmd_compile += ["-o", str(elf_file)]
    subprocess.check_call(cmd_compile)

    # Convert ELF to Binary
    cmd_objcopy = [toolchain.get_llvm_objcopy(), "-O", "binary", str(elf_file), str(bin_file)]
    subprocess.check_call(cmd_objcopy)

    # Generate Hex
    program.generate_hex_program(str(bin_file), str(hex_file))

    _internal_run_test(build_dir, module_name, verilog_sources, toplevel, **kwargs)
import os
import shutil
import subprocess
from pathlib import Path
from typing import List, Optional, Dict, Any, Union
from test import env
from cocotb_test.simulator import run as cocotb_run

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

    # Ensure PYTHONDONTWRITEBYTECODE is passed to the simulator process
    extra_env = kwargs.get("extra_env", {})
    extra_env["PYTHONDONTWRITEBYTECODE"] = "1"
    kwargs["extra_env"] = extra_env

    # Resolve RTL files, handling both absolute and relative paths
    abs_rtl_files: List[Union[str, Path]] = []
    for f in verilog_sources:
        path_f = Path(f)
        if path_f.is_absolute():
            abs_rtl_files.append(str(path_f))
        else:
            abs_rtl_files.append(str(env.get_rtl_dir() / path_f))

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
    python_search.append(str(project_root / "test" / "hardware" / "unit"))
    python_search.append(str(project_root / "test" / "hardware" / "integration"))
    python_search.append(str(project_root))

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



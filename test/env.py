
from pathlib import Path
from typing import List, Optional, Dict, Any, Union

def get_project_root() -> Path:
    """Returns project root folder."""
    return Path(__file__).parent.parent

def get_build_dir() -> Path:
    """Returns build directory."""
    return get_project_root() / "build"

def get_rtl_dir() -> Path:
    """Returns rtl directory."""
    return get_project_root() / "rtl"

def get_all_rtl_files() -> List[Path]:
    """Returns a list of all Verilog source files in the RTL directory."""
    return list(get_rtl_dir().rglob("*.v"))

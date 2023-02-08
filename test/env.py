
from pathlib import Path


def get_project_root() -> Path:
    """Returns project root folder."""
    return Path(__file__).parent.parent

def get_build_dir() -> Path:
    """Returns build directory."""
    return get_project_root() / "build"

def get_rtl_dir() -> Path:
    """Returns rtl directory."""
    return get_project_root() / "rtl"
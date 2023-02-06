from pathlib import Path
from typing import List, Dict

# Root directory
# tests/hardware/integration/common.py -> tests/hardware/integration -> tests/hardware -> tests -> root
ROOT_DIR = Path(__file__).resolve().parent.parent.parent.parent
RTL_DIR = ROOT_DIR / "rtl"

def get_rtl_files(subsystem: str = "core") -> List[str]:
    """
    Collect all RTL files for a given subsystem, or all if subsystem is 'all'.
    """
    subsystem_dirs: Dict[str, List[str]] = {
        "core": ["system", "core", "cache", "memory", "peripherals"],
        "backend": ["core/backend", "peripherals"],
    }

    if subsystem == "all":
        return [str(p) for p in RTL_DIR.rglob("*.v")]

    if subsystem not in subsystem_dirs:
        raise ValueError(f"Unknown subsystem: {subsystem}")

    rtl_files: List[str] = []
    for sub_dir in subsystem_dirs[subsystem]:
        # Use rglob for recursive search within the subdirectory
        target_dir = RTL_DIR / sub_dir
        if target_dir.exists():
            rtl_files.extend([str(p) for p in target_dir.rglob("*.v")])
        else:
            # Warn or handle missing directory if necessary, for now just skip
            pass

    return rtl_files

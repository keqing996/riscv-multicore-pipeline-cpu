import os
import glob

# Root directory
ROOT_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
RTL_DIR = os.path.join(ROOT_DIR, "rtl")

def get_rtl_files(subsystem="core"):
    """
    Collect all RTL files for a given subsystem, or all if subsystem is 'all'.
    """
    subsystem_dirs = {
        "core": ["system", "core", "cache", "memory", "peripherals"],
        "backend": ["core/backend", "peripherals"],
    }

    if subsystem == "all":
        return glob.glob(os.path.join(RTL_DIR, "**", "*.v"), recursive=True)

    if subsystem not in subsystem_dirs:
        raise ValueError(f"Unknown subsystem: {subsystem}")

    rtl_files = []
    for sub_dir in subsystem_dirs[subsystem]:
        rtl_files.extend(glob.glob(os.path.join(RTL_DIR, sub_dir, "**", "*.v"), recursive=True))

    return rtl_files

import os
import shutil
import subprocess
from pathlib import Path
from typing import List, Optional, Dict, Any, Union

def collect_all_rtl(rtl_dir: Path) -> List[Path]:
    return list(rtl_dir.rglob("*.v"))

import os
import shutil
from pathlib import Path

_HOMEBREW_LLVM_CLANG = "/opt/homebrew/opt/llvm/bin/clang"
_HOMEBREW_LLVM_OBJCOPY = "/opt/homebrew/opt/llvm/bin/llvm-objcopy"

def get_riscv_compiler() -> str:
    if os.environ.get("RISCV_CC"):
        cc = os.environ["RISCV_CC"]
    elif os.path.exists(_HOMEBREW_LLVM_CLANG):
        cc = _HOMEBREW_LLVM_CLANG
    else:
        cc = shutil.which("clang") or "clang"
    return cc

def get_llvm_objcopy() -> str:
    if os.environ.get("RISCV_OBJCOPY"):
        objcopy = os.environ["RISCV_OBJCOPY"]
    elif os.path.exists(_HOMEBREW_LLVM_OBJCOPY):
        objcopy = _HOMEBREW_LLVM_OBJCOPY
    else:
        objcopy = shutil.which("llvm-objcopy") or "llvm-objcopy"
    return objcopy

def get_riscv_cflags(include_dirs: list[Path] = []):
    riscv_cflags = [
        "--target=riscv32", 
        "-march=rv32i", 
        "-mabi=ilp32",
        "-ffreestanding", 
        "-nostdlib", 
        "-O2", 
        "-g", 
        "-Wall",
    ]

    for include_dir in include_dirs:
        riscv_cflags.append(f"-I{include_dir}")

    return riscv_cflags

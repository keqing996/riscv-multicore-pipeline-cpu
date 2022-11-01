import sys
import os

# Prevent __pycache__ generation - Must be done before importing other modules
sys.dont_write_bytecode = True
os.environ["PYTHONDONTWRITEBYTECODE"] = "1"

import pytest

def main():
    """
    Main entry point for running tests.
    Passes arguments directly to pytest.
    """
    # Default to running all tests in the tests directory if no args provided
    args = sys.argv[1:]
    if not args:
        args = ["tests"]
        
    print(f"Running pytest with args: {args}")
    sys.exit(pytest.main(args))

if __name__ == "__main__":
    main()

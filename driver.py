import sys
import os
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

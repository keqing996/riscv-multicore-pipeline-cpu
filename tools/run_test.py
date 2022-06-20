import argparse
import shutil
import subprocess
import sys
import os

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--vvp', required=True, help="Path to vvp executable")
    parser.add_argument('--sim-dir', required=True, help="Directory where simulation runs")
    parser.add_argument('--sim-file', required=True, help="Compiled VVP file name (e.g. core_tb.vvp)")
    parser.add_argument('--hex', required=True, help="Path to the test hex file")
    parser.add_argument('--name', required=True, help="Name of the test")
    args = parser.parse_args()

    # 1. Prepare: Copy hex file to program.hex in sim-dir
    if not os.path.exists(args.sim_dir):
        print(f"Simulation directory {args.sim_dir} does not exist.")
        sys.exit(1)

    target_hex = os.path.join(args.sim_dir, 'program.hex')
    try:
        shutil.copy(args.hex, target_hex)
    except Exception as e:
        print(f"Error copying hex file: {e}")
        sys.exit(1)

    # 2. Execute: Run VVP
    # We run inside sim-dir so $readmemh("program.hex") works
    cmd = [args.vvp, args.sim_file]
    print(f"Running test '{args.name}' in {args.sim_dir}...")
    
    try:
        result = subprocess.run(
            cmd, 
            cwd=args.sim_dir, 
            capture_output=True, 
            text=True,
            timeout=60 # Timeout after 60 seconds to prevent infinite loops
        )
    except subprocess.TimeoutExpired:
        print("Test FAILED: Simulation timed out.")
        sys.exit(1)
    except Exception as e:
        print(f"Failed to run simulation: {e}")
        sys.exit(1)

    # 3. Verify: Check Output
    print("--- Simulation Output ---")
    print(result.stdout)
    if result.stderr:
        print("--- Simulation Stderr ---")
        print(result.stderr)
    print("-------------------------")

    # Check 1: Return Code
    if result.returncode != 0:
        print(f"Test FAILED: Simulation exited with code {result.returncode}")
        sys.exit(1)

    # Check 2: Explicit Errors
    if "ERROR" in result.stdout:
        print("Test FAILED: Found 'ERROR' in simulation output")
        sys.exit(1)

    # Check 3: Success Indicator
    # We expect at least one "[PASS]" or a specific completion message
    if "[PASS]" not in result.stdout:
         print("Test FAILED: Did not find '[PASS]' indicator in output")
         sys.exit(1)

    print(f"Test '{args.name}' PASSED successfully.")
    sys.exit(0)

if __name__ == "__main__":
    main()

import sys
import time

time.sleep(3)
if "--fail" in sys.argv:
    print("Simulated task failure.", file=sys.stderr)
    sys.exit(1)
print("Placeholder task completed successfully.")

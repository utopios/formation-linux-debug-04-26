#!/usr/bin/env python3
"""Process qui alloue 64 Mo/s jusqu'a etre tue par l'OOM Killer."""
import os
import time

print("PID", os.getpid(), flush=True)

chunks = []
step_mb = 64

while True:
    chunks.append(bytearray(step_mb * 1024 * 1024))
    total = len(chunks) * step_mb
    print(f"alloc {total} MB", flush=True)
    time.sleep(1)

#!/bin/sh
# Educational build. Disables the stack protector and PIE so the classic
# textbook overflow is visible. NEVER build real software this way.
# Targets x86-64 Linux (e.g. your Ubuntu server). Not macOS / Apple Silicon.
cd "$(dirname "$0")"

if [ "$(uname -s)" != "Linux" ] || [ "$(uname -m)" != "x86_64" ]; then
    echo "WARNING: you are on $(uname -s)/$(uname -m), not x86-64 Linux." >&2
    echo "         Run this on your x86-64 Linux server. Continuing anyway..." >&2
    echo >&2
fi

gcc -g -O0 -fno-stack-protector -no-pie -o vuln vuln.c
status=$?
if [ $status -ne 0 ]; then
    echo "build failed (gcc exit $status). Is build-essential installed?" >&2
    echo "  sudo apt-get install build-essential gdb" >&2
    exit $status
fi

echo "Built ./vuln"
./vuln | head -1          # prints win()'s address for reference

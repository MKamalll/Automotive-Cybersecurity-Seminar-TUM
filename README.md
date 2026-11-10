# Securing the Software-Defined Vehicle — TUM Guest Lecture

A ~45-minute guest lecture (+ Q&A) on **automotive cybersecurity** for a
mixed audience of informatics and mechanical-engineering students, built
around a **live stack buffer-overflow exploit** on a toy ECU diagnostic
handler.

**Title:** *Securing the Software-Defined Vehicle — From Attack Surface to
Exploit to Defense*

## Build

```bash
latexmk -pdf Automotive-Security-MKAbozeid.tex
# or run pdflatex twice (second pass fills in the running chapter headers):
pdflatex Automotive-Security-MKAbozeid.tex && pdflatex Automotive-Security-MKAbozeid.tex
```

Output: **`Automotive-Security-MKAbozeid.pdf`**. Sources are split across
`sections/`, shared styling is in `preamble.tex`, and all imagery is in
`figures/`.

## Flow (seven parts, ~37 slides)

1. **Why it matters** — a car is a computer on wheels; four real incidents; the consequences (recalls, settlements, reputation); the 2025 numbers.
2. **Security, in a car** — safety vs. security: two different enemies.
3. **Inside the vehicle** — ECUs, CAN, the gateway as a drawbridge; the attack surface.
4. **From bugs to exploits** — the 7PK taxonomy, why cars still run on C, the stack.
5. **Live demo** — a stack buffer overflow turned into control of an ECU (see `demo/`).
6. **Defense in depth** — layered defenses, the secure SDLC, SAST vs. DAST, vulnerability management.
7. **Rules & process + takeaways** — ISO/SAE 21434, UN R155/R156, TARA; then careers and Q&A.

## Live demo

Everything for the demo lives in `demo/`: the vulnerable C program, the
build and exploit scripts, a one-shot setup script, and
**`demo/gdb-cheatsheet.md`** (handy gdb commands for finding `unlock_ecu`,
proving the 16-byte offset, and watching the overwrite live).

The demo targets **x86-64 Linux** and relies on
`-fno-stack-protector -no-pie`. The overflow only ever redirects execution
to a benign in-binary `unlock_ecu()` routine (a printed "access granted"
banner) — it does **not** spawn a shell or inject code. Build and rehearse
it once before the talk.

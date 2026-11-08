# TUM guest lecture: Cyber Security in Automotive

45-minute lecture (+ Q&A) for informatics and mechanical-engineering
students, intro tutorial (basic security concepts, AppSec, SAST/DAST, 7PK taxonomy).

Build: `latexmk -pdf main.tex` (needs `pgfplots` for the CVE chart).
Sections live in `sections/`, shared styling in `preamble.tex`.

## Structure (9 sections, ~49 slides incl. section dividers)
1. Hook — a car is a computer on wheels (Jeep Cherokee, Tesla, 2022 API hack)
2. Security basics, mapped onto a vehicle; safety vs. security
3. Vehicle architecture — ECUs, CAN, gateway, ADAS, OTA
4. Attack surface — entry points, fob relay, 2022 web-API case, CVE/KEV chart by vendor
5. Regulation — UN R155/R156, ISO/SAE 21434, TARA
6. From bugs to exploits — 7PK condensed, SAST vs DAST, the stack
7. **Live demo** — stack buffer overflow in a toy diagnostic handler (see `demo/`)
8. Defense in depth — mitigations, SBOM/vulnerability management
9. Takeaways, careers, Q&A

## Live demo
See `demo/README.md` for the full walkthrough script. The demo itself
(`demo/diag_handler.c`, `demo/launcher.c`) is built and verified
separately — run `make` inside `demo/` before the talk and rehearse
it once.

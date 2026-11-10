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
        "\n"
        "  >> [ECU] SECURITY ACCESS GRANTED  (no key was ever checked)\n"
        "  >> Immobilizer: OFF    Doors: UNLOCKED    Engine start: ENABLED\n"
        "\n"
        "  unlock_ecu() ran via the overflow -- on a real ECU this routine\n"
        "  should sit behind UDS seed-key authentication.\n\n";
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

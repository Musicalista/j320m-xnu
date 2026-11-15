/*
 * Copyright (c) 2026 Musicalista. All rights reserved.
 * Samsung Galaxy J3 (2016) SM-J320M Darwin / XNU Kernel Entry Trampoline.
 *
 * Implements ARM Linux zImage header contract for Spreadtrum SC9830A U-Boot
 * and sets up early hardware state for Apple Darwin 16.7.0 (iOS 10.3.3).
 */

.syntax unified
.arm
.text

.globl __entry
.globl __start

__entry:
    /* 0x00: Branch past standard Linux header to entry point */
    b       __start
    .space  0x1C

    /* 0x20 - 0x2F: ARM Linux zImage magic and bounds */
    .word   0x00000000                  /* Reserved */
    .word   0x016F2818                  /* Magic: ARM\x01 (zImage identifier) */
    .word   0x80008000                  /* Start address */
    .word   0x80400000                  /* End address */
    .word   0x00000000                  /* Flags */

__start:
    /* 1. Ensure Supervisor (SVC) mode and mask IRQ / FIQ */
    cpsid   if, #0x13

    /* 2. Flush and invalidate Branch Target Cache & TLB */
    mov     r0, #0
    mcr     p15, 0, r0, c8, c7, 0       /* Invalidate Unified TLB */
    mcr     p15, 0, r0, c7, c5, 6       /* Invalidate BTC */
    dsb     sy
    isb     sy

    /*
     * 3. Visual Entry Checkpoint:
     * Paint green bar (0x00FF00) to physical framebuffer 0x9EB74000.
     * Samsung J320M AMOLED: 720x1280 @ 2880 bytes stride.
     */
    ldr     r1, =0x9EB74000             /* Physical Framebuffer Base */
    ldr     r2, =0x0000FF00             /* RGB888 Green */
    mov     r3, #0

    /* Draw 16 rows of green confirmation pixels */
    mov     r4, #16                     /* 16 lines */
line_loop:
    mov     r5, #720                    /* 720 pixels per line */
pix_loop:
    str     r2, [r1, r3]
    add     r3, r3, #4
    subs    r5, r5, #1
    bne     pix_loop
    subs    r4, r4, #1
    bne     line_loop

    /* Push framebuffer dirty lines to RAM via Clean by MVA to PoC */
    mov     r6, #0
flush_loop:
    add     r7, r1, r6
    mcr     p15, 0, r7, c7, c10, 1      /* DCCMVAC */
    add     r6, r6, #64
    cmp     r6, r3
    blo     flush_loop
    dsb     sy

    /*
     * 4. Early Serial UART1 Output:
     * Spreadtrum UART1 at 0x70100000 (115200 8N1).
     */
    ldr     r8, =0x70100000
    adr     r9, boot_banner

uart_banner_loop:
    ldrb    r0, [r9], #1
    cmp     r0, #0
    beq     banner_done

uart_wait_tx:
    ldr     r10, [r8, #0x0C]            /* UART TX FIFO status */
    tst     r10, #0x01                  /* Check TX FIFO full */
    bne     uart_wait_tx

    str     r0, [r8, #0x00]             /* Transmit character */
    b       uart_banner_loop

banner_done:
    /* 5. Set up initial bootstrap stack at top of low memory */
    ldr     sp, =0x80800000

    /* 6. Jump into Darwin C runtime initialization */
    b       _darwin_arm_init

boot_banner:
    .ascii  "\r\n[MAHI68] Darwin/XNU 16.7.0 (iOS 10.3.3) for Galaxy J3 (2016) SM-J320M\r\n"
    .ascii  "SoC: Spreadtrum SC9830A (Cortex-A7 Quad-Core @ 1.5 GHz)\r\n\0"
    .align  4

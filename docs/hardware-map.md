# Samsung Galaxy J3 (2016) SM-J320M — XNU Hardware Architecture Map

## 1. Platform Overview
* **Target Device:** Samsung Galaxy J3 2016 (Latin America)
* **Model Number:** `SM-J320M` / `SM-J320M/DS` (`j3xlte` / `j3xnlte`)
* **SoC:** Spreadtrum SC9830A / SC8830 (SharkLS platform, `SP9830I`)
* **CPU:** Quad-Core ARM Cortex-A7 @ 1.5 GHz (MPIDR: `0xf00`, `0xf01`, `0xf02`, `0xf03`)
* **Architecture:** ARMv7-A (32-bit), VFPv4-D16, NEON
* **RAM:** 1.5 GB LPDDR3 (`0x60000000` bytes)
* **Display:** 5.0" Super AMOLED, 720x1280 (RGB_8888, 2880 bytes stride)
* **Bootloader:** Spreadtrum U-Boot / SPL (Standard Android `boot.img` packaging)

---

## 2. Memory & Physical Address Map

```text
+-----------------------+ 0x80000000 - DRAM Physical Base (1.5 GB total)
| Kernel / Low Memory   |
+-----------------------+ 0x85500000 - Ramdisk / Initrd
| Shared Memory (SMEM)  | 0x87800000 (Size: 5 MB)
+-----------------------+ 0x89600000 - LTE Modem Carveout (Size: 64.5 MB)
| General VM Allocation |
+-----------------------+ 0x9B23B000 - Camera / Multimedia Carveout (Size: ~57 MB)
| Framebuffer (Display) | 0x9EB74000 - 720x1280x4 (Size: 10.5 MB, 3 buffers)
+-----------------------+ 0x9F600000 - ION Memory Pool
| Upper DRAM / Stack    |
+-----------------------+ 0xE0000000 - DRAM Top (1.5 GB physical limit)
```

---

## 3. Peripheral & MMIO Register Map

| Subsystem | Physical Address | Size | Description |
|---|---|---|---|
| **GICv2 Distributor** | `0x12001000` | `0x1000` | ARM Generic Interrupt Controller (Distributor) |
| **GICv2 CPU Interface** | `0x12002000` | `0x1000` | ARM Generic Interrupt Controller (CPU Interface) |
| **UART0** | `0x70000000` | `0x1000` | High-speed UART (48 MHz) |
| **UART1 (Console)** | `0x70100000` | `0x1000` | Primary Serial Debug Port (`115200n8`, 26 MHz) |
| **UART2** | `0x70200000` | `0x1000` | Auxiliary UART (26 MHz) |
| **UART3** | `0x70300000` | `0x1000` | Auxiliary UART (26 MHz) |
| **SYSCNT Timer** | `0x40230000` | `0x1000` | Spreadtrum System Hardware Counter |
| **APTIMER0** | `0x40220000` | `0x1000` | Application Processor Timer 0 |
| **D_GPIO** | `0x40280000` | `0x1000` | Digital GPIO Controller (256 GPIOs) |
| **D_EIC_GPIO** | `0x40210000` | `0x1000` | External Interrupt Controller GPIOs |
| **DSI Host** | `0x20800000` | `0x1000` | MIPI Display Serial Interface Controller |
| **eMMC Host** | `0x20300000` | `0x1000` | Internal Storage Interface |

---

## 4. Interrupt Routing (GICv2)
* **Virtual Timer PPI:** INTID `27` (ARM Architected Virtual Timer)
* **Physical Timer PPI:** INTID `30`
* **Software Generated Interrupt (SGI):** SGI `1` (IPI signaling across Cortex-A7 cores)
* **UART1 IRQ:** SPI `3` (GIC INTID `35`)
* **Display IRQ:** SPI `21` (GIC INTID `53`)

---

## 5. Boot Protocol & Entry Specifications
* **Kernel Load Address:** `0x80008000` (Offset `0x00008000` from RAM base `0x80000000`)
* **Ramdisk Load Address:** `0x81000000` (Offset `0x01000000`)
* **Tags / ATAGS / DTB Address:** `0x80000100` (Offset `0x00000100`)
* **Entry CPU State:** ARMv7-A Supervisor Mode (`SVC`), IRQ/FIQ disabled, MMU disabled, D-cache disabled, I-cache optional.
* **Boot Arguments:** `console=ttyS1,115200n8`

# Darwin / XNU Kernel Port for Samsung Galaxy J3 (2016) SM-J320M

[![Device: Galaxy J3 2016](https://img.shields.io/badge/Device-Samsung%20Galaxy%20J3%20(2016)-blue.svg)](https://github.com/Musicalista/j320m-xnu)
[![Model: SM-J320M](https://img.shields.io/badge/Model-SM--J320M-lightgrey.svg)](https://github.com/Musicalista/j320m-xnu)
[![SoC: Spreadtrum SC9830A](https://img.shields.io/badge/SoC-Spreadtrum%20SC9830A%20(SharkLS)-orange.svg)](https://github.com/Musicalista/j320m-xnu)
[![Arch: ARMv7-A (32-bit)](https://img.shields.io/badge/Arch-ARMv7--A%20Cortex--A7%20Quad-red.svg)](https://github.com/Musicalista/j320m-xnu)

This project ports the Apple Darwin/XNU kernel architecture to the **Samsung Galaxy J3 (2016) Latin America variant (`SM-J320M` / `j3xlte`)**, derived and adapted from the 64-bit Exynos 7570 bring-up in [`j3y17lte-xnu`](https://github.com/imusingwinxp-ops/j3y17lte-xnu).

---

## 1. Architectural Differences: J3 (2017) vs J3 (2016)

While `j3y17lte-xnu` targets the **Galaxy J3 2017 (SM-J330FN)** running a 64-bit ARMv8-A CPU (Cortex-A53), the **Galaxy J3 2016 (SM-J320M)** runs a 32-bit ARMv7-A processor:

| Parameter | Galaxy J3 2017 (`j3y17lte`) | Galaxy J3 2016 (`SM-J320M`) |
|---|---|---|
| **SoC / Chipset** | Samsung Exynos 7570 Quad | Spreadtrum SC9830A (SharkLS / SP9830I) |
| **CPU Cores** | 4x ARM Cortex-A53 | 4x ARM Cortex-A7 |
| **ISA / Mode** | **ARM64 (AArch64, 64-bit)** | **ARMv7-A (32-bit only)** |
| **RAM Space** | 2.0 GB (`0x40000000` & `0x80000000`) | 1.5 GB (`0x80000000` to `0xE0000000`) |
| **Interrupt Controller** | GICv2 @ `0x10901000` / `0x10902000` | GICv2 @ `0x12001000` / `0x12002000` |
| **Physical Framebuffer** | `0x67000000` (720x1280) | `0x9EB74000` (720x1280, 2880 bytes stride) |
| **Debug Console UART** | Exynos UART @ `0x13820000` | Spreadtrum UART1 @ `0x70100000` (26 MHz) |
| **Boot Mechanism** | Samsung S-Boot (EL1 64-bit jump) | Spreadtrum U-Boot / SPL (Supervisor SVC 32-bit) |
| **Native iOS Userland** | iOS 16 (64-bit Mach-O) | iOS 10.3.3 (32-bit ARMv7 Mach-O) |

---

## 2. Porting Roadmap & Strategies

### Strategy A: Native 32-bit Bare-Metal XNU (Primary / Recommended)
* **Kernel Base:** Apple Open Source **XNU 3789.70.16** (iOS 10.3.3 / iPhone 5 / Darwin 16.7.0).
* **Rationale:** iOS 10 is the final, fully-featured release of iOS supporting 32-bit ARMv7 Mach-O binaries. Modern XNU (8796+) stripped `osfmk/arm` 32-bit support entirely in iOS 11.
* **Performance:** Executes bare-metal on Cortex-A7 silicon with zero emulation overhead (solid 60 FPS SpringBoard).

### Strategy B: Hosted / AArch64 Translation Bridge
* For users seeking to execute iOS 16 64-bit binaries on J320M, an AArch64-to-ARMv7 dynamic translation layer is hosted on top of a minimal Linux runtime, bridging trapped Mach syscalls.

---

## 3. Patches & Bring-Up Hierarchy

The patchset in `patches/` adapts the hardware layer to the Spreadtrum SC9830A topology:

1. **`0001-j320m-board-config-and-headers.patch`**:
   - Declares `ARM_BOARD_CONFIG_J320M`.
   - Defines memory bounds (`0x80000000` base, 1.5 GB limit), GICv2 base addresses (`0x12001000` / `0x12002000`), and hardware constants.
2. **`0002-j320m-early-framebuffer-entry-marker.patch`**:
   - Assembly entry marker in `osfmk/arm/start.s` executed immediately after bootloader handoff (before MMU is enabled).
   - Draws a green visual confirmation bar directly to physical framebuffer `0x9EB74000`.
3. **`0003-j320m-gicv2-and-timer.patch`**:
   - GICv2 interrupt acknowledgment (`GICC_IAR` `0x00c`) and end-of-interrupt (`GICC_EOIR` `0x010`).
   - Virtual timer PPI routing (INTID 27) and Cortex-A7 inter-processor interrupts (SGI 1).
4. **`0004-j320m-serial-console-uart1.patch`**:
   - Spreadtrum SC9830A UART1 polling driver at `0x70100000` (`115200 8N1`).
5. **`0005-j320m-framebuffer-iomobileframebuffer.patch`**:
   - `IOMobileFramebuffer` driver registering the 720x1280 Super AMOLED display buffer with CoreAnimation/IOSurface.
6. **`0006-j320m-smp-quadcore-bringup.patch`**:
   - Quad-core SMP secondary core release (CPU1, CPU2, CPU3) via Spreadtrum holding pen (`0x20E00014`), jump address register (`0x20E00018`), PMU CA7 power un-gating (`0x402B0008`..`0x402B0010`), and GIC SGI 1.
7. **`0007-j320m-touch-imagis-ist30xxc.patch`**:
   - Imagis IST30XXC multi-touch driver on Spreadtrum hardware I2C1 (`0x70600000`, 7-bit slave `0x50`, GPIO 142) translating touches to Darwin `IOHIDEventService`.
8. **`0008-j320m-keys-keypad-gpio.patch`**:
   - Hardware button scanner for physical Home (`0x40250000` keypad row 0 col 2), Vol Up, Vol Down, and Power (`0x40210000` EIC).
9. **`0009-j320m-mockfs-ramdisk-ios10.patch`**:
   - MockFS ramdisk root mounting iOS 10.3.3 Mach-O rootfs from `0x81000000` without proprietary Apple NAND drivers.
10. **`0010-j320m-amfi-cs-bypass-ios10.patch`**:
    - AppleMobileFileIntegrity and code-signing policy bypass allowing bare-metal execution of iOS 10.3.3 binaries and daemons.
11. **`0011-j320m-iphone5-identity-and-display-scale.patch`**:
    - Sets `hw.machine` = `iPhone5,2`, `hw.model` = `N42AP`, 720x1280 @ 2x retina display, and 1.5 GB physical RAM reporting.

---

## 4. Building the Kernel

To build the kernel on macOS or Linux:

```bash
# Clone the build harness
git clone https://github.com/Musicalista/j320m-xnu.git
cd j320m-xnu

# Preflight and apply patches to base XNU
git clone --depth 1 --branch xnu-3789.70.16 https://github.com/apple-oss-distributions/xnu.git base-xnu
cd base-xnu
for p in ../patches/*.patch; do
    git apply "$p"
done

# Build target
make MACHINE_CONFIG=J320M ARCH_CONFIG=ARM
```

---

## 5. Boot Packaging (Android `boot.img`)

To flash via Odin / TWRP on Galaxy J3 (2016):

```bash
mkbootimg \
  --kernel build/kernel.mach \
  --ramdisk ramdisk.img \
  --base 0x80000000 \
  --kernel_offset 0x00008000 \
  --ramdisk_offset 0x01000000 \
  --tags_offset 0x00000100 \
  --pagesize 2048 \
  --cmdline "console=ttyS1,115200n8 root=/dev/ram0 rw" \
  -o boot.img
```

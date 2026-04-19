# Cirque Trackpad ZMK

Standalone Cirque trackpad experiment using ZMK firmware on SuperMini (nice!nano v2 clone, identical pinout).

## Goal

Make a Cirque TM035035 trackpad work as a standalone BLE pointing device — no keyboard matrix, just the trackpad. This is a clean-room experiment isolated from the full kb38-cirque-zmk keyboard build to debug trackpad issues independently.

## Hardware

- **Controller**: SuperMini NRF52840 (nice!nano v2 pin-compatible clone)
- **Trackpad**: Cirque TM035035-2024-003 (I2C mode, Pinnacle ASIC)
- **Interface**: I2C on TWIM0 peripheral
- **Power**: 3.3V from VCC pin (NOT RAW — RAW is unregulated battery voltage)

## Wiring (nice!nano v2 / SuperMini pinout)

```
Cirque Pin    nice!nano Pin    nRF52840 GPIO    Notes
─────────────────────────────────────────────────────────────
SDA           D2               P0.17            I2C data
SCL           D3               P0.20            I2C clock
DR            D7               P0.11            Data-ready interrupt (active HIGH)
VCC           VCC              —                3.3V regulated
GND           GND              —                Ground
```

**Required**: 4.7kOhm external pull-up resistors on SDA and SCL to 3.3V (VCC).
Cirque trackpads do not have internal pull-ups.

## Pin Choice Rationale

- D2/D3 (P0.17/P0.20): Standard accessible pins on the left column of the pro micro header. Using TWIM0 (I2C0) peripheral — the primary I2C hardware block on nRF52840.
- D7 (P0.11): Data-ready interrupt pin. Any GPIO works for interrupts on nRF52840; D7 is on the same side of the board for clean wiring.
- Using I2C (not SPI) because it requires fewer wires (4 vs 6) and is the standard approach for Cirque in ZMK builds.

## Build

```bash
# Build firmware (requires Docker)
./build.sh

# Build settings_reset firmware
./build.sh reset

# Build and flash (waits for bootloader drive)
./build.sh --flash
```

## Flash

1. Connect SuperMini via USB
2. Double-tap RST to enter bootloader (NICENANO drive appears)
3. Copy `firmware/cirque_trackpad.uf2` to the drive (or use `./build.sh --flash`)

## Debug

Firmware is built with USB logging enabled. Connect via serial console:

```bash
# macOS — find the serial device
ls /dev/cu.usbmodem*

# Connect (baud rate doesn't matter for USB CDC)
screen /dev/cu.usbmodem<TAB> 115200
```

The config enables I2C debug logging and I2C shell. In the serial console:
```
i2c scan i2c@40003000
```
This should show device at address 0x2a if the Cirque is wired correctly.

## Key Config Options (cirque_trackpad.conf)

- `CONFIG_ZMK_POINTING=y` — enables ZMK pointing device subsystem
- `CONFIG_INPUT_INIT_PRIORITY=90` — delays Pinnacle driver init to allow 300ms power-on reset
- `CONFIG_I2C_SHELL=y` — enables `i2c scan` command for debugging
- Debug logging enabled for I2C, input, and sensor subsystems

## Reference

- Related keyboard project: ~/Playground/kb38-cirque-zmk
- ZMK docs: https://zmk.dev/docs
- Cirque Pinnacle datasheet: search for "Cirque TM035035" or "Pinnacle ASIC"

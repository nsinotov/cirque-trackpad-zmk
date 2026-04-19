# Cirque Trackpad ZMK

Standalone ZMK firmware for testing and debugging a Cirque TM035035 trackpad with a nice!nano v2 controller (SuperMini NRF52840 compatible).

This is a minimal, isolated configuration with no keyboard matrix — just the trackpad and one button for scroll mode. It was created to debug Cirque trackpad issues independently from a full keyboard build.

## Hardware

| Component | Model |
|-----------|-------|
| Controller | nice!nano v2 (nRF52840). SuperMini NRF52840 is pin-compatible and works as a drop-in replacement. |
| Trackpad | Cirque TM035035-2024-003 (I2C, Pinnacle ASIC) |
| Pull-ups | 4.7k-5.1k on SDA and SCL to VCC |

## Wiring

```
nice!nano v2 / SuperMini NRF52840
┌─────────────────────────┐
│                     VCC ●──── Cirque VCC (3.3V)
│                     GND ●──── Cirque GND
│                         │
│  D2  (P0.17)  SDA  ────●──── Cirque SDA  ──┬── 4.7k ── VCC
│  D3  (P0.20)  SCL  ────●──── Cirque SCL  ──┬── 4.7k ── VCC
│  D7  (P0.11)  DR   ────●──── Cirque DR
│                         │
│  D10 (P0.09)  BTN  ────●──── Scroll button ── GND
│                         │
└─────────────────────────┘
```

- **SDA/SCL**: I2C data and clock on TWIM1 peripheral
- **DR**: Data-ready interrupt (active high) — required for event-driven operation
- **BTN**: Optional momentary button for scroll mode (internal pull-up, active low)
- **VCC**: Must be the regulated 3.3V pin, not RAW (unregulated battery)

### Alternative wiring (tested)

The following pinout was also tested and confirmed working — used by the [kb38-cirque-zmk](https://github.com/nsinotov/kb38-cirque-zmk) keyboard:

| Signal | Pin | GPIO |
|--------|-----|------|
| SDA | D18 | P1.15 |
| SCL | D19 | P0.02 |
| DR | D2 | P0.17 |

To use this pinout, update the `pinctrl` and `data-ready-gpios` in the overlay.
**Note:** D20 (P0.29) cannot be used for I2C — the nice!nano battery voltage divider on this pin interferes with I2C communication.

## Issues Found During Debugging

These issues were discovered while bringing up the Cirque trackpad and may help others:

### 1. Pinnacle driver must be explicitly enabled in Kconfig

The device tree alone does not enable the I2C or Pinnacle drivers. Without these lines in `.conf`, the driver silently does nothing — no I2C init, no errors, no log output:

```
CONFIG_I2C=y
CONFIG_INPUT=y
CONFIG_INPUT_PINNACLE=y
```

### 2. I2C0 does not initialize on nice!nano — use I2C1

Using `&i2c0` (TWIM0) produced no I2C activity at all, likely due to a hardware resource conflict with SPIM0 on the nRF52840. Switching to `&i2c1` (TWIM1) with `&spi1` explicitly disabled resolved this.

### 3. Pinnacle init fails if it runs too early

The Cirque trackpad needs ~300ms after power-on before it can accept I2C commands. At the default init priority, the driver fails with:

```
<err> pinnacle: Failed to write reset to SYS_CONFIG1 (-5)
```

Setting `CONFIG_INPUT_INIT_PRIORITY=99` delays init enough for the trackpad to be ready.

### 4. Sensitivity above 2x causes cursor to fly to one corner

With `sensitivity = "4x"` or `"3x"`, touching the trackpad sends the cursor to the bottom-right corner instead of tracking finger movement. `sensitivity = "2x"` works correctly. This may be related to how the Pinnacle driver interprets high-sensitivity absolute coordinate data.

### 5. Y-axis is inverted by default

Finger movement up produces downward cursor movement. Fixed with a `zmk,input-processor-transform` using `INPUT_TRANSFORM_Y_INVERT` on the input listener.

### 6. Cirque Pinnacle uses modified I2C register protocol

Manual I2C debugging via the Zephyr shell requires register address prefixes: `reg | 0x80` for writes, `reg | 0xA0` for reads. Standard register addresses silently fail to write. The ZMK Pinnacle driver handles this internally.

## Build

Requires Docker.

```bash
./build.sh              # Build firmware
./build.sh reset        # Build settings_reset firmware
./build.sh --flash      # Build and flash (waits for bootloader)
```

## Flash

1. Connect controller via USB
2. Double-tap RST to enter bootloader (NICENANO drive appears)
3. Copy `firmware/cirque_trackpad.uf2` to the drive, or use `./build.sh --flash`

## Debug

USB logging is enabled. Connect via serial console:

```bash
screen /dev/cu.usbmodem* 115200
```

I2C shell commands for manual diagnostics:

```bash
i2c scan i2c@40004000                           # Should show device at 0x2a
i2c read_byte i2c@40004000 0x2a 0xa0            # Read FIRMWARE_ID (expect 0x07)
i2c write_byte i2c@40004000 0x2a 0x84 0x01      # Enable data feed
i2c read_byte i2c@40004000 0x2a 0xa2            # Read STATUS register
```

## License

MIT

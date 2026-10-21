# AXI4-Lite SPI Master IP & EDA Automation

A lightweight SPI Master peripheral interfaced to an **AXI4-Lite** slave bus, packaged for the Vivado IP Catalog, and automated via headless Tcl scripting.

---

## Architecture & Register Map

The peripheral exposes four 32-bit memory-mapped registers via an AXI4-Lite slave interface:

| Offset | Register Name | Access | Description |
| :---: | :---: | :---: | :--- |
| `0x0` | `TX_DATA` | Write | Bits [7:0]: Byte to transmit on MOSI |
| `0x4` | `RX_DATA` | **Read-Only** | Bits [7:0]: Byte received from MISO. Software writes are ignored in hardware. |
| `0x8` | `CTRL_STATUS` | Read/Write | Bit [0]: `START` (Rising-edge triggered transfer)<br>Bit [1]: `BUSY` (**Read-Only**, 1 = transfer active) |
| `0xC` | `CLK_DIV` | Write | Prescaler divider for SPI `SCLK` generation |

---

## Key Design Highlights

* **Rising-Edge Triggered Start:** Implements an internal edge detector (`slv_reg2[0] & ~start_d & ~busy`) ensuring exactly one transfer per write.
* **Read-Only Register Protection:** Modified the standard Vivado AXI template write strobe logic to ensure software cannot corrupt hardware-driven status registers (`RX_DATA`, `BUSY`).
* **Self-Checking Testbench:** Implements an internal hardware loopback (`MOSI` → `MISO`), an active watchdog timer to catch stuck handshakes, and explicit assertions for read-only register gating.
* **Tcl Batch Automation:** Headless build flow (`build.tcl`) that sets up the project, runs behavioral simulation, parses the output log, and exits with standard non-zero codes on failure for CI/CD compatibility.

---

## Verification

The testbench verifies two distinct test cases:
1. **SPI Loopback:** Transmits `0xA5` with clock divider 2, polls `BUSY` until 0, and asserts received byte equals `0xA5`.
2. **Read-Only Gating:** Attempts a CPU write of `0xFF` to `0x4` (RX_DATA) and asserts that the stored hardware value remains intact.

---

## One-Command Reproducible Build

To build the project and execute verification headlessly without opening the GUI:

```bash
vivado -mode batch -source scripts/build.tcl

<div align="center">

<img src="https://umsousercontent.com/lib_lnlnuhLgkYnZdkSC/hj0vk05j0kemus1i.png" alt="ChipFoundry Logo" height="140" />

[![Typing SVG](https://readme-typing-svg.demolab.com?font=Inter&size=44&duration=3000&pause=600&color=4C6EF5&center=true&vCenter=true&width=1100&lines=OpenFrame+User+Project+Template;OpenLane+%2B+ChipFoundry+Flow;Verification+and+Shuttle-Ready)](https://git.io/typing-svg)

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![ChipFoundry Marketplace](https://img.shields.io/badge/ChipFoundry-Marketplace-6E40C9.svg)](https://platform.chipfoundry.io/marketplace)

</div>

## Table of Contents
- [Overview](#overview)
- [Documentation & Resources](#documentation--resources)
- [Prerequisites](#prerequisites)
- [Project Structure](#project-structure)
- [Starting Your Project](#starting-your-project)
- [Development Flow](#development-flow)
- [Local Precheck](#local-precheck)
- [Checklist for Shuttle Submission](#checklist-for-shuttle-submission)

## Overview
OpenFrame is a ChipFoundry project template that provides only a bare padframe (no integrated SoC), giving you a 15 mm² user area and 44 GPIOs to design your own custom chip. You are free to implement your design and directly connect it to the available GPIOs throught the pins provided on the openframe wrapper.

---

## Documentation & Resources
For detailed hardware specifications and design guidelines, refer to the following official documents:

* **[ChipFoundry Marketplace](https://platform.chipfoundry.io/marketplace)**: Access additional IP blocks, EDA tools, and shuttle services.

---

## Prerequisites
Ensure your environment meets the following requirements:

1. **Docker** [Linux](https://docs.docker.com/desktop/setup/install/linux/ubuntu/) | [Windows](https://docs.docker.com/desktop/setup/install/windows-install/) | [Mac](https://docs.docker.com/desktop/setup/install/mac-install/)
2. **Python 3.8+** with `pip`.
3. **Git**: For repository management.

---

## Project Structure
A successful OpenFrame project requires a specific directory layout for the automated tools to function:

| Directory | Description |
| :--- | :--- |
| `openlane/` | Configuration files for hardening macros and the wrapper. |
| `verilog/rtl/` | Source Verilog code for the project. |
| `verilog/gl/` | Gate-level netlists (generated after hardening). |
| `verilog/dv/` | Design Verification (cocotb and Verilog testbenches). |
| `ip/` | IPM-installed IPs (for example `CF_gpio_config`). Track `ip/dependencies.json` only. |
| `gds/` | Final GDSII binary files for fabrication. |
| `lef/` | Library Exchange Format files for the macros. |

---

## Starting Your Project

### 1. Repository Setup
Create a new repository based on the `openframe_user_project` template and clone it to your local machine:

```bash
git clone <your-github-repo-URL>
pip install chipfoundry-cli
cd <project_name>
```

### 2. Project Initialization

> [!IMPORTANT]
> Run this first! Initialize your project configuration:

```bash
cf init
```

This creates `.cf/project.json` with project metadata. **This must be run before any other commands**

### 3. Environment Setup
Install the ChipFoundry CLI tool and set up the local environment (PDKs, OpenLane, and OpenFrame):

```bash
cf setup
```

The `cf setup` command installs:

- OpenFrame: The OpenFrame harness template.
- OpenLane: The RTL-to-GDS hardening flow.
- PDK: Skywater 130nm process design kit.
- Timing Scripts: For Static Timing Analysis (STA).
- IPM: The ChipFoundry IP Manager (`cf-ipm`) used to install listed IPs.

### 4. Install IPM dependencies

IPs listed in `ip/dependencies.json` (for example `CF_gpio_config`) are not stored in git. After cloning, install them with:

```bash
ipm install-dep --ip-root ip
```

This is required for GPIO pad configuration and any other IPM-managed blocks in `ip/`.

---

## Development Flow

### Configuring the GPIO pads and power domains

The pad configuration and power domains live in one spec, the `project.openframe` block of
`.cf/project.json`. `cf init` seeds it from `.cf/openframe_default.json`, which reproduces the example
timer pinout:

| Pads | Mode | Signal |
| :--- | :--- | :--- |
| 0 | input | `clk` |
| 1 | input with pull-up | `rst` |
| 2-12 | output | `out[10:0]` |
| 13-43 | analog (unused) | - |

Power: domain `vccd1`/`vssd1`, feeding macro instance `mprj`.

Edit the spec, then regenerate the derived files:

```bash
cf gpio-config                  # 44-pad grid: mode, signal/bus bit, pad overrides, power (p)
cf gpio-config --view           # print the current pinout
cf openframe generate           # regenerate after editing or importing the spec
cf openframe generate --check   # fail if the generated files are stale (useful in CI)
cf openframe export pinout.yaml # standalone YAML/JSON copy, e.g. for review or the web configurator
cf openframe import pinout.yaml # validate and store a YAML/JSON spec, then regenerate
```

Generated files (do not edit by hand; they carry a `spec-sha256` of the spec they came from):

- `verilog/rtl/openframe_gpio.v`: one `CF_gpio_config` instance per pad. Its user ports are named after
  the spec signals (a `bidir` signal `x` becomes `x_in`, `x_out`, `x_oeb`).
- `openlane/openframe_project_wrapper/power.json`: `VDD_NETS`, `GND_NETS` and `PDN_MACRO_CONNECTIONS`
  for the wrapper PDN.

> [!NOTE]
> The current wrapper flow (LibreLane 2.4.x, `config.json`) does not read `power.json` yet; the wrapper
> still uses the single `vccd1`/`vssd1` domain set in `config.json`. Multi-domain power from the spec
> arrives with the LibreLane 3.x wrapper PDN.

`verilog/rtl/openframe_project_wrapper.v` instantiates `openframe_gpio` and wires its named ports to your
macro. When you rename or add signals in the spec, update those connections in the wrapper. Pads in
`analog` mode have no digital signal; use `analog_io[n]` / `analog_noesd_io[n]` on the wrapper directly.

### Hardening the Design
Hardening is the process of synthesizing your RTL and performing Place & Route (P&R) to create a GDSII layout.

#### Macro Hardening
Create a subdirectory for each custom macro under `openlane/` containing your `config.json`.

```bash
cf harden --list         # List detected configurations
cf harden <macro_name>   # Harden a specific macro
```

#### Integration
Instantiate your module(s) in `verilog/rtl/openframe_project_wrapper.v` and connect them to the named
ports of the generated `openframe_gpio` instance (see above).

Update `openlane/openframe_project_wrapper/config.json` environment variables (`VERILOG_FILES_BLACKBOX`, `EXTRA_LEFS`, `EXTRA_GDS_FILES`) to point to your new macros.

#### Wrapper Hardening
Finalize the top-level user project:

```bash
cf harden openframe_project_wrapper
```

### Important Notes

**Connecting to Power:**
   - Ensure your design is connected to power using the power pins on the wrapper.
   - Use the `vccd1_connection` and `vssd1_connection` macros, which contain the necessary vias and nets for power connections.

### Verification

#### 1. Simulation
We use cocotb for functional verification. Ensure your file lists are updated in `verilog/includes/`.

Run RTL Simulation:

```bash
cf verify <test_name>
```

Run Gate-Level (GL) Simulation:

```bash
cf verify <test_name> --sim gl
```

Run all tests:

```bash
cf verify --all
```

---

## Local Precheck
Before submitting your design for fabrication, run the local precheck to ensure it complies with all shuttle requirements:

```bash
cf precheck
```

You can also run specific checks or disable LVS:

```bash
cf precheck --disable-lvs                    # Skip LVS check
cf precheck --checks license --checks makefile  # Run specific checks only
```
---

## Checklist for Shuttle Submission
- [ ] Top-level macro is named openframe_project_wrapper.
- [ ] Full Chip Simulation passes for both RTL and GL.
- [ ] Hardened Macros are LVS and DRC clean.
- [ ] openframe_project_wrapper matches the required pin order/template.
- [ ] Design is properly connected to power (vccd1/vssd1).
- [ ] Design passes the local cf precheck.
- [ ] Documentation (this README) is updated with project-specific details.

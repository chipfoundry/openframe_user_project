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

This creates `.cf/project.json` with project metadata. **This must be run before any other commands.**

If you are logged in (`cf login`) and this repo is not yet linked to the platform, `cf init` asks which platform action to take:

1. **Link to an existing platform project** (the default). Use this when the design is already registered on the [ChipFoundry platform](https://platform.chipfoundry.io). Init lists your projects and stores the one you pick in `.cf/project.json`. Later commands, including submission, use that project. Linking is the default so a second platform project is not created by accident.
2. **Create a new platform project**. Use this the first time you register this design. Init asks you to pick a shuttle and creates a Draft project on the platform.

If you are not logged in, `cf init` only writes the local config. Log in, then run `cf init` again or `cf link`. You can change the link later with `cf link` and `cf unlink`.

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

### Hardening the Design
Hardening is the process of synthesizing your RTL and performing Place & Route (P&R) to create a GDSII layout.

#### Macro Hardening
Create a subdirectory for each custom macro under `openlane/` containing your `config.json`.

```bash
cf harden --list         # List detected configurations
cf harden <macro_name>   # Harden a specific macro
```

#### Integration
Instantiate your module(s) in `verilog/rtl/openframe_project_wrapper.v`.

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
We use cocotb for functional verification. Tests live under `verilog/dv/cocotb/<test_name>/`. The template includes `hello_world` and `timer`, which checks the example 7-segment clock (`verilog/rtl/timer.v`) on GPIOs 0–12.

`cf verify --all` does not discover tests on its own. It runs the list in `verilog/dv/cocotb/user_proj_tests/user_proj_tests.yaml` (and `user_proj_tests_gl.yaml` for gate-level). Add one entry there for each test you want included. Run `cf setup` (cocotb is installed as part of setup) before the first verify.

Run one RTL test:

```bash
cf verify timer
```

Run one Gate-Level (GL) test:

```bash
cf verify timer --sim gl
```

Run every test in the list:

```bash
cf verify --all
cf verify --all --sim gl
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

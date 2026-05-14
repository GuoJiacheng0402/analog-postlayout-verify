# analog-postlayout-verify

> Reproducible post-layout verification scripts for an Operational Amplifier
> (OPA) and a Bandgap Reference (BGR), built on Cadence Spectre and
> Mentor Calibre.

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Python](https://img.shields.io/badge/python-3.6%2B-blue.svg)](#requirements)

- Repository: <https://github.com/GuoJiacheng0402/analog-postlayout-verify>
- Author: **GuoJiacheng** &mdash; <https://github.com/GuoJiacheng0402>
- License: [Apache License 2.0](LICENSE)
- 中文版本: [README.zh-CN.md](README.zh-CN.md)

## Origin

These scripts were originally written by the author for personal use
during the course project of *Principles and Design of Analog Integrated
Circuits*, to make the post-layout verification loop fast and reproducible. 

The code has been refactored so that it no longer depends on a specific
course, server, or PDK install path — all site-specific values are
supplied through `configs/*.json`.

## Overview

Two driver scripts are provided:

- **`scripts/opa_verify.py`** — runs Spectre against the schematic-reference,
  PEX no-R/C, and PEX full R+C netlists of an OPA, and computes
  `Adc`, `GBW`, `PM`, `Idc`, `SR+`, and `SR-`.
- **`scripts/bgr_verify.py`** — runs a Spectre startup-transient temperature
  sweep on the BGR PEX netlist, and computes the reference voltage `Vref`,
  the supply current `Idd`, and the temperature coefficient
  `TC = ΔVref / (mean(Vref) · ΔT) × 1e6` in ppm/°C.

For every invocation, both drivers regenerate fresh testbenches, invoke
Spectre with explicit options (`reltol`, `vabstol`, `iabstol`, `temp`,
`tnom`, …), parse the freshly produced PSF ASCII raw data, and emit a
new timestamped run directory. No previously generated CSV, log,
screenshot, or raw file is reused.

## Use case

The intended user has already completed the front-end flow (schematic
design and pre-simulation), the layout, and Calibre DRC / LVS / PEX. What
is still missing is a repeatable, scriptable bridge from the PEX netlist
to a report-ready table of analog metrics. This project provides that
bridge:

1. Take the freshly produced PEX netlist (Spectre format) and re-simulate
   it on an EDA server.
2. Extract the standard OPA / BGR specifications into a uniform CSV
   table.
3. Keep the exact simulator command lines, PSF raw paths, and CSV outputs
   alongside the metrics, so that every reported number can be traced
   back to a specific PEX netlist and a specific simulator invocation.

Python dependencies: standard library only — no `pip install` is required.

## Repository layout

```
analog-postlayout-verify/
├── README.md              # English README (this file)
├── README.zh-CN.md        # Chinese README
├── LICENSE                # Apache License 2.0
├── NOTICE                 # Apache 2.0 NOTICE file
├── configs/
│   ├── opa.example.json   # OPA configuration template
│   └── bgr.example.json   # BGR configuration template
└── scripts/
    ├── opa_verify.py      # OPA post-layout verification driver
    ├── bgr_verify.py      # BGR post-layout verification driver
    ├── run_opa_verify.sh  # Thin wrapper that forwards CLI arguments
    └── run_bgr_verify.sh  # Thin wrapper that forwards CLI arguments
```

## Quick start

Run on a Linux EDA server that has Spectre, Calibre, and the analog PDK
available:

```bash
git clone https://github.com/GuoJiacheng0402/analog-postlayout-verify.git
cd analog-postlayout-verify

cp configs/opa.example.json configs/opa.local.json
cp configs/bgr.example.json configs/bgr.local.json
```

Edit `configs/*.local.json` and replace the placeholder values
(`<group>`, `<student_id>`, cell names, model paths, PEX paths, license
paths) with the values that correspond to your EDA environment.
`configs/*.local.json` is gitignored so local edits never leak into the
repository.

Run the OPA full R+C variant only:

```bash
cd scripts
./run_opa_verify.sh --config ../configs/opa.local.json --variants pex_rc
```

Run all OPA variants in one pass (schematic / PEX no-R/C / PEX full R+C):

```bash
cd scripts
./run_opa_verify.sh --config ../configs/opa.local.json
```

Run the BGR full R+C startup temperature sweep:

```bash
cd scripts
./run_bgr_verify.sh --config ../configs/bgr.local.json --variants pex_rc
```

Optionally re-run Calibre PEX from inside the BGR flow before the Spectre
sweep:

```bash
cd scripts
./run_bgr_verify.sh --config ../configs/bgr.local.json --variants pex_rc --rerun-pex
```

## Outputs

Each run creates a new directory under the configured run root:

- OPA: `~/opa_verify/runs/run_YYYYMMDD-HHMMSS/`
- BGR: `~/bgr_verify/runs/run_YYYYMMDD-HHMMSS/`

The run directory contains:

- `opa_live_metrics.csv` — six-metric OPA summary (one row per variant).
- `bgr_live_metrics.csv` — BGR temperature-coefficient summary.
- `temperature_points.csv` — BGR per-temperature `Vref`, `Vinx`, `Viny`,
  `Net2`, and `Idd` samples.
- `all_waveform_points.csv` — long waveform table for plotting and audit.
- The generated `.scs` testbenches, Spectre logs, and PSF ASCII raw
  directories that produced the numbers above.

## Configuration

At minimum, the following keys must be set in `configs/opa.local.json`
or `configs/bgr.local.json`:

- `paths.model` — PDK Spectre model file.
- `paths.spectre` — Spectre executable.
- `variants.*.include` — schematic or PEX netlist path.
- `variants.*.cell` (or top-level `cell`) — subckt name in the netlist.
- `cadence.*` — Cadence environment and license settings for the host.
- For BGR `--rerun-pex`, additionally configure `calibre.*`,
  `paths.gds`, `paths.cdl`, `paths.pex_deck`, and
  `paths.course_gui_runset`.

The `cds_lic_file` and `mgls_license_file` fields support a `{hostname}`
placeholder, which is substituted with the current server hostname at
runtime:

```json
"/SM01/eda/license/{hostname}/cadence/cadence_lic.dat"
```

## Requirements

- Linux EDA server with Cadence Spectre, Mentor Calibre, and the analog
  PDK installed.
- Python 3.6 or newer (standard library only — no `pip install`).
- A locally produced PEX netlist in Spectre format, the corresponding PDK
  model file, and a working Cadence/Mentor license configuration.

## Implementation notes

- Original PEX netlists are never modified in place. Each driver writes a
  sanitized include copy into the run directory, in which a few common
  Calibre PEX include paths are rewritten to absolute paths and a small
  set of device aliases (`rpoly2`, `rhr1k`, `cpip`) are mapped to
  Spectre primitives.
- Default OPA port order:
  - schematic: `(VDD VIN1 VIN2 VOUT VSS)`
  - PEX:       `(VDD VSS VOUT VIN1 VIN2)`
- Default BGR port order: `(VREF VSS VDD)`.
- If your cell uses a different port order, edit the testbench instance
  line in the corresponding driver script.
- BGR `--rerun-pex` deletes and recreates the matching Calibre PEX work
  directory. First-time users should run the simulation flow without
  `--rerun-pex` to confirm the existing PEX netlist works end to end.

## License

Released under the [Apache License, Version 2.0](LICENSE). See the
[`NOTICE`](NOTICE) file for the attribution notice that accompanies any
redistribution under Section 4(d) of the License.

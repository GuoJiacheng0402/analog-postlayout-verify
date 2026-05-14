# analog-postlayout-verify · 模拟集成电路后仿验证脚本

> 面向模拟集成电路后端流程的可复现后仿验证脚本：基于 Cadence Spectre 与
> Mentor Calibre，对 OPA 与 BGR 的 PEX 网表进行重新仿真，并把指标整理成
> 标准化 CSV。

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Python](https://img.shields.io/badge/python-3.6%2B-blue.svg)](#使用前提)

- 仓库地址：<https://github.com/GuoJiacheng0402/analog-postlayout-verify>
- 作者：**GuoJiacheng** &mdash; <https://github.com/GuoJiacheng0402>
- 许可证：[Apache License 2.0](LICENSE)
- English version: [README.md](README.md)

## 项目来源

这些脚本最初是作者在《模拟集成电路原理与设计》课程设计期间，为便于
后仿验证流程更快、更可复现而写的工具。
代码已经做了通用化整理：不再硬编码具体课程、服务器目录或 PDK 安装
路径，所有与站点相关的取值都通过 `configs/*.json` 传入，可以独立用于其
他模拟集成电路后端流程。

## 项目简介

仓库提供两个驱动脚本：

- **`scripts/opa_verify.py`**：分别基于 schematic 参考网表、PEX no-R/C 网表与
  PEX full R+C 网表运行 Spectre，自动计算运放（OPA）的
  `Adc / GBW / PM / Idc / SR+ / SR-` 六项指标。
- **`scripts/bgr_verify.py`**：基于 BGR 的 PEX 网表运行启动瞬态温扫，
  自动计算带隙基准的 `Vref`、电源电流 `Idd` 以及温度系数
  `TC = ΔVref / (mean(Vref) · ΔT) × 1e6`，单位 ppm/°C。

每次运行都会重新生成 testbench、显式设置 Spectre 选项
（`reltol`、`vabstol`、`iabstol`、`temp`、`tnom` 等），调用 Spectre 仿真，
解析本次产生的 PSF ASCII raw 数据，并写入新的、带时间戳的 run 目录。
**所有指标都来自本次重新仿真，不会读取旧 CSV、旧波形或旧截图。**

## 适用场景

适合已经完成前端设计与预仿、版图设计以及 Calibre DRC / LVS / PEX 的工程
场景，但缺少一个把 PEX 网表稳定地"跑回去 + 整理成报告"的脚本化环节。
本项目正是这一环节：

1. 把刚刚产生的 PEX 网表（Spectre 格式）放回 EDA 服务器，使用 Spectre
   重新仿真。
2. 把 OPA / BGR 的标准指标整理成统一的 CSV 表格。
3. 把仿真器的命令行、PSF raw 路径与 CSV 输出与指标一并保留，使任何一行
   报告里的数字都可以追溯到一份 PEX 网表与一次具体的仿真调用。

Python 依赖：仅使用标准库，不需要 `pip install`。

## 目录结构

```
analog-postlayout-verify/
├── README.md                  # English README
├── README.zh-CN.md            # 中文 README（本文件）
├── LICENSE                    # Apache License 2.0
├── NOTICE                     # Apache 2.0 NOTICE 文件
├── configs/
│   ├── opa.example.json       # OPA 配置模板
│   └── bgr.example.json       # BGR 配置模板
└── scripts/
    ├── opa_verify.py          # OPA 后仿主脚本
    ├── bgr_verify.py          # BGR 后仿主脚本
    ├── run_opa_verify.sh      # OPA 入口（转发命令行参数）
    └── run_bgr_verify.sh      # BGR 入口（转发命令行参数）
```

## 快速开始

在已安装 Spectre / Calibre / PDK 的 Linux EDA 服务器上：

```bash
git clone https://github.com/GuoJiacheng0402/analog-postlayout-verify.git
cd analog-postlayout-verify

cp configs/opa.example.json configs/opa.local.json
cp configs/bgr.example.json configs/bgr.local.json
```

把 `configs/*.local.json` 中的占位符（`<group>`、`<student_id>`、cell 名、
模型路径、PEX 路径、license 路径等）改成你自己环境的实际取值。
`configs/*.local.json` 已加入 `.gitignore`，本地修改不会提交到仓库。

只跑 OPA full R+C：

```bash
cd scripts
./run_opa_verify.sh --config ../configs/opa.local.json --variants pex_rc
```

一次性跑 OPA 三组对比（schematic / PEX no-R/C / PEX 全 R+C）：

```bash
cd scripts
./run_opa_verify.sh --config ../configs/opa.local.json
```

跑 BGR full R+C startup 温扫：

```bash
cd scripts
./run_bgr_verify.sh --config ../configs/bgr.local.json --variants pex_rc
```

如希望先重新跑一次 Calibre PEX，再跑 Spectre 温扫：

```bash
cd scripts
./run_bgr_verify.sh --config ../configs/bgr.local.json --variants pex_rc --rerun-pex
```

## 输出文件

每次运行都会在指定的 run root 下新建一个目录：

- OPA：`~/opa_verify/runs/run_YYYYMMDD-HHMMSS/`
- BGR：`~/bgr_verify/runs/run_YYYYMMDD-HHMMSS/`

主要输出：

- `opa_live_metrics.csv`：OPA 六项指标汇总（每个 variant 一行）。
- `bgr_live_metrics.csv`：BGR 温度系数汇总。
- `temperature_points.csv`：BGR 每个温度点的 `Vref / Vinx / Viny / Net2 / Idd`。
- `all_waveform_points.csv`：全量波形采样点，便于绘图与审计。
- 自动生成的 `.scs` testbench、Spectre log 以及 PSF ASCII raw 目录。

## 配置文件说明

至少需要确认以下字段：

- `paths.model`：PDK Spectre model 文件。
- `paths.spectre`：Spectre 可执行文件。
- `variants.*.include`：schematic 或 PEX 网表路径。
- `variants.*.cell`（或顶层的 `cell`）：网表中的 subckt 名称。
- `cadence.*`：服务器的 Cadence 环境与 license 设置。
- BGR 若使用 `--rerun-pex`，还需要配置 `calibre.*`、`paths.gds`、
  `paths.cdl`、`paths.pex_deck` 与 `paths.course_gui_runset`。

`cds_lic_file` 与 `mgls_license_file` 支持 `{hostname}` 占位符，运行时会
替换成当前服务器的 hostname：

```json
"/SM01/eda/license/{hostname}/cadence/cadence_lic.dat"
```

## 使用前提

- 装有 Cadence Spectre、Mentor Calibre 及对应模拟 PDK 的 Linux EDA 服务器。
- Python 3.6 及以上（仅使用标准库）。
- 你自己产生的 PEX 网表（Spectre 格式）、PDK model 文件，以及可用的
  Cadence / Mentor license 配置。

## 实现说明

- 原始 PEX 网表绝不会被就地修改。每个驱动脚本会在 run 目录中生成
  sanitized include 副本，把 Calibre PEX 的相对 include 改写为绝对路径，
  并把少量器件别名（`rpoly2`、`rhr1k`、`cpip`）映射到 Spectre 原语。
- OPA 默认端口顺序：
  - schematic：`(VDD VIN1 VIN2 VOUT VSS)`
  - PEX：`(VDD VSS VOUT VIN1 VIN2)`
- BGR 默认端口顺序：`(VREF VSS VDD)`。
- 如果你的 cell 端口顺序不同，请先修改对应脚本中的 testbench 实例化语句。
- BGR 的 `--rerun-pex` 会删除并重建对应的 Calibre PEX 工作目录。
  第一次使用建议先只跑仿真（不加 `--rerun-pex`），确认现有 PEX 网表能够
  端到端跑通后再启用。

## License

本项目以 [Apache License 2.0](LICENSE) 协议开源。
[`NOTICE`](NOTICE) 文件提供了 Apache 2.0 第 4(d) 条所要求的署名声明，
再发布与衍生作品中需要随分发包一起携带该 NOTICE 文件。

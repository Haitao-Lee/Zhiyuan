# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Zhiyuan (智源)** is an intelligent brachytherapy treatment planning platform built on [3D Slicer](https://slicer.org/). It provides AI-powered organ segmentation, dose prediction, and treatment optimization for brachytherapy procedures.

- **Platform**: Windows 10/11 (64-bit), Linux
- **Framework**: 3D Slicer (Qt-based medical imaging application)
- **Languages**: Python (algorithms), C++ (application layer)
- **ML Stack**: PyTorch, SimpleITK, TotalSegmentator

## Build & Package Commands

### Build (Windows)
```bat
# CMake GUI + Visual Studio 2022 (recommended, ~3 hours)
# Source: C:\W\Z, Build: C:\W\ZR

# Command line build
cmake -G "Visual Studio 17 2022" -A x64 -DQt5_DIR:PATH="C:/Qt/${QT_VERSION}/${COMPILER}/lib/cmake/Qt5" ..\Z
cmake --build . --config Release -- /maxcpucount:4
```

### Package (Windows)
```bat
# Requires NSIS 2 installed
cmake --build . --config Release --target PACKAGE
```

### Run
```bat
# Launch from build directory
C:\W\ZR\Slicer-build\bin\Release\Slicer.exe --python-code "import BrachyPlan"
```

## Architecture

```
Zhiyuan/
├── Applications/ZhiyuanApp/      # C++ application layer (main window, styles)
├── Modules/Scripted/
│   ├── BrachyPlan/               # Main brachytherapy planning module
│   │   ├── BrachyPlan.py         # Slicer module (widget, logic)
│   │   ├── MarkupConstraints.py  # Markup node constraints
│   │   ├── plans/                # Planning algorithms (Python)
│   │   │   ├── brachy_plan_v2.py # Main planning entry point
│   │   │   ├── core_v2.py        # Optimization algorithms
│   │   │   ├── utilizations_v2.py # Image processing utilities
│   │   │   ├── config.json       # Hyperparameters (JSON)
│   │   │   └── dose_pre/         # CNN-based dose prediction
│   │   └── Resources/            # Icons, UI (.ui), stylesheets
│   └── Home/                     # Custom home module
└── r/                            # Slicer build output, external deps
```

### Key Entry Points

| File | Purpose |
|------|---------|
| `Modules/Scripted/BrachyPlan/BrachyPlan.py` | Main Slicer module (BrachyPlanWidget, BrachyPlanLogic) |
| `Modules/Scripted/BrachyPlan/plans/brachy_plan_v2.py` | `brachy_plan()` and `brachy_plan_rf()` functions |
| `Applications/ZhiyuanApp/Main.cxx` | Application entry point |

## Code Modification Workflow

- **Edit Build Directory First**: Always edit code in `c:\Zhiyaun\r\Slicer-build\lib\Zhiyuan-5.9\qt-scripted-modules\` first. Sync to source (`Modules/Scripted/`) only upon explicit user request.
- **Comments in English**: All code comments must be in English regardless of context.
- **Windows Environment**: Use PowerShell/Bash syntax, not Linux commands. Request confirmation before system-level commands.

## Medical Imaging Development Rules

When modifying BrachyPlan or any imaging module:

1. **Context-Aware Analysis**: Read full context before changes. Understand systemic impact.
2. **Official Documentation First**: Consult 3D Slicer API docs before using API functions.
3. **Plan Before Action**: Create a detailed plan including rationale, changes, and verification steps.
4. **No Auto-Sync**: Do not automatically sync build directory changes to source.

## Configuration

All hyperparameters are in `Modules/Scripted/BrachyPlan/plans/config.json`:
- `module_constants`: NEW_SLICES_ROUNDED, SEED_LENGTH, SEED_RADIUS
- `seed_info`: Seed geometry parameters
- `dl_params`: Device (cuda/cpu), learning rate, loss weights
- `radiation_array_params`: Target/obstacle values, image dimensions
- `iso_dose_params`: Visualization isodose levels and colors

## Important Notes

- The UI file `Resources/UI/BrachyPlan.py` is **auto-generated** from `BrachyPlan.ui` - do not edit manually
- No unit tests exist for the BrachyPlan module
- The project uses `threading.Lock` for subprocess progress tracking - verify thread safety with Slicer API
- The `.claude/` directory contains ECC tooling rules, not project-specific guidance

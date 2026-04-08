<!-- PROJECT BADGES -->
[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://github.com/Haitao-Lee/Zhiyuan/releases)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux-green.svg)](https://www.slicer.org/)
[![License](https://img.shields.io/badge/license-Proprietary-orange.svg)](LICENSE)

<!-- PROJECT LOGO -->
<p align="center">
  <img src="Modules/Scripted/BrachyPlan/Resources/Icons/BrachyPlan.png" alt="Zhiyuan Logo" width="120" height="120"/>
</p>

<!-- PROJECT TITLE -->
<h1 align="center">Zhiyuan (智源——放射性粒子智能布源)</h1>

<h3 align="center">
  Intelligent Brachytherapy Treatment Planning Platform
</h3>

<p align="center">
  A customized 3D Slicer application for advanced medical image processing and brachytherapy optimization
</p>

---

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Quick Start](#quick-start)
- [Brachytherapy Planning Module](#brachytherapy-planning-module)
- [Architecture](#architecture)
- [Configuration](#configuration)
- [Contributing](#contributing)
- [License](#license)
- [Contact](#contact)

---

## Overview

Zhiyuan (致远, meaning "Boundless Horizon") is a specialized medical imaging platform built upon [3D Slicer](https://www.slicer.org/), developed by researchers at Shanghai Jiao Tong University and Ruijin Hospital.

The platform provides sophisticated tools for:
- Medical image segmentation (CT, MRI, PET)
- AI-powered organ delineation (via TotalSegmentator)
- Brachytherapy treatment planning optimization
- Dose distribution prediction (deep learning models)
- 3D visualization and export

---

## Features

### Core Capabilities
- **Multi-modality Support**: CT, MRI, PET, ultrasound medical imaging
- **3D Visualization**: Volume rendering, surface rendering, MPR
- **Quantitative Analysis**: ROI measurements, intensity profiling

### AI Integration
- **Auto-segmentation**: TotalSegmentator for organ segmentation (104 anatomical structures)
- **Dose Prediction**: CNN-based dose distribution prediction
- **Optimization Algorithms**: Reinforcement learning for trajectory optimization

### Brachytherapy Planning
- **4-Stage Optimization**: Image prep → Trajectory init → Seed placement → 3D export
- **Customizable Parameters**: JSON-based configuration
- **Multiple Task Support**: Total, Liver Tumor, Skin segmentation (decoupled)
- **STL Export**: 3D seed models for visualization

---

## Quick Start

### Prerequisites
- Windows 10/11 (64-bit) or Linux
- Python 3.8+
- CUDA-enabled GPU (optional, for deep learning)

### Installation

```bash
# Clone the repository
git clone https://github.com/Haitao-Lee/Zhiyuan.git
cd Zhiyuan

# Build from source (see BUILD.md for detailed instructions)
# Or use pre-built installer from Releases
```

### Basic Usage

1. Launch Zhiyuan application
2. Load CT image via File → Open
3. Navigate to **BrachyPlan** module
4. Select input volume and output segmentation
5. Choose segmentation task (Total / Liver Tumor / Skin)
6. Click **Run Segmentation**
7. For treatment planning, click **Plan** button

---

## Brachytherapy Planning Module

### Location
```
Modules/Scripted/BrachyPlan/BrachyPlan.py
```

### Supported Segmentation Tasks

| Task | Description | Task Name |
|------|-------------|-----------|
| Total | Full body segmentation (104 structures) | `total` |
| Liver Tumor | Liver vessels + tumor extraction | `liver_vessels` |
| Skin | Skin surface segmentation | `skin` |

> **Note**: Each task runs independently (decoupled) - no dependency between tasks.

### Algorithm Overview

```
Input: CT Image + Segmentation → 
  1. Image Normalization & Resampling
  2. Generate Candidate Trajectories  
  3. Optimize Seed Placement (iterative)
  4. Validate Dosimetric Coverage
Output: STL seed models + RTDoseMap volume
```

### Configuration

All hyperparameters are stored in `plans/config.json`:

```json
{
  "module_constants": {
    "NEW_SLICES_ROUNDED": 64,
    "SEED_LENGTH": 3.7,
    "SEED_RADIUS": 0.4
  },
  "seed_info": {
    "radius": 0.4,
    "length": 3.7
  },
  "dl_params": {
    "device": "cuda",
    "lr": 0.0004
  }
}
```

---

## Architecture

```
Zhiyuan/
├── Applications/ZhiyuanApp/     # Custom Slicer application
├── Modules/Scripted/
│   ├── BrachyPlan/            # Brachytherapy planning module
│   │   ├── plans/             # Planning algorithms
│   │   │   ├── config.json    # Configuration (JSON)
│   │   │   ├── brachy_plan.py # Main planning logic
│   │   │   ├── core.py        # Optimization algorithms
│   │   │   └── dose_pre/      # Dose prediction models
│   │   └── Resources/         # Icons, UI definitions
│   └── Home/                  # Custom home module
└── r/                          # Slicer build output
```

### Key Technologies
- **3D Slicer**: Application framework
- **Python**: Core algorithms, AI/ML integration
- **PyTorch**: Deep learning models
- **SimpleITK**: Image processing
- **VTK**: 3D visualization
- **TotalSegmentator**: Organ segmentation

---

## Configuration

### BrachyPlan Constants

| Constant | Default | Description |
|----------|---------|-------------|
| `NEW_SLICES_ROUNDED` | 64 | Resampling size |
| `SEED_LENGTH` | 3.7 | Seed length (mm) |
| `SEED_RADIUS` | 0.4 | Seed radius (mm) |
| `SEED_RESOLUTION` | 60 | STL resolution |
| `DIRECTION_EXTENSION` | 100 | Direction vector scale |

### Planning Parameters

All parameters are configurable via `plans/config.json`:
- Seed properties (radius, length)
- Radiation constraints (target/obstacle values)
- DL model settings
- Isodose visualization parameters
- Reinforcement learning parameters

---

## Contributing

Contributions are welcome! Please read our [Contributing Guidelines](CONTRIBUTING.md) before submitting PRs.

### Development Setup

```bash
# Install pre-commit hooks
pip install pre-commit
pre-commit install

# Run tests (if available)
pytest tests/
```

---

## License

This project is proprietary. See [LICENSE](LICENSE) file for details.

---

## Acknowledgments

Zhiyuan is built upon the excellent [3D Slicer](https://www.slicer.org/) platform.

**Contributors:**
- Shanghai Jiao Tong University (SJTU)
- Ruijin Hospital, Shanghai Jiao Tong University School of Medicine
- 3D Slicer Community

---

## Contact

- **Primary Contact**: Haitao Lee (hunter_lee163@163.com)
- **Issues**: [GitHub Issues](https://github.com/Haitao-Lee/Zhiyuan/issues)
- **Releases**: [GitHub Releases](https://github.com/Haitao-Lee/Zhiyuan/releases)

---

*Last updated: April 2026*
*Version: 1.0.0*

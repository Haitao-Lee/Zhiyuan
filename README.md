# Zhiyuan by Shanghai Jiao Tong University

A customized version of 3D Slicer for advanced medical image processing, radiotherapy planning, and brachytherapy treatment optimization.

## Overview

Zhiyuan is a specialized medical imaging platform built upon 3D Slicer, developed by researchers at Shanghai Jiao Tong University. This application provides sophisticated tools for medical image processing, visualization, and analysis with particular emphasis on radiotherapy treatment planning, including advanced brachytherapy optimization algorithms.

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Brachytherapy Planning Module](#brachytherapy-planning-module)
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
  - [Quick Start](#quick-start)
- [Development](#development)
  - [Building from Source](#building-from-source)
  - [Contributing](#contributing)
  - [Architecture](#architecture)
- [Modules](#modules)
- [Key Components](#key-components)
- [License](#license)
- [Acknowledgments](#acknowledgments)
- [Contact](#contact)

## Features

### Core Capabilities
- **Advanced Medical Image Processing**: State-of-the-art algorithms for image segmentation, registration, filtering, and enhancement
- **Multi-modality Support**: Comprehensive handling of CT, MRI, PET, ultrasound, and other medical imaging formats
- **3D Visualization**: Interactive 3D rendering with volume rendering, surface rendering, and multi-planar reconstruction
- **Quantitative Analysis**: Tools for ROI measurements, intensity profiling, and statistical analysis

### Radiotherapy Planning Specialization
- **External Beam Radiotherapy**: Tools for IMRT, VMAT, and SBRT plan evaluation and optimization
- **Brachytherapy Planning**: Specialized module for intracavitary and interstitial brachytherapy optimization
- **Dose Calculation Engine**: Integrated dose calculation with support for multiple algorithms
- **Plan Quality Assurance**: Automated QA checks and plan comparison tools

### Artificial Intelligence Integration
- **Deep Learning Models**: Pre-trained neural networks for auto-segmentation and dose prediction
- **Optimization Algorithms**: Advanced mathematical optimization for treatment planning
- **Prediction Tools**: AI-assisted contouring and outcome prediction

## Brachytherapy Planning Module

The brachytherapy planning module is one of Zhiyuan's core specialized components, designed specifically for optimizing brachytherapy treatment plans. This module implements sophisticated algorithms for determining optimal radioactive seed placement in interstitial brachytherapy procedures.

### Module Location
```
Modules/Scripted/AddSources/plans/brachy_plan.py
```

### Core Functionality

The brachytherapy planning module implements a multi-stage optimization algorithm that:

1. **Processes Medical Imaging Data**: Takes CT images andCTV (Clinical Target Volume) segmentations as input
2. **Generates Radiation Planning Volume**: Creates a 3D dose calculation grid based on image data
3. **Initializes Trajectory Candidates**: Generates potential needle/catheter trajectories for seed delivery
4. **Optimizes Seed Placement**: Uses iterative optimization to determine optimal radioactive seed positions along selected trajectories
5. **Validates Dosimetric Coverage**: Ensures the plan meets prescribed dose coverage constraints
6. **Exports Plan Data**: Generates STL files for 3D visualization of seed positions and trajectories

### Algorithm Details

#### Input Parameters
- `ctimage`: Computed Tomography image in NIfTI format
- `ctvimage`: Clinical Target Volume segmentation (binary mask)
- `args`: Configuration object containing all planning parameters

#### Four-Stage Optimization Process

**Stage 1: Image and Radiation Data Preparation**
- Loads and normalizes the CT image data
- Generates the radiation planning volume from the CTV segmentation using threshold values
- Establishes a reference direction for trajectory planning (can be manually set or automatically determined)

**Stage 2: Trajectory Initialization**
- Generates candidate trajectories for needle/catheter placement based on:
  - Angular resolution parameters
  - Geometric constraints from the radiation volume
  - Obstacle avoidance (structures to avoid irradiating)
  - Seed physical characteristics (length, radius)

**Stage 3: Optimal Plan Generation**
- Implements an iterative optimization process that:
  - Places seeds along trajectories to achieve target dose coverage
  - Uses Dose-Volume Histogram (DVH) constraints to ensure adequate target coverage
  - Incorporates deep learning models for refinement of seed placement
  - Balances tumor coverage with healthy tissue sparing
  - Minimizes the number of seeds while maintaining clinical requirements

**Stage 4: 3D Visualization and Export**
- Converts optimized seed positions and orientations into 3D geometric models
- Exports seed positions as STL files for visualization in 3D software
- Optionally exports dose distributions as NIfTI files

### Key Functions

#### `brachy_plan(ctimage, ctvimage, args)`
Main entry point that orchestrates the four-stage optimization process.

#### Helper Functions in `core.py`
- `seed_plan()` and `seed_plan_v2()`: Core optimization algorithms for seed placement
- `trajectory_plan()`: Generates and evaluates candidate needle trajectories
- `init_plan()`: Initializes trajectory planning with directional constraints
- `optimal_plan()`: Combines trajectory selection with seed placement optimization

### Technical Implementation

The brachytherapy planning module utilizes:

- **Mathematical Optimization**: Iterative algorithms for seed placement optimization
- **Deep Learning**: Pre-trained neural networks (`dose_model.pth`) for predicting dose distributions
- **Geometric Computations**: Vector mathematics for trajectory and seed positioning
- **Image Processing**: Utilizes SimpleITK and NumPy for image manipulation
- **3D Visualization**: VTK-based rendering through 3D Slicer's infrastructure

### Usage Example

The module can be invoked directly for testing or integrated into larger workflows:

```python
from Modules.Scripted.AddSources.plans.brachy_plan import brachy_plan
import config

# Load your CT and CTV images (implementation specific)
ctimage = load_ct_image("patient_ct.nii.gz")
ctvimage = load_ctv_segmentation("patient_ctv.nii.gz")

# Get default configuration
args = config.setting()

# Run brachytherapy plan optimization
plan_result, sum_image, dose_image = brachy_plan(ctimage, ctvimage, args)

# plan_result contains optimized seed trajectories and positions
# STL files are automatically exported to ./output/ directory
```

### Output Files

After successful execution, the module generates:
- `./output/seed_{i}_{j}.stl`: STL files representing individual radioactive seeds
- `./output/dose_{i}_{j}.nii.gz`: Optional dose distribution files for each seed
- Visualization files in `./fig/` directory for debugging and validation

## Getting Started

### Prerequisites

#### Hardware Requirements
- **Operating System**: Windows 10/11 (64-bit) or Linux (Ubuntu 20.04+ recommended)
- **Processor**: Modern multi-core CPU (Intel i5/i7/i9 or AMD equivalent)
- **Memory**: Minimum 8GB RAM (16GB+ recommended for large datasets)
- **Graphics**: GPU with OpenGL 3.3+ support and minimum 2GB VRAM
- **Storage**: SSD recommended with at least 20GB free space

#### Software Dependencies
- Python 3.8-3.11
- Required Python packages (see requirements.txt)
- VTK and Qt libraries (included with 3D Slicer dependencies)
- CUDA-enabled GPU for deep learning acceleration (optional but recommended)

### Installation

#### Option 1: Using Pre-built Installer (Recommended for Users)
1. Visit the [Releases](https://github.com/Haitao-Lee/Zhiyuan/releases) page
2. Download the latest installer for your operating system
3. Run the installer and follow the on-screen instructions
4. Launch Zhiyuan from your applications menu or desktop shortcut

#### Option 2: Building from Source (For Developers)
1. **Clone the Repository**:
   ```bash
   git clone https://github.com/Haitao-Lee/Zhiyuan.git
   cd Zhiyuan
   ```

2. **Set up Build Environment**:
   - Follow platform-specific instructions in [BUILD.md](BUILD.md)
   - Install required dependencies
   - Configure build system (CMake)

3. **Build the Application**:
   ```bash
   # Windows example
   mkdir build && cd build
   cmake .. -G "Visual Studio 17 2022"
   cmake --build . --config Release
   ```

4. **Run the Application**:
   - Locate the executable in the build output directory
   - Launch Zhiyuan from the command line or by double-clicking the executable

### Quick Start

After installation:
1. Launch Zhiyuan from your applications menu
2. Use the File → Open menu to load your CT and segmentation data
3. Navigate to the Brachytherapy Planning module via the Modules menu
4. Load your data and configure planning parameters
5. Execute the optimization and review results
6. Export your plan for clinical use or further analysis

## Development

### Building from Source

Detailed build instructions for all supported platforms are available in [BUILD.md](BUILD.md):

- **Windows**: Using Visual Studio and vcpkg dependencies
- **Linux**: Using GCC/Clang and system package managers
- **macOS**: Using Xcode and Homebrew dependencies

### Contributing

We welcome contributions from the community! Please see our [Contributing Guidelines](CONTRIBUTING.md) for:

- **Coding Standards**: Style guides for C++, Python, and QML
- **Pull Request Process**: How to submit changes for review
- **Issue Reporting**: Guidelines for submitting bug reports and feature requests
- **Development Workflow**: Branching strategy and release procedures
- **Testing Procedures**: Unit testing and integration testing requirements

### Architecture

Zhiyuan follows a modular extension architecture based on 3D Slicer:

#### Core Layers
- **Application Layer**: Main window, menus, and user interface framework (C++/Qt)
- **Module Layer**: Loadable extensions providing specific functionality
  - **Logic Layer**: Core algorithms and processing (C++/Python)
  - **GUI Layer**: User interfaces and interaction (Qt/QML/Python)
  - **Resources**: Icons, UI definitions, and configuration files (XML/QRC/INI)

#### Key Technologies
- **C++/Qt**: Core application performance and responsiveness
- **Python**: Rapid prototyping, scripting, and AI/ML integration
- **VTK**: Advanced 3D visualization and image processing
- **ITK**: Scientific image processing algorithms
- **JSON/XML**: Configuration and data exchange formats
- **CMake**: Cross-platform build system

## Modules

### Scripted Modules (Python-based)

Located in `Modules/Scripted/`:
- **AddSources**: Comprehensive tools for importing, creating, and manipulating imaging data
  - DICOM import and export functionality
  - Volume creation and editing tools
  - Markup and annotation tools
  - Specialized planning modules (brachytherapy, external beam)
- **Home**: Customized startup interface with quick access to common workflows
  - Customizable dashboard for frequent tasks
  - Integrated access to planning modules
  - Recent files and project management

### Key Submodules in AddSources/Plans

#### Brachytherapy Planning (`brachy_plan.py`)
As detailed above, provides optimized interstitial brachytherapy seed placement.

#### Dose Prediction (`dose_pre/`)
- Deep learning models for dose distribution prediction
- Preprocessing and postprocessing utilities
- Model training and validation scripts

#### Geometric Utilities (`geometry.py`)
- Mathematical functions for spatial computations
- Coordinate transformation utilities
- Intersection and distance calculation algorithms

#### Treatment Planning Utilities
- `utilizations.py`: Core image processing and mathematical helper functions
- `visualizer.py`: 3D visualization and export functions (STL, NIfTI)
- `plans/config.py`: Default parameter configurations
- `plans/core.py`: Main optimization algorithms
- `plans/fitting_model.py`: Mathematical models for dose fall-off and seed characteristics

### Compiled Modules (C++)

Located in `Applications/ZhiyuanApp/`:
- **Main Application Framework**: Window management, event handling, and core services
- **Custom Widgets**: Specialized UI components for medical imaging
- **Rendering Extensions**: Custom volume renderers and shaders
- **I/O Modules**: Specialized file format readers and writers

## Key Components

### Dose Prediction Models
Located in various `*_model.pth` files:
- **Dose Prediction Networks**: Convolutional neural networks trained to predict 3D dose distributions from anatomical images and planned applicator positions
- **Segmentation Networks**: Models for automatic organ-at-risk and target volume delineation
- **Optimization Networks**: Models that suggest optimal seed placements based on partial plans

### Image Processing Pipeline
- **Preprocessing**: Noise reduction, bias field correction, and intensity normalization
- **Registration**: Rigid and deformable image alignment algorithms
- **Segmentation**: Both manual tools and AI-assisted automatic segmentation
- **Feature Extraction**: Radiomics and texture analysis tools

### Treatment Planning Tools
- **Dose Calculation**: Multiple algorithms including convolution/superposition and Monte Carlo methods
- **Optimization Engines**: Mathematical solvers for fluence and seed position optimization
- **Evaluation Tools**: DVH calculation, conformity index computation, and plan comparison
- **Delivery Simulation**: Virtual treatment delivery and QA simulation

### Visualization and Export
- **3D Seed Visualization**: Interactive display of radioactive seed positions and orientations
- **Isodose Surface Rendering**: Color-coded dose level surfaces
- **Dose Volume Histograms**: Interactive DVH graphs and analysis
- **Export Capabilities**: DICOM RT, DICOM, NIfTI, STL, and other standard formats

## License

This project is licensed under the terms of the [LICENSE](LICENSE) file in the repository root.

## Acknowledgments

Zhiyuan is built upon the excellent foundation of [3D Slicer](https://www.slicer.org/), the open-source software platform for medical image informatics, image processing, and three-dimensional visualization.

We acknowledge the contributions of:
- The 3D Slicer development community
- Researchers at Shanghai Jiao Tong University Medical School
- Collaborating clinical partners providing valuable feedback and validation data
- Open-source contributors to VTK, ITK, NumPy, SciPy, PyTorch, and other libraries

## Contact

For questions, support, or collaboration inquiries:

### Official Channels
- **Issue Tracker**: [GitHub Issues](https://github.com/Haitao-Lee/Zhiyuan/issues)
- **Documentation**: [GitHub Wiki](https://github.com/Haitao-Lee/Zhiyuan/wiki) (coming soon)
- **Releases**: [GitHub Releases](https://github.com/Haitao-Lee/Zhiyuan/releases)

### Development Team
- **Primary Contact**: Haitao Lee (haitao.lee@sjtu.edu.cn)
- **Affiliation**: Department of Radiation Oncology, Shanghai Jiao Tong University Affiliated Hospitals
- **Research Group**: Medical Imaging and Radiation Therapy Optimization Lab

---

*Last updated: March 2026*
*Version: 1.0.0*
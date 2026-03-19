# Zhiyuan by Shanghai Jiao Tong University

A customized version of 3D Slicer for medical image processing, visualization, and analysis.

## Overview

Zhiyuan is a specialized medical imaging platform built upon 3D Slicer, developed by Shanghai Jiao Tong University. It provides advanced tools for medical image processing, radiotherapy planning, and clinical research applications.

## Features

- **Medical Image Processing**: Advanced algorithms for image segmentation, registration, and filtering
- **Radiotherapy Planning**: Specialized tools for dose calculation, plan evaluation, and quality assurance
- **Deep Learning Integration**: Pre-trained models for automated contouring and dose prediction
- **Custom Workflows**: Tailored interfaces for specific clinical applications
- **Extensible Architecture**: Based on 3D Slicer's plugin system for easy customization
- **Multi-modal Support**: Handles CT, MRI, PET, and other medical imaging formats

## Getting Started

### Prerequisites

- Windows 10/11 (64-bit) or Linux (Ubuntu 20.04+ recommended)
- Minimum 8GB RAM (16GB+ recommended)
- GPU with OpenGL 3.3+ support for optimal visualization
- At least 10GB free disk space

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/Haitao-Lee/Zhiyuan.git
   ```

2. Navigate to the project directory:
   ```bash
   cd Zhiyuan
   ```

3. Follow the build instructions in [BUILD.md](BUILD.md)

### Quick Start (Windows)

1. Download the pre-built installer from the [Releases](https://github.com/Haitao-Lee/Zhiyuan/releases) page
2. Run the installer and follow the on-screen instructions
3. Launch Zhiyuan from the Start menu or desktop shortcut

## Development

### Building from Source

See [BUILD.md](BUILD.md) for detailed build instructions for Windows, Linux, and macOS.

### Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for:
- Coding standards
- Pull request process
- Issue reporting guidelines
- Development workflow

### Architecture

Zhiyuan follows the 3D Slicer extension architecture:
- Core functionality in C++/Qt
- Scripted modules in Python
- Resource files (icons, UI definitions) in XML/QRC formats
- Configuration and settings in INI formats

## Modules

### Scripted Modules

Located in `Modules/Scripted/`:
- **AddSources**: Tools for adding and manipulating imaging data sources
- **Home**: Main interface with quick access to common workflows
- Various planning and analysis modules in the `plans/` subdirectories

### Key Components

- **Dose Prediction Models**: Deep learning models (`*.pth` files) for automated dose distribution prediction
- **Image Processing Utilities**: Advanced filtering and segmentation algorithms
- **Treatment Planning Tools**: Specialized for radiotherapy workflows

## License

This project is licensed under the terms of the LICENSE file in the repository root.

## Acknowledgments

Based on [3D Slicer](https://www.slicer.org/) - Software Platform for Medical Image Informatics, Image Processing, and Three-Dimensional Visualization.

Developed by researchers at Shanghai Jiao Tong University.

## Contact

For questions or support, please open an issue on this repository or contact the development team.

---

*Last updated: March 2026*
# Build and Package Zhiyuan

This document summarizes how to build and package Zhiyuan on Windows.

Zhiyuan is a custom Slicer application. Reading the [3D Slicer Developer Documentation](https://slicer.readthedocs.io/en/latest/developer_guide/index.html) may help answer additional questions.

The initial source files were created using [KitwareMedical/SlicerCustomAppTemplate](https://github.com/KitwareMedical/SlicerCustomAppTemplate).

## Prerequisites

- Setting up your git account:

  - Create a [Github](https://github.com) account.

  - Setup your SSH keys following [these](https://help.github.com/articles/generating-ssh-keys) instructions.

  - Setup [your git username](https://help.github.com/articles/setting-your-username-in-git) and [your git email](https://help.github.com/articles/setting-your-email-in-git).

  - If not already done, email `FirstName LastName <firstname.lastname@Shanghai Jiao Tong University.com>` to be granted access to
    the [Shanghai Jiao Tong University/Zhiyuan](https://github.com/Shanghai Jiao Tong University/Zhiyuan) repository.

## Checkout

1. Start `Git Bash`
2. Checkout the source code into a directory `C:\W\` by typing the following commands:

```bat
cd /c
mkdir W
cd /c/W
git clone https://github.com/Shanghai Jiao Tong University/Zhiyuan.git Z
```

Note: use short source and build directory names to avoid the [maximum path length limitation](https://learn.microsoft.com/en-us/windows/win32/fileio/naming-a-file#maximum-path-length-limitation).

## Build

Note: The build process will take approximately 3 hours.

<b>Option 1: CMake GUI and Visual Studio (Recommended)</b>

1. Start [CMake GUI](https://cmake.org/runningcmake/), select source directory `C:\W\Z` and set build directory to `C:\W\ZR`.
2. Add an entry `Qt5_DIR` pointing to `C:/Qt/${QT_VERSION}/${COMPILER}/lib/cmake/Qt5`.
3. Generate the project.
4. Open `C:\W\ZR\Zhiyuan.sln`, select `Release` and build the project.

<b>Option 2: Command Line</b>

1. Start the [Command Line Prompt](http://windows.microsoft.com/en-us/windows/command-prompt-faq)
2. Configure and build the project in `C:\W\ZR` by typing the following commands:

```bat
cd C:\W\
mkdir ZR
cd ZR
cmake -G "Visual Studio 17 2022" -A x64 -DQt5_DIR:PATH=`C:/Qt/${QT_VERSION}/${COMPILER}/lib/cmake/Qt5 ..\Z
cmake --build . --config Release -- /maxcpucount:4
```

## Package

Install [NSIS 2](http://sourceforge.net/projects/nsis/files/)

<b>Option 1: CMake and Visual Studio</b>

1. In the `C:\W\ZR\Slicer-build` directory, open `Slicer.sln` and build the `PACKAGE` target

<b>Option 2: Command Line</b>

1. Start the [Command Line Prompt](http://windows.microsoft.com/en-us/windows/command-prompt-faq)
2. Build the `PACKAGE` target by typing the following commands:

```bat
cd C:\W\ZR\Slicer-build
cmake --build . --config Release --target PACKAGE
```

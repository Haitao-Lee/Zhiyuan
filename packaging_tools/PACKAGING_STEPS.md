# Zhiyuan 完整打包步骤记录

> 版本: 3.0.0 | 最后更新: 2026-04-24
> 本文件记录了从源码到专业安装包的完整流程，基于实际成功打包经验编写

---

## 目录

1. [概述](#1-概述)
2. [环境准备](#2-环境准备)
3. [目录结构](#3-目录结构)
4. [完整打包流程](#4-完整打包流程)
5. [各工具详细说明](#5-各工具详细说明)
6. [已知问题与解决方案](#6-已知问题与解决方案)
7. [故障排查](#7-故障排查)
8. [文件清单速查](#8-文件清单速查)
9. [快速参考卡](#9-快速参考卡)

---

## 1. 概述

打包流程将 Zhiyuan 的 Python 源码通过 Cython 编译为二进制 .pyd 文件，实现知识产权保护，然后生成专业安装程序（Inno Setup）和便携压缩包（7z）。

**完整流程概览：**

```
源码 (.py) --[AST分析]--> 发现所有依赖 --> Cython编译 --> .pyd二进制
                                                        |
构建目录文件 --[白名单复制]--> TempRelease沙箱 --> Inno Setup --> .exe安装包
                                                        |
                                                        +--> 7z压缩 --> .7z便携包
```

**预计耗时：** 60-90 分钟（Cython编译约5-10分钟，Inno Setup编译约60-70分钟，7z压缩约10分钟）

---

## 2. 环境准备

### 2.1 必需软件

| 软件 | 版本要求 | 用途 | 验证命令 |
|------|----------|------|----------|
| **Python** | **3.12**（必须匹配 Slicer 版本） | Cython 编译 | `python --version` 应显示 `Python 3.12.x` |
| **Cython** | 最新版 | 源码保护(.py→.pyd) | `python -m pip show cython` |
| **NumPy** | 最新版 | Cython 编译依赖 | `python -m pip show numpy` |
| **setuptools** | 最新版 | Cython build 依赖 | `python -m pip show setuptools` |
| **7-Zip** | 任意版本 | 压缩/便携包 | `7z` 或 `"C:\Program Files\7-Zip\7z.exe"` |
| **Inno Setup 6** | 6.x | 专业安装界面 | `ISCC /?` |

> **重要：** Python 版本必须与 Slicer 内置 Python 版本完全一致。Slicer 5.9 使用 Python 3.12。如果使用 Python 3.14 编译，生成的 .pyd 文件（如 `.cp314-win_amd64.pyd`）将无法被 Slicer 的 Python 3.12 加载，运行时会出现 `ImportError: DLL load failed`。

### 2.2 安装依赖

```powershell
# 确保使用 Python 3.12
C:\Users\b223\AppData\Local\Programs\Python\Python312\python.exe -m pip install cython numpy setuptools
```

### 2.3 验证环境

```powershell
cd C:\Zhiyaun\packaging_tools

# 检查 Python 版本
$pythonExe = "C:\Users\b223\AppData\Local\Programs\Python\Python312\python.exe"
& $pythonExe --version

# 检查 Cython
& $pythonExe -c "import Cython; print(Cython.__version__)"

# 检查 Inno Setup
$inno = "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
if (Test-Path $inno) { & $inno /? } else { "Inno Setup not found" }

# 检查 7-Zip
$7z = "C:\Program Files\7-Zip\7z.exe"
if (Test-Path $7z) { & $7z } else { "7-Zip not found" }
```

---

## 3. 目录结构

```
C:\Zhiyaun\                          # 项目根目录
├── r\Slicer-build\                 # 构建目录（源码在此运行）
│   ├── Zhiyuan.exe                # 主程序（启动器）
│   ├── ZhiyuanLauncherSettings.ini      # 启动器配置（开发环境）
│   ├── ZhiyuanLauncherSettingsToInstall.ini  # 启动器配置（安装后）
│   ├── bin\                        # 二进制目录（含 ZhiyuanApp-real.exe）
│   │   └── Release\               # Release 模式 DLL
│   ├── lib\                        # 库目录
│   │   ├── Python\                # Python 3.12 运行时（~50k 文件）
│   │   ├── QtPlugins\             # Qt 插件（platforms, styles, imageformats）
│   │   ├── *.dll                  # Slicer 核心 DLL
│   │   ├── *.pyd                  # Slicer 核心 Python 扩展
│   │   └── Zhiyuan-5.9\           # Slicer 模块目录
│   │       ├── qt-scripted-modules\   # Python 脚本模块
│   │       │   ├── BrachyPlan.py      # 入口模块（将被编译为 .pyd）
│   │       │   ├── MarkupConstraints.py
│   │       │   ├── SubjectHierarchyPlugins\  # 层次结构插件
│   │       │   ├── plans\              # 算法模块（将被编译为 .pyd）
│   │       │   │   ├── brachy_plan_v2.py    # 主规划入口
│   │       │   │   ├── core_v2.py          # 优化算法
│   │       │   │   ├── utilizations_v2.py  # 图像处理工具
│   │       │   │   ├── visualizer.py       # 可视化
│   │       │   │   ├── geometry.py
│   │       │   │   ├── fitting_model.py
│   │       │   │   ├── config.json         # 超参数配置
│   │       │   │   ├── reinforcement.py    # Numba @njit（不编译，保留源码）
│   │       │   │   ├── dose_pre\          # 剂量预测 CNN
│   │       │   │   │   └── myDoseNet.py
│   │       │   │   └── seg\               # 分割模型权重（~1.2GB）
│   │       │   │       ├── total\         # TotalSegmentator 模型
│   │       │   │       └── pancreatic_tumor\  # 胰腺肿瘤模型
│   │       │   └── Resources\          # 图标、UI(.ui)、样式表
│   │       │       └── UI\             # Qt Designer UI 文件
│   │       │           ├── BrachyPlan.ui
│   │       │           ├── Home.ui
│   │       │           └── ...
│   │       └── qt-loadable-modules\   # C++ 加载模块
│   └── share\                      # 共享资源（SplashScreen.png 等）
│
├── Modules\Scripted\BrachyPlan\    # 源码目录（Git 追踪）
│   ├── BrachyPlan.py
│   ├── plans\brachy_plan_v2.py
│   └── ...
│
├── packaging_tools\             # 打包工具目录
│   ├── smart_builder.py         # 智能构建器（AST分析 + Cython编译）
│   ├── Zhiyuan_Setup.iss        # Inno Setup 安装脚本
│   ├── pack.ps1                # 一键打包主控脚本
│   ├── UI_MIGRATION_GUIDE.md   # UI 迁移指南
│   ├── README.md               # 工具说明
│   ├── vc_redist.x64.exe       # VC++ 运行时（可选，手动放置）
│   └── PACKAGING_STEPS.md      # 本文件
│
└── releases\                    # 输出目录（打包后生成）
    ├── Zhiyuan-Installer-v{x.y.z}.exe   # 安装包（~2.4GB）
    └── Zhiyuan-v{x.y.z}.7z              # 便携包（~3.6GB）
```

---

## 4. 完整打包流程

### Step 0: 前置检查

#### 0.1 关闭 Zhiyuan 进程

```powershell
# 必须确保 Zhiyuan.exe 没有运行，否则旧 .pyd 文件会被锁定无法删除
taskkill /F /IM Zhiyuan.exe /T 2>$null
taskkill /F /IM ZhiyuanApp-real.exe /T 2>$null
```

> **为什么：** 如果 Zhiyuan 正在运行，它加载的 .pyd 文件会被 Windows 锁定。Cython 编译时需要覆盖这些文件，会导致编译失败或生成损坏的 .pyd。

#### 0.2 确保代码最新

```powershell
cd C:\Zhiyaun

# 确认构建目录中的代码是最新版本
# 开发流程：先在 r\Slicer-build 中修改调试，确认无误后再同步到 Modules\Scripted\
# 打包时直接使用 r\Slicer-build 中的代码
```

> **重要：** 打包直接从 `r\Slicer-build` 读取代码，不需要手动同步到 `Modules\Scripted\`。开发调试在 `r\Slicer-build` 中进行，Git 提交时才需要同步。

#### 0.3 清理旧的编译产物

```powershell
cd C:\Zhiyaun\r\Slicer-build\lib\Zhiyuan-5.9\qt-scripted-modules

# 删除旧的 .pyd 文件（避免版本冲突）
Get-ChildItem -Filter "*.pyd" -Recurse | Remove-Item -Force

# 删除 Cython 生成的 .c 文件
Get-ChildItem -Filter "*.c" -Recurse | Remove-Item -Force

# 删除 build 临时目录
if (Test-Path "_cython_build_temp") { Remove-Item -Recurse -Force "_cython_build_temp" }
```

---

### Step 1: Cython 编译（IP 保护）

#### 1.1 运行智能构建器

```powershell
cd C:\Zhiyaun\packaging_tools

# 方式A: 通过 pack.ps1 自动调用（推荐）
# 见 Step 4 的一键打包

# 方式B: 单独运行 smart_builder.py（调试用）
C:\Users\b223\AppData\Local\Programs\Python\Python312\python.exe smart_builder.py
```

#### 1.2 smart_builder.py 内部执行流程

**Phase 1: AST 依赖分析**

```
输入: BrachyPlan.py（入口点）
  |
  └─> AST 解析 import/from 语句
      ├─ 处理绝对导入: from plans.core_v2 import xxx
      ├─ 处理相对导入: from . import core_v2  （node.module=None，需特殊处理）
      ├─ 递归查找所有本地 .py 依赖（BFS 队列遍历）
      └─ 扫描 loadUI() 调用找 .ui 文件引用
```

**扫描目录（SCAN_DIRS）：**
```python
SCAN_DIRS = [
    ".",                        # 根目录（BrachyPlan.py, MarkupConstraints.py）
    "plans",                    # 算法模块
    "plans/dose_pre",           # 剂量预测
    "SubjectHierarchyPlugins",  # 层次结构插件
    "Resources",                # 资源文件
]
```

**排除的文件（EXCLUDE_FILES）：**

```python
EXCLUDE_FILES = {
    "__init__.py",              # Cython 编译 __init__.py 生成的 .pyd 文件名与目录名冲突（Windows 限制）
    "reinforcement.py",         # 使用 Numba @njit，与 Cython 不兼容，保留源码
    # Slicer 框架模块（无需编译）
    "DICOM.py", "SegmentEditor.py", "TotalSegmentator.py",
    "Home.py", "Settings.py", "SlicerWelcome.py",
    "SampleData.py", "ScreenCapture.py", "WebServer.py",
    # ... 其他 Slicer 自带模块
}
```

> **关键修复：** 早期版本将 `core_v2.py`、`utilizations.py`、`brachy_plan.py` 加入 EXCLUDE_FILES，导致这些核心模块未被编译。修复后只有 Slicer 框架模块和已知不兼容文件被排除。

**Phase 2: Cython 编译**

```
发现的 .py 文件列表
  |
  └─> 生成 setup_cython_build.py（动态创建 Extension 列表）
      |
      └─> 调用 Python 3.12 执行:
          python setup_cython_build.py build_ext --inplace
          |
          ├─> .py -> .c（Cython 转换）
          └─> .c -> .pyd（MSVC 编译）
              输出: xxx.cp312-win_amd64.pyd
```

**编译指令（CYTHON_DIRECTIVES）：**
```python
CYTHON_DIRECTIVES = {
    "language_level": "3",      # Python 3 语法
    "embedsignature": "True",   # 嵌入函数签名
    "boundscheck": "False",     # 禁用边界检查（性能）
    "wraparound": "False",      # 禁用负索引包装（性能）
    "cdivision": "True",        # 使用 C 风格除法
}
```

**Phase 3: 清理**

- 删除 `setup_cython_build.py`
- 删除所有 `.c` 中间文件
- 删除 `_cython_build_temp/` 临时目录

#### 1.3 验证编译结果

编译完成后，检查关键 .pyd 文件是否生成：

```powershell
$moduleDir = "C:\Zhiyaun\r\Slicer-build\lib\Zhiyuan-5.9\qt-scripted-modules"

# 必须存在的核心 .pyd 文件（11个）
$requiredPyd = @(
    "BrachyPlan.cp312-win_amd64.pyd",
    "plans\brachy_plan_v2.cp312-win_amd64.pyd",
    "plans\core_v2.cp312-win_amd64.pyd",
    "plans\utilizations_v2.cp312-win_amd64.pyd",
    "plans\utilizations.cp312-win_amd64.pyd",
    "plans\visualizer.cp312-win_amd64.pyd",
    "plans\geometry.cp312-win_amd64.pyd",
    "plans\fitting_model.cp312-win_amd64.pyd",
    "plans\config.cp312-win_amd64.pyd",
    "plans\dose_pre\myDoseNet.cp312-win_amd64.pyd",
    "SubjectHierarchyPlugins\AbstractScriptedSubjectHierarchyPlugin.cp312-win_amd64.pyd"
)

foreach ($pyd in $requiredPyd) {
    $path = Join-Path $moduleDir $pyd
    if (Test-Path $path) {
        Write-Host "[OK] $pyd" -ForegroundColor Green
    } else {
        Write-Host "[MISSING] $pyd" -ForegroundColor Red
    }
}
```

> **历史问题：** v1.0.4 早期版本缺失 `utilizations_v2.cp312`、`visualizer.cp312`、`myDoseNet.cp312`、`AbstractScriptedSubjectHierarchyPlugin.cp312`，原因是 AST 分析器未正确处理相对导入（`from . import xxx` 时 `node.module = None`）。修复后所有模块均正确编译。

---

### Step 2: 沙箱创建（TempRelease）

```powershell
# pack.ps1 自动执行:
# 1. 删除旧沙箱（如果存在）
Remove-Item -Recurse -Force C:\Zhiyaun\TempRelease -ErrorAction SilentlyContinue

# 2. 创建新沙箱
New-Item -ItemType Directory -Path C:\Zhiyaun\TempRelease\r\Zhiyuan-build -Force
```

**沙箱隔离机制：**

```
原项目目录 (C:\Zhiyaun\r\Slicer-build\)
    ⚠️ 绝对安全，不会被修改
    
临时沙箱 (C:\Zhiyaun\TempRelease\)
    ✓ 从原目录复制必要文件
    ✓ 在此基础上进行修改（路径替换、安全扫描等）
    ✓ 打包完成后自动删除
```

> **重要：** 确保同时只有一个打包任务运行。多个任务竞争 TempRelease 目录会导致文件混乱。运行打包前检查是否有其他 PowerShell/cmd 窗口正在执行 pack.ps1。

---

### Step 3: 白名单文件复制

pack.ps1 按以下顺序将文件复制到沙箱：

#### 3.1 主程序

```
Source: r\Slicer-build\Zhiyuan.exe
Dest:   TempRelease\r\Zhiyuan-build\Zhiyuan.exe
```

#### 3.2 编译后的 Python 模块（.pyd）和 UI 文件（.ui）

```
Source: r\Slicer-build\lib\Zhiyuan-5.9\qt-scripted-modules\**\*.pyd
Dest:   TempRelease\r\Zhiyuan-build\lib\Zhiyuan-5.9\qt-scripted-modules\...\*.pyd

Source: r\Slicer-build\lib\Zhiyuan-5.9\qt-scripted-modules\**\*.ui
Dest:   TempRelease\r\Zhiyuan-build\lib\Zhiyuan-5.9\qt-scripted-modules\...\*.ui
```

> **UI 文件不编译：** `.ui` 文件保留原始格式，因为 Slicer 使用 `slicer.util.loadUI()` 动态加载，且包含私有 Qt 组件（如 `qMRMLCheckableNodeComboBox`），无法通过 pyuic 编译。

#### 3.3 Python 源码（智能保留）

对于每个 `.py` 文件：
- 如果存在同名的 `.pyd` → **跳过**（不复制 .py，防止源码泄漏）
- 如果不存在 `.pyd` → **保留**（复制 .py，否则运行时 ImportError）
- `reinforcement.py` → **始终保留**（Numba @njit 不兼容 Cython）

```powershell
# 逻辑伪代码:
foreach ($pyFile in Get-ChildItem *.py -Recurse) {
    $pydPattern = "${pyFile.BaseName}.*.pyd"
    if (Test-Path $pydPattern) {
        # 有编译版本，跳过 .py（保护源码）
    } elseif ($pyFile.Name -eq "reinforcement.py") {
        # Numba 不兼容，保留源码
        Copy-Item $pyFile
    } else {
        # 编译失败或不需要编译，保留 .py（否则无法运行）
        Copy-Item $pyFile
        Write-Warning "KEPT (no .pyd): $($pyFile.Name)"
    }
}
```

#### 3.4 DLL 库（多来源合并）

复制来源：
1. `r\Slicer-build\lib\*.dll`（Slicer 核心 DLL）
2. `r\CTK-build\CTK-build\bin\Release\*.dll`（CTK 框架）
3. `r\DCMTK-build\bin\Release\*.dll`（DICOM 支持）
4. `r\VTK-build\bin\Release\vtk*.dll`（VTK 可视化）
5. `r\ITK-build\bin\Release\ITK*.dll`（ITK 图像处理）
6. `r\teem-build\bin\Release\*.dll`（Teem 库）
7. `r\SlicerExecutionModel-build\...\*.dll`（模块描述解析）
8. `r\LibArchive-build\bin\Release\*.dll`（压缩库）
9. `r\ex-tbb1234\...\*.dll`（TBB 并行库）
10. Qt 5.15.2 `bin\Qt5*.dll`（Qt 核心）
11. OpenSSL `libcrypto-1_1-x64.dll`, `libssl-1_1-x64.dll`

> **排除 debug 文件：** 所有 `_d.dll`（debug 版本）都被跳过，只复制 Release 版本。

#### 3.5 Python 运行时（python-install）

```
Source: r\python-install\**\*
Dest:   TempRelease\r\Zhiyuan-build\lib\Python\...\*
```

> **关键路径：** 目标必须是 `lib\Python`，因为 `ZhiyuanLauncherSettingsToInstall.ini` 中设置 `PYTHONHOME=<APPLAUNCHER_SETTINGS_DIR>/../lib/Python`。

#### 3.6 Qt 插件

```
Source: Qt 安装目录\plugins\platforms\qwindows.dll
        Qt 安装目录\plugins\styles\*.dll
        Qt 安装目录\plugins\imageformats\*.dll
        Qt 安装目录\plugins\iconengines\*.dll
Dest:   TempRelease\r\Zhiyuan-build\lib\QtPlugins\...
```

> **为什么 Qt 插件必须在 lib\QtPlugins：** `ZhiyuanLauncherSettingsToInstall.ini` 设置 `QT_PLUGIN_PATH=<APPLAUNCHER_SETTINGS_DIR>/lib/QtPlugins`。如果 Qt 插件缺失，应用会闪退。

#### 3.7 模型权重（.pth）

```
Source: r\Slicer-build\lib\Zhiyuan-5.9\qt-scripted-modules\plans\seg\**\*.pth
        r\Slicer-build\lib\Zhiyuan-5.9\qt-scripted-modules\plans\dose_pre\*.pth
Dest:   TempRelease\r\Zhiyuan-build\lib\Zhiyuan-5.9\qt-scripted-modules\plans\...\*.pth
```

#### 3.8 配置文件（.json）

```
plans\config.json
plans\seg\total\config.json
plans\seg\total\label_mapping.json
plans\seg\**\*.json（递归，模型配置）
```

#### 3.9 资源文件（Resources）

```
Source: r\Slicer-build\lib\Zhiyuan-5.9\qt-scripted-modules\Resources\**\*
Dest:   TempRelease\r\Zhiyuan-build\lib\Zhiyuan-5.9\qt-scripted-modules\Resources\...\*
```

> **复制规则：** 复制所有非 `.py` 文件（图标 .png/.ico、样式表 .qss、UI .ui 等），跳过 `__pycache__`。

#### 3.10 Slicer bin 目录

```
Source: r\Slicer-build\bin\**\*（排除 debug 和源码文件）
Dest:   TempRelease\r\Zhiyuan-build\bin\...\*
```

#### 3.11 启动器设置 INI 文件

```
ZhiyuanLauncherSettings.ini（多位置复制）
ZhiyuanLauncherSettingsToInstall.ini（多位置复制）
```

复制到：
- `TempRelease\r\Zhiyuan-build\`
- `TempRelease\r\Zhiyuan-build\bin\`
- `TempRelease\r\Zhiyuan-build\bin\Release\`

#### 3.12 Slicer share 目录

```
Source: r\Slicer-build\share\**\*
Dest:   TempRelease\r\Zhiyuan-build\share\...\*
```

包含 `SplashScreen.png`（启动器必需）。

#### 3.13 辅助文件

```
setup_config.bat      # 环境变量配置脚本（用户首次运行）
Debug_Run.bat         # 调试模式启动器（排错用）
vc_redist.x64.exe     # VC++ 运行时安装程序（可选）
```

---

### Step 3.5: 安全扫描（智能 .py 移除）

在沙箱中对复制的文件进行二次检查：

```
对 TempRelease\r\Zhiyuan-build\lib\Zhiyuan-5.9\qt-scripted-modules\ 下的每个 .py:
    - 如果存在同名 .pyd → 删除 .py（源码已保护）
    - 如果不存在 .pyd → 保留 .py（防止运行时错误）
    - reinforcement.py → 始终保留（Numba 限制）
```

**预期结果：**
```
[OK] Security scan complete: X .py removed, Y .py kept
[INFO] Kept files (no compiled .pyd or Numba incompatibility):
    - reinforcement.py
```

---

### Step 3.6: 保留 reinforcement.py

`reinforcement.py` 使用 Numba 的 `@njit` 装饰器进行 JIT 编译，与 Cython 的静态编译冲突。该文件必须作为原始 `.py` 源码包含在包中。

```python
# smart_builder.py 中的配置:
EXCLUDE_FILES = {
    ...
    "reinforcement.py",  # Numba @njit 与 Cython 不兼容
}
```

---

### Step 3.6b: 修复 ToInstall INI 结构

`ZhiyuanLauncherSettingsToInstall.ini` 假设启动器运行在子目录中（使用 `../` 相对路径），但我们的启动器 `Zhiyuan.exe` 运行在 `Zhiyuan-build/` 根目录。

**修复操作：**
```powershell
# 用开发环境的 ZhiyuanLauncherSettings.ini（结构正确）覆盖 ToInstall 版本
Copy-Item ZhiyuanLauncherSettings.ini ZhiyuanLauncherSettingsToInstall.ini -Force
```

---

### Step 3.7: 深度路径替换

将所有配置文件中的绝对路径替换为相对路径宏：

| 原路径（开发机器） | 替换为 |
|-------------------|--------|
| `C:/Zhiyaun/r/python-install` | `<APPLAUNCHER_SETTINGS_DIR>/lib/Python` |
| `C:\Zhiyaun\r\python-install` | `<APPLAUNCHER_SETTINGS_DIR>/lib/Python` |
| `C:/LHT_workspace/code/Qt5.15/5.15.2/msvc2019_64/bin` | `<APPLAUNCHER_SETTINGS_DIR>/lib/QtPlugins` |
| `C:/Zhiyaun/r/VTK-build/bin/Release` | `<APPLAUNCHER_SETTINGS_DIR>/bin/Release` |
| `C:/Zhiyaun/r/ITK-build/bin/Release` | `<APPLAUNCHER_SETTINGS_DIR>/bin/Release` |
| `C:/Zhiyaun/r/CTK-build/CTK-build/bin/Release` | `<APPLAUNCHER_SETTINGS_DIR>/bin/Release` |
| `SLICER_HOME=C:/Zhiyaun/r/Slicer-build` | `SLICER_HOME=<APPLAUNCHER_SETTINGS_DIR>` |
| `Slicer-build` | `Zhiyuan-build` |

> **为什么用 [ordered]@{}：** PowerShell 普通 Hashtable 的键迭代顺序不保证。路径替换中 `Slicer-build -> Zhiyuan-build` 必须在 `SLICER_HOME` 替换之后执行，否则 `SLICER_HOME=C:/Zhiyaun/r/Slicer-build` 先变成 `SLICER_HOME=C:/Zhiyaun/r/Zhiyuan-build`，然后 `Slicer-build` 匹配失败。使用 `[ordered]@{}` 确保按定义顺序执行。

---

### Step 4: 安装包生成

#### 4.1 Inno Setup 编译

```powershell
# pack.ps1 自动执行:
ISCC.exe "Zhiyuan_Setup.iss" /O"releases" /DMyAppVersion="1.0.4"
```

**ISS 文件关键配置：**

```pascal
[Setup]
AppName=Zhiyuan
AppVersion=1.0.4
DefaultDirName={autopf}\Zhiyuan
OutputBaseFilename=Zhiyuan-Installer
Compression=lzma2/ultra64
SolidCompression=yes
ArchitecturesAllowed=x64compatible

[Files]
; === Python 安装（lib/Python）===
; 必须拆分为根 + 子目录，因为 `lib\Python\**\*` 在 50k+ 文件时会导致 ISS 内部递归深度超限
Source: "TempRelease\r\Zhiyuan-build\lib\Python\*"; ...
Source: "TempRelease\r\Zhiyuan-build\lib\Python\DLLs\*"; ...
Source: "TempRelease\r\Zhiyuan-build\lib\Python\Lib\*"; ...
Source: "TempRelease\r\Zhiyuan-build\lib\Python\Scripts\*"; ...
Source: "TempRelease\r\Zhiyuan-build\lib\Python\include\*"; ...

; === Qt 插件 ===
Source: "TempRelease\r\Zhiyuan-build\lib\QtPlugins\platforms\qwindows.dll"; ...
Source: "TempRelease\r\Zhiyuan-build\lib\QtPlugins\styles\*"; ...
Source: "TempRelease\r\Zhiyuan-build\lib\QtPlugins\imageformats\*"; ...

; === 编译后的 .pyd 模块 ===
Source: "TempRelease\r\Zhiyuan-build\lib\Zhiyuan-5.9\qt-scripted-modules\BrachyPlan*.pyd"; ...
Source: "TempRelease\r\Zhiyuan-build\lib\Zhiyuan-5.9\qt-scripted-modules\plans\*.pyd"; ...
Source: "TempRelease\r\Zhiyuan-build\lib\Zhiyuan-5.9\qt-scripted-modules\plans\dose_pre\*.pyd"; ...

; === 模型权重 ===
Source: "TempRelease\r\Zhiyuan-build\lib\Zhiyuan-5.9\qt-scripted-modules\plans\seg\**\*.pth"; ...
```

> **ISS `**\*` 递归通配符限制：** `lib\Python\**\*` 包含约 50,000 个文件，超过 ISS 内部递归限制，导致编译失败。解决方法是将 `lib\Python\**\*` 拆分为 5 个独立的子目录条目（根目录、DLLs、Lib、Scripts、include）。

**编译输出：**
```
Successful compile (4055.563 sec). Resulting Setup program filename is:
C:\Zhiyaun\releases\Zhiyuan-Installer.exe
```

> **注意：** Inno Setup 编译需要约 60-70 分钟，因为需要处理数万个小文件（主要是 Python 标准库）。这是正常的，不要中断。

#### 4.2 7z 便携包（备选/补充）

无论 Inno Setup 是否成功，都会额外生成 7z 便携包：

```powershell
7z.exe a -t7z -m0=lzma2 -mx=9 -mfb=256 -md=32m -ms=on Zhiyuan-v1.0.4.7z TempRelease\*
```

> **7z 压缩参数说明：**
> - `-mx=9`：最高压缩级别
> - `-mfb=256`：快速字节（字典大小相关）
> - `-md=32m`：字典大小 32MB
> - `-ms=on`：固实模式（提高压缩率）

---

### Step 5: 清理

```powershell
Remove-Item -Recurse -Force C:\Zhiyaun\TempRelease
```

删除沙箱目录，释放磁盘空间（约 5-6GB）。

---

## 5. 各工具详细说明

### 5.1 smart_builder.py - 智能构建器

**位置**: `C:\Zhiyaun\packaging_tools\smart_builder.py`

**功能**: 源码保护的核心工具

**完整工作流程：**

```
输入: BrachyPlan.py (入口点)
  ↓
Phase 1: AST 分析
  │ 解析 import/from 语句（含相对导入）
  │ 递归查找所有本地 .py 依赖（BFS）
  │ 扫描 loadUI() 调用找 .ui 引用
  ↓
Phase 2: Cython 编译
  │ 生成 setup_cython_build.py
  │ 调用 Python 3.12 + MSVC 编译
  │ .py → .pyd (Windows 二进制扩展)
  ↓
Phase 3: 清理
  │ 删除 setup_cython_build.py
  │ 删除 .c 中间文件
  │ 删除 build/ 临时目录
  ↓
输出: 所有 .py → 对应 .pyd
```

**关键配置项：**

| 配置项 | 位置 | 说明 |
|--------|------|------|
| `PYTHON_312_EXE` | 第 37 行 | Python 3.12 可执行文件路径 |
| `SCAN_DIRS` | 第 39-45 行 | 依赖分析的扫描目录 |
| `EXCLUDE_FILES` | 第 57-109 行 | 排除编译的文件列表 |
| `CYTHON_DIRECTIVES` | 第 111-117 行 | Cython 编译器指令 |

**单独运行：**
```powershell
cd C:\Zhiyaun
python packaging_tools/smart_builder.py
```

### 5.2 pack.ps1 - 主控脚本

**位置**: `C:\Zhiyaun\packaging_tools\pack.ps1`

**功能**: 一键执行全部打包流程

**参数列表：**

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `-Version` | string | `"1.0.0"` | 安装包版本号 |
| `-SkipCompile` | switch | `$false` | 跳过 Cython 编译（使用已有 .pyd） |
| `-Verbose` | switch | `$false` | 显示详细日志 |
| `-SourceDir` | string | `"r\Slicer-build"` | 构建目录名 |
| `-OutputDir` | string | `"releases"` | 输出目录名 |
| `-TempDir` | string | `"TempRelease"` | 临时沙箱目录 |

**执行步骤：**

```
Step 0: 环境验证
Step 1: Cython 编译（调用 smart_builder.py）
Step 1b: 编译完整性验证（检查每个 .py 是否有 .pyd）
Step 2: 沙箱创建（TempRelease/）
Step 3: 白名单文件复制（~15 个子步骤）
Step 3.5: 安全扫描（智能 .py 移除）
Step 3.6: 保留 reinforcement.py
Step 3.6b: 修复 ToInstall INI 结构
Step 3.7: 深度路径替换（Slicer-build → Zhiyuan-build）
Step 4: 安装包生成（Inno Setup + 7z）
Step 5: 清理
```

**常用命令：**
```powershell
cd C:\Zhiyaun\packaging_tools

# 完整打包（指定版本号）
.\pack.ps1 -Version "1.0.4"

# 跳过编译（使用已有 .pyd）
.\pack.ps1 -SkipCompile -Version "1.0.4"

# 详细调试模式
.\pack.ps1 -Verbose -Version "1.0.4"
```

### 5.3 Zhiyuan_Setup.iss - Inno Setup 配置

**位置**: `C:\Zhiyaun\packaging_tools\Zhiyuan_Setup.iss`

**功能**: 专业安装程序配置

**安全机制：白名单打包**

```
包含:
  ✅ *.pyd (编译后的模块)
  ✅ *.exe (主程序)
  ✅ *.dll (运行库)
  ✅ *.pth (模型权重)
  ✅ *.ui (UI 设计文件)
  ✅ Resources/ (图标等)
  ✅ setup_config.bat, Debug_Run.bat

排除:
  ❌ *.py (源码 - 已由 .pyd 保护)
  ❌ __pycache__/
  ❌ *backup*, *_old*
  ❌ debug 文件 (_d.dll, .pdb, .lib, .exp)
```

**安装组件：**

| 组件 | 内容 | 大小 |
|------|------|------|
| core | 核心应用文件（程序、DLL、Python 运行时、Qt 插件） | ~1.2 GB |
| models | 分割模型权重（TotalSegmentator + 胰腺肿瘤） | ~1.2 GB |
| dosemodel | 剂量预测模型 | ~50 MB |
| vcredist | Visual C++ 运行时 | ~20 MB |

**安装后操作：**
1. 设置环境变量 `TOTALSEG_WEIGHTS_PATH`
2. 安装 VC++ 运行时（如未安装）
3. 可选：创建桌面快捷方式
4. 可选：安装完成后启动 Zhiyuan

**手动编译（不通过 pack.ps1）：**
```powershell
$inno = "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
& $inno "C:\Zhiyaun\packaging_tools\Zhiyuan_Setup.iss" /DMyAppVersion="1.0.4"
```

---

## 6. 已知问题与解决方案

### 6.1 AST 分析器无法检测相对导入

**症状:** `utilizations_v2.cp312`、`visualizer.cp312`、`myDoseNet.cp312`、`AbstractScriptedSubjectHierarchyPlugin.cp312` 缺失

**原因:** `from . import xxx` 在 Python AST 中 `node.module = None`，早期分析器未处理这种情况

**修复:** 在 `visit_ImportFrom` 中添加相对导入处理：
```python
def visit_ImportFrom(self, node: ast.ImportFrom):
    if node.module:
        self.imported_modules.add(node.module)
    elif node.level > 0:
        # Relative import: from . import xxx
        for alias in node.names:
            self.imported_modules.add(f"__relative__:{alias.name}")
```

在 `analyze_dependencies` 中解析相对导入：
```python
if mod_name.startswith("__relative__:"):
    rel_name = mod_name.split(":", 1)[1]
    current_dir = current_file.parent
    candidate = current_dir / f"{rel_name}.py"
    # ...
```

### 6.2 EXCLUDE_FILES 过度排除核心模块

**症状:** `core_v2.py`、`brachy_plan.py`、`utilizations.py` 未被编译

**原因:** 早期版本将这些文件加入 `EXCLUDE_FILES` 以排除旧版模块，但误伤了当前使用的模块

**修复:** 从 `EXCLUDE_FILES` 中移除：
```python
# 修复前:
EXCLUDE_FILES = {
    "brachy_plan.py",   # 误伤 - 当前使用的是 brachy_plan_v2.py，但 brachy_plan.py 也可能被引用
    "core.py",          # 误伤
    "utilizations.py",  # 误伤
    ...
}

# 修复后:
EXCLUDE_FILES = {
    # 只排除确定不需要编译的文件
    "brachy_plan_backup.py",
    "core_backup.py",
    "utilizations_backup.py",
    ...
}
```

### 6.3 __init__.py 编译失败

**症状:** Cython 编译 `__init__.py` 时报错或生成的 .pyd 无法加载

**原因:** Windows 上，`plans/__init__.py` 编译为 `plans.cp312-win_amd64.pyd` 后，文件名 `plans` 与目录名 `plans` 冲突，导致 Python 无法正确识别包结构

**修复:** 将 `__init__.py` 加入 `EXCLUDE_FILES`：
```python
EXCLUDE_FILES = {
    "__init__.py",  # Cython __init__.py compilation produces .pyd that conflicts with directory name on Windows
}
```

### 6.4 旧 .pyd 文件被锁定

**症状:** Cython 编译时报 "Permission denied" 或 "file is being used by another process"

**原因:** 上一次运行 Zhiyuan 后，Windows 仍持有 .pyd 文件的句柄

**修复:** 打包前强制结束进程：
```powershell
taskkill /F /IM Zhiyuan.exe /T 2>$null
taskkill /F /IM ZhiyuanApp-real.exe /T 2>$null
```

### 6.5 ISS 递归通配符超限

**症状:** Inno Setup 编译时卡住或报错 "Too many files"

**原因:** `lib\Python\**\*` 包含约 50,000 个文件，超过 ISS 内部递归通配符处理限制

**修复:** 拆分为多个子目录条目：
```pascal
; 修复前（导致问题）:
Source: "TempRelease\r\Zhiyuan-build\lib\Python\**\*"; ...

; 修复后:
Source: "TempRelease\r\Zhiyuan-build\lib\Python\*"; ...
Source: "TempRelease\r\Zhiyuan-build\lib\Python\DLLs\*"; ...
Source: "TempRelease\r\Zhiyuan-build\lib\Python\Lib\*"; ...
Source: "TempRelease\r\Zhiyuan-build\lib\Python\Scripts\*"; ...
Source: "TempRelease\r\Zhiyuan-build\lib\Python\include\*"; ...
```

### 6.6 PowerShell Hashtable 键顺序问题

**症状:** 路径替换时 `Slicer-build` 被错误地替换到 `SLICER_HOME` 路径中

**原因:** 普通 `@{}` Hashtable 不保证键的迭代顺序。如果 `Slicer-build -> Zhiyuan-build` 在 `SLICER_HOME` 替换之前执行，会导致 `SLICER_HOME=C:/Zhiyaun/r/Slicer-build` 先变成包含 `Zhiyuan-build` 的路径，后续 `SLICER_HOME` 匹配失败

**修复:** 使用 `[ordered]@{}`：
```powershell
$pathReplacements = [ordered]@{
    # SLICER_HOME 替换必须在 Slicer-build 通用替换之前
    "SLICER_HOME=C:/Zhiyaun/r/Slicer-build" = "SLICER_HOME=<APPLAUNCHER_SETTINGS_DIR>"
    # ... 其他特定替换 ...
    # Slicer-build -> Zhiyuan-build 必须是最后一个
    "Slicer-build" = "Zhiyuan-build"
}
```

### 6.7 Resources 复制白名单太严格

**症状:** 某些资源文件（如 .qss 样式表、自定义图标格式）未被打包

**原因:** 早期版本使用扩展名白名单（只复制 .png, .ico, .json），遗漏了其他格式的资源

**修复:** 改为"复制所有非 .py 文件"：
```powershell
Get-ChildItem -Path $resDir -Recurse -File | Where-Object {
    $_.Extension -ne '.py' -and
    $_.FullName -notmatch '__pycache__'
}
```

---

## 7. 故障排查

### 7.1 Cython 编译失败

**症状:** Step 1 报错退出

**检查清单：**
```powershell
# 1. Python 版本
python --version  # 必须是 3.12.x

# 2. Cython 安装
python -m pip show cython

# 3. NumPy 安装（Cython 编译依赖）
python -m pip show numpy

# 4. setuptools 安装
python -m pip show setuptools

# 5. MSVC 编译器（Windows 必需）
# 检查是否安装了 Visual Studio Build Tools 或 Visual Studio 2022
```

**解决方案：**
```powershell
# 重新安装依赖
python -m pip install --upgrade cython numpy setuptools

# 如果仍失败，检查是否有旧 .pyd 被锁定
taskkill /F /IM Zhiyuan.exe /T 2>$null
Get-ChildItem -Path "C:\Zhiyaun\r\Slicer-build\lib\Zhiyuan-5.9\qt-scripted-modules" -Filter "*.pyd" -Recurse | Remove-Item -Force
```

### 7.2 某些模块未找到（ImportError）

**症状:** 运行时报 `ImportError: No module named xxx`

**原因:** 使用了动态加载但未被 AST 自动检测到

**解决方案：**

编辑 `C:\Zhiyaun\packaging_tools\smart_builder.py`：

```python
# 检查 SCAN_DIRS 是否包含该模块所在目录
SCAN_DIRS = [
    ".",
    "plans",
    "plans/dose_pre",
    "SubjectHierarchyPlugins",
    "Resources",
    # 添加新目录，例如:
    # "plans/new_submodule",
]
```

如果模块是通过 `importlib.import_module()` 动态加载的，AST 分析器会在日志中警告：
```
Dynamic import at line X: importlib.import_module
```

此时需要将该模块手动添加到分析队列，或在 `SCAN_DIRS` 中添加其所在目录。

### 7.3 Inno Setup 编译卡住/失败

**症状:** Step 4 长时间无响应或报错

**可能原因与解决：**

1. **文件数量过多（50k+ Python 文件）**
   - 正常现象，编译需要 60-70 分钟
   - 不要中断，等待完成

2. **ISS 递归通配符超限**
   - 检查 `Zhiyuan_Setup.iss` 中 `lib\Python\**\*` 是否已拆分为子目录
   - 参考 6.5 的修复方案

3. **TempRelease 目录被占用**
   - 确保没有其他程序（如文件资源管理器、另一个 pack.ps1 实例）正在访问 TempRelease
   - 关闭所有相关窗口后重试

### 7.4 安装包过大

**预期大小:** ~2.4 GB（含模型权重）

**优化方案：**

```powershell
# 方案1: 不包含模型权重（仅 ~1.2 GB）
# 编辑 Zhiyuan_Setup.iss，将 models 组件设为可选（已默认实现）
# 用户安装时可选择 "Compact Installation"

# 方案2: 使用更高压缩率（7z）
# 编辑 pack.ps1，修改 7z 参数:
# -mfb=256 改为 -mfb=512（更大快速字节）
# -md=32m 改为 -md=64m（更大字典）
```

### 7.5 目标机器无法启动

**检查清单：**

```
□ 安装了 Visual C++ Redistributable 2019-2022 (x64)
□ 环境变量 TOTALSEG_WEIGHTS_PATH 已设置（安装程序自动设置）
□ 运行了 setup_config.bat（可选）
□ 重启了电脑（或注销重新登录，使环境变量生效）
□ 有足够的内存（16GB+ 推荐）
□ 显卡驱动是最新的
```

**快速修复命令（在目标机器上）：**
```batch
@echo off
set TOTALSEG_WEIGHTS_PATH=C:\Program Files\Zhiyuan\r\Zhiyuan-build\lib\Zhiyuan-5.9\qt-scripted-modules\plans\seg\total\nnunet\results
setx TOTALSEG_WEIGHTS_PATH "%TOTALSEG_WEIGHTS_PATH%"
echo Environment variable set. Please restart computer.
pause
```

### 7.6 Qt 插件缺失导致闪退

**症状:** 双击 Zhiyuan.exe 后窗口闪一下立即关闭

**原因:** Qt 平台插件 `qwindows.dll` 缺失或路径不正确

**检查：**
```powershell
# 确认 qwindows.dll 存在
Test-Path "C:\Zhiyaun\TempRelease\r\Zhiyuan-build\lib\QtPlugins\platforms\qwindows.dll"

# 确认 INI 中 QT_PLUGIN_PATH 正确
Get-Content "C:\Zhiyaun\TempRelease\r\Zhiyuan-build\ZhiyuanLauncherSettings.ini" | Select-String "QT_PLUGIN_PATH"
# 应显示: QT_PLUGIN_PATH=<APPLAUNCHER_SETTINGS_DIR>/lib/QtPlugins
```

---

## 8. 文件清单速查

### 打包工具目录

```
C:\Zhiyaun\packaging_tools\
├── smart_builder.py          ✅ 智能构建器（AST分析 + Cython编译）
├── Zhiyuan_Setup.iss         ✅ Inno Setup 安装脚本
├── pack.ps1                 ✅ 主控脚本（一键打包）
├── UI_MIGRATION_GUIDE.md   ✅ UI 迁移指南
├── README.md                ✅ 工具说明
├── vc_redist.x64.exe        ⚠️ VC++ 运行时（手动放置，可选）
└── PACKAGING_STEPS.md      ✅ 本文件
```

### 输出目录（打包后生成）

```
C:\Zhiyaun\releases\
├── Zhiyuan-Installer-v{x.y.z}.exe   ✅ 安装包（~2.4GB）
└── Zhiyuan-v{x.y.z}.7z              ✅ 便携包（~3.6GB）
```

### 成功打包的统计参考（v1.0.4）

```
Compiled Modules (.pyd): 653
UI Interfaces (.ui):     5
Executables (.exe):      63
Runtime Libs (.dll):     827
Model Weights (.pth):    11
Configurations (.json):  45
Other Resources:         50178
```

---

## 9. 快速参考卡

### 常用命令

```powershell
# === 完整打包（最常用）===
cd C:\Zhiyaun\packaging_tools
.\pack.ps1 -Version "1.0.4"

# === 仅编译不打包（调试用）===
cd C:\Zhiyaun
python packaging_tools/smart_builder.py

# === 跳过编译直接打包（.pyd已存在）===
cd C:\Zhiyaun\packaging_tools
.\pack.ps1 -SkipCompile -Version "1.0.4"

# === 详细调试模式 ===
cd C:\Zhiyaun\packaging_tools
.\pack.ps1 -Verbose -Version "1.0.4"

# === 打包前清理旧编译产物 ===
cd C:\Zhiyaun\r\Slicer-build\lib\Zhiyuan-5.9\qt-scripted-modules
taskkill /F /IM Zhiyuan.exe /T 2>$null
Get-ChildItem -Filter "*.pyd" -Recurse | Remove-Item -Force
Get-ChildItem -Filter "*.c" -Recurse | Remove-Item -Force
if (Test-Path "_cython_build_temp") { Remove-Item -Recurse -Force "_cython_build_temp" }
```

### 关键路径

```
项目根目录:       C:\Zhiyaun
构建目录:         C:\Zhiyaun\r\Slicer-build
入口模块:         ...qt-scripted-modules\BrachyPlan.py
模块算法目录:     ...qt-scripted-modules\plans\
打包工具目录:     C:\Zhiyaun\packaging_tools\
输出目录:         C:\Zhiyaun\releases\
临时沙箱:         C:\Zhiyaun\TempRelease\
```

### 版本更新检查清单

每次发布新版本前：

- [ ] 代码已同步至 `r\Slicer-build`（构建目录）
- [ ] Zhiyuan.exe 没有在运行（taskkill 确认）
- [ ] 旧 .pyd 文件已清理
- [ ] `smart_builder.py` 的 `EXCLUDE_FILES` 无需更新
- [ ] 版本号正确（`-Version "x.y.z"`）
- [ ] 磁盘空间充足（需要 ~10GB 临时空间）

---

*本文档基于实际打包经验编写，如有问题请查阅各工具内的详细注释或联系开发团队。*

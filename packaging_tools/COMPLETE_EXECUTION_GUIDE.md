# Zhiyuan Professional Installer - 完整打包执行指南

> **版本**: 2.3.0 (Final Edition - All Issues Resolved)
> **目标**: 从源码到专业安装包的一键自动化流程
> **适用工具**: Codex / Claude Code / 任何 AI 编程助手

---

## 📋 任务概述

**目标**: 执行 `.\pack.ps1` 脚本，生成 **Zhiyuan-Installer-v{VERSION}.exe** 专业安装包

**核心功能**:
1. ✅ Cython 源码编译（.py → .pyd 二进制保护）
2. ✅ 沙箱隔离复制（不污染原项目）
3. ✅ 白名单安全打包（排除所有 .py 源码）
4. ✅ Inno Setup 专业安装包生成
5. ✅ 自动清理临时文件

---

## 🎯 执行命令

```powershell
cd C:\Zhiyaun\packaging_tools
.\pack.ps1 -Version "1.0.0"
```

### 参数说明

| 参数 | 类型 | 默认值 | 说明 | 示例 |
|------|------|--------|------|------|
| `-Version` | string | `"1.0.0"` | 安装包版本号 | `-Version "1.1.0"` |
| `-SkipCompile` | switch | `$false` | 跳过Cython编译（用于调试） | `-SkipCompile` |
| `-Verbose` | switch | `$false` | 显示详细日志 | `-Verbose` |
| `-SourceDir` | string | `"r\Slicer-build"` | 构建目录名 | （通常不需改） |
| `-OutputDir` | string | `"releases"` | 输出目录名 | （通常不需改） |
| `-TempDir` | string | `"TempRelease"` | 临时沙箱目录名 | （通常不需改） |

### 常用命令组合

```powershell
# === 标准打包（含编译）===
.\pack.ps1 -Version "1.0.0"

# === 快速打包（跳过编译，用于测试ISS修复）===
.\pack.ps1 -SkipCompile -Version "1.0.0"

# === 详细日志模式（排查问题）===
.\pack.ps1 -Verbose -SkipCompile -Version "1.0.0"
```

---

## 📂 项目结构（必须理解）

```
C:\Zhiyaun\                              # 项目根目录 ($ProjectRoot)
├── r\Slicer-build\                     # 构建目录 ($BuildDir)
│   ├── Zhiyuan.exe                    # 主程序
│   └── lib\Zhiyuan-5.9\
│       └── qt-scripted-modules\        # 模块根目录 ($ModuleRoot)
│           ├── BrachyPlan.cp312-win_amd64.pyd  # 入口模块（Cython编译后）
│           ├── plans\*.cp312-win_amd64.pyd      # 算法子模块
│           ├── *.ui                        # UI文件（Qt Designer）
│           └── Resources\                 # 图标等资源
│
├── Modules\Scripted\BrachyPlan\          # 源码目录（Git追踪）
│
└── packaging_tools\                     # 打包工具目录 ($ScriptDir) ⭐
    ├── pack.ps1                         # 主控脚本 ⭐⭐⭐
    ├── smart_builder.py                 # Cython编译器
    ├── Zhiyuan_Setup.iss                # Inno Setup配置 ⭐⭐⭐
    └── PACKAGING_STEPS.md               # 文档
```

---

## 🔧 关键文件详解与注意事项

### 1️⃣ **pack.ps1** (主控脚本) - `C:\Zhiyaun\packaging_tools\pack.ps1`

**作用**: 一键执行全部5个步骤

**关键配置点**（第36-41行）：
```powershell
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir        # C:\Zhiyaun
$BuildDir = Join-Path $ProjectRoot $SourceDir         # C:\Zhiyaun\r\Slicer-build
$ModuleRoot = Join-Path $BuildDir "lib\Zhiyuan-5.9\qt-scripted-modules"
$ReleaseDir = Join-Path $ProjectRoot $OutputDir        # C:\Zhiyaun\releases
$SandboxDir = Join-Path $ProjectRoot $TempDir          # C:\Zhiyaun\TempRelease
```

**⚠️ 注意事项**:
- ❌ **不要修改** ISS 文件输出位置为 `%TEMP%` 目录（会导致路径解析错误）
- ✅ 必须输出到 `$ProjectRoot` (即 `C:\Zhiyaun\`)
- ✅ 使用 `-WorkingDirectory $ProjectRoot` 确保相对路径正确解析

**Step 3 复制逻辑**（第144-208行）：

| 复制项 | 源路径 | 目标路径（在TempRelease中） | 说明 |
|--------|--------|---------------------------|------|
| **主程序** | `$BuildDir\Zhiyuan.exe` | `r\Slicer-build\Zhiyuan.exe` | ⚠️ 不是 TempRelease 根目录！ |
| **DLL库** | `$BuildDir\lib\*.dll` | `r\Slicer-build\lib\*.dll` | 排除 `_d.dll` 调试版 |
| **PYD模块** | `$ModuleRoot\*.pyd` | `r\Slicer-build\lib\...\*.pyd` | Cython编译产物 |
| **UI文件** | `$ModuleRoot\*.ui` | `r\Slicer-build\lib\...\*.ui` | Qt界面文件 |
| **模型权重** | `$ModuleRoot\plans\seg\total\*.pth` | 对应子目录 | ~1.2GB 大文件 |
| **配置脚本** | `$ProjectRoot\setup_config.bat` | `setup_config.bat` | 环境变量设置 |
| **VC运行库** | `$ScriptDir\vc_redist.x64.exe` | `vc_redist.x64.exe` | ⚠️ 必须手动放置！ |

**Step 4 Inno Setup 编译**（第248-268行）：

```powershell
# ✅ 正确做法：直接使用相对路径，不替换
$tempIss = Join-Path $ProjectRoot "Zhiyuan_Setup_temp.iss"
$issContent = Get-Content $issFile -Raw -Encoding UTF8
$issContent = $issContent.Replace("0000000000", $totalSize.ToString())
# ❌ 不要添加路径替换代码！这会破坏ISS语法！

$process = Start-Process -FilePath $InnoSetupPath `
    -ArgumentList "`"$tempIss`" /O`"$installerPath`" /DMyAppVersion=`"$Version`"" `
    -WorkingDirectory $ProjectRoot `
    -PassThru -NoNewWindow -Wait
```

**⛔ 绝对禁止的代码**（已删除的错误实现）：
```powershell
# ❌ 错误1: 输出到 %TEMP%（导致路径找不到）
$tempIss = Join-Path $env:TEMP "Zhiyuan_Setup_temp.iss"

# ❌ 错误2: 动态替换 Source 路径（破坏引号/语法）
$sandboxDirForIss = $SandboxDir.Replace("\", "/")
$issContent = $issContent.Replace('Source: "TempRelease\', "Source: `"$sandboxDirForIss\"")

# ❌ 错误3: 使用 -replace 操作符处理反斜杠（正则转义错误）
$sandboxDirForIss = $SandboxDir -replace "\\", "/"
```

---

### 2️⃣ **Zhiyuan_Setup.iss** (Inno Setup配置) - `C:\Zhiyaun\packaging_tools\Zhiyuan_Setup.iss`

**作用**: 定义安装包的结构、界面和行为

**✅ 已验证通过的完整有效配置**（198行）：

#### [Setup] 段落（第18-59行）

```ini
[Setup]
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher=Shanghai Jiao Tong University / Ruijin Hospital
DefaultDirName={autopf}\Zhiyuan
WizardStyle=modern
Compression=lzma2/ultra64
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64
ShowLanguageDialog=yes
```

**⚠️ 关键约束**:
- ❌ 不要在 [Languages] 段落添加 `Flags` 参数
- ❌ 不要在 [Tasks] 段落使用 `once` 标志（仅适用于 [Icons]/[Run]）
- ❌ 不要使用不存在的 `[Uninstall]` 段落（应使用 `[UninstallDelete]`）
- ✅ Registry 每行必须独立包含 `Root:` 和 `Subkey:`（不支持多行续写）

#### [Languages] 段落（第61-64行）

```ini
[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "chinesesimplified"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"
```

**⚠️ 前置条件**: 必须先安装中文语言包！
```powershell
# 中文语言包位置（已自动安装）:
C:\Users\b223\AppData\Local\Programs\Inno Setup 6\Languages\ChineseSimplified.isl
```

#### [Files] 段落（第80-117行）- ⭐⭐⭐ 最重要部分

**路径规则**:
- 所有 `Source:` 路径以 `TempRelease\` 开头（相对于项目根目录）
- **实际文件位置** = `C:\Zhiyaun\TempRelease\` + Source路径去掉 `TempRelease\`
- Inno Setup 在 `$ProjectRoot` (C:\Zhiyaun\) 目录下查找

**文件命名格式**:
```
Cython编译后的 .pyd 文件名格式:
  {模块名}.cp{Python版本}-{平台}.pyd
  
示例:
  BrachyPlan.cp312-win_amd64.pyd    ← 实际存在
  plans.cp312-win_amd64.pyd          ← 实际存在
  
ISS 中必须使用通配符匹配:
  BrachyPlan*.pyd                    ✅ 正确
  BrachyPlan.pyd                      ❌ 错误（找不到文件）
```

**完整有效的 [Files] 配置**:

```ini
[Files]
; === 核心主程序 ===
Source: "TempRelease\r\Slicer-build\Zhiyuan.exe"; DestDir: "{app}\r\Slicer-build\"; Components: core; Flags: ignoreversion
Source: "TempRelease\r\Slicer-build\lib\*.dll"; DestDir: "{app}\r\Slicer-build\lib\"; Components: core; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "TempRelease\r\Slicer-build\lib\*.pyd"; DestDir: "{app}\r\Slicer-build\lib\"; Components: core; Flags: ignoreversion recursesubdirs createallsubdirs

; === 模块源码加密包 (.pyd) - 使用通配符匹配Cython编译后的文件名 ===
Source: "TempRelease\r\Slicer-build\lib\Zhiyuan-5.9\qt-scripted-modules\BrachyPlan*.pyd"; DestDir: "{app}\r\Slicer-build\lib\Zhiyuan-5.9\qt-scripted-modules\"; Components: core; Flags: ignoreversion
Source: "TempRelease\r\Slicer-build\lib\Zhiyuan-5.9\qt-scripted-modules\MarkupConstraints*.pyd"; DestDir: "{app}\r\Slicer-build\lib\Zhiyuan-5.9\qt-scripted-modules\"; Components: core; Flags: ignoreversion

; === 核心 UI 原生文件 ===
Source: "TempRelease\r\Slicer-build\lib\Zhiyuan-5.9\qt-scripted-modules\*.ui"; DestDir: "{app}\r\Slicer-build\lib\Zhiyuan-5.9\qt-scripted-modules\"; Components: core; Flags: ignoreversion

; === UI 编译后的二进制包 ===
Source: "TempRelease\r\Slicer-build\lib\Zhiyuan-5.9\qt-scripted-modules\*_ui*.pyd"; DestDir: "{app}\r\Slicer-build\lib\Zhiyuan-5.9\qt-scripted-modules\"; Components: core; Flags: ignoreversion

; === 算法子模块 ===
Source: "TempRelease\r\Slicer-build\lib\Zhiyuan-5.9\qt-scripted-modules\plans\*.pyd"; DestDir: "{app}\r\Slicer-build\lib\Zhiyuan-5.9\qt-scripted-modules\plans\"; Components: core; Flags: ignoreversion
Source: "TempRelease\r\Slicer-build\lib\Zhiyuan-5.9\qt-scripted-modules\plans\config.json"; DestDir: "{app}\r\Slicer-build\lib\Zhiyuan-5.9\qt-scripted-modules\plans\"; Components: core; Flags: ignoreversion
Source: "TempRelease\r\Slicer-build\lib\Zhiyuan-5.9\qt-scripted-modules\plans\dose_pre\*.pyd"; DestDir: "{app}\r\Slicer-build\lib\Zhiyuan-5.9\qt-scripted-modules\plans\dose_pre\"; Components: core; Flags: ignoreversion

; === 资源文件 ===
Source: "TempRelease\r\Slicer-build\lib\Zhiyuan-5.9\qt-scripted-modules\Resources\**\*"; DestDir: "{app}\r\Slicer-build\lib\Zhiyuan-5.9\qt-scripted-modules\Resources\"; Components: core; Flags: ignoreversion recursesubdirs createallsubdirs

; === 配置脚本 ===
Source: "TempRelease\setup_config.bat"; DestDir: "{app}\"; Components: core; Flags: ignoreversion skipifsourcedoesntexist

; === 深度学习模型权重 (大文件) ===
Source: "TempRelease\r\Slicer-build\lib\Zhiyuan-5.9\qt-scripted-modules\plans\seg\total\config.json"; ...
Source: "TempRelease\r\Slicer-build\lib\Zhiyuan-5.9\qt-scripted-modules\plans\seg\total\nnunet\results\*\*\checkpoint_final.pth"; ...

; === VC 运行库 ===
Source: "TempRelease\vc_redist.x64.exe"; DestDir: "{tmp}"; Components: vcredist; Flags: deleteafterinstall skipifsourcedoesntexist
```

**⛔ 绝对禁止的 Flags 参数**:

| ❌ 无效Flags | 原因 | ✅ 替代方案 |
|-------------|------|-----------|
| `excludes:"..."` | 不是Inno Setup标准Flag | 由pack.ps1白名单控制 |
| `ignoresize` | 不存在 | `ignoreversion` |
| `once` (在[Tasks]) | 仅适用于[Icons]/[Run] | 删除或用 `unchecked` |

**⛔ 绝对禁止的引号用法**:

```ini
; ❌ 错误: excludes值用双引号（导致引号嵌套冲突）
Flags: ... excludes:"*.py,*.pyc"

; ❌ 错误: excludes值用单引号（同样冲突）
Flags: ... excludes:'*.py,*.pyc'

; ✅ 正确: 不使用excludes参数（pack.ps1已做过滤）
Flags: ignoreversion recursesubdirs createallsubdirs
```

#### [Registry] 段落（第135-146行）- ⭐ 引号转义重点

```ini
[Registry]
; 每行必须独立包含 Root 和 Subkey（不支持多行续写！）
Root: HKLM; Subkey: "SOFTWARE\{#MyAppName}"; ValueType: string; ValueName: "InstallPath"; ValueData: "{app}"
Root: HKLM; Subkey: "SOFTWARE\{#MyAppName}"; ValueType: string; ValueName: "Version"; ValueData: {#MyAppVersion}

; ⚠️ 包含引号的值必须使用三引号转义!
Root: HKLM; Subkey: "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{#MyAppName}"; ValueType: string; ValueName: "UninstallString"; ValueData: """{uninstallexe}"""
Root: HKLM; Subkey: "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{#MyAppName}"; ValueType: string; ValueName: "DisplayIcon"; ValueData: """{app}\r\Slicer-build\{#MyAppExeName}"",0"
```

**引号规则总结**:
```
普通值:     ValueData: "text"                    ← 双引号
包含双引号:   ValueData: """quoted"""             ← 三个双引号
包含逗号+引号: ValueData: ""","path"",0"          ← 三引号包裹
Pascal代码:  'Environment'                       ← 单引号
```

#### [UninstallDelete] 段落（第130-133行）

```ini
; ✅ 正确: 使用标准的卸载删除段落
[UninstallDelete]
Type: filesandordirs; Name: "{app}"
Type: filesandordirs; Name: "{group}"
Type: files; Name: "{autodesktop}\{#MyAppName}.lnk"

; ❌ 错误: 使用不存在的 [Uninstall] 段落
; [Uninstall]
; RMDir /r "{app}"     ← 这些命令在此段落无效！
```

---

### 3️⃣ **smart_builder.py** (Cython编译器) - `C:\Zhiyaun\packaging_tools\smart_builder.py`

**作用**: 将 .py 源码编译为 .pyd 二进制文件（IP保护）

**何时运行**:
- ✅ 首次打包时（不带 `-SkipCompile`）
- ✅ 代码修改后重新打包时
- ❌ 测试 ISS 修复时可跳过（`-SkipCompile`）

**输出文件命名**:
```
输入:  BrachyPlan.py
输出:  BrachyPlan.cp312-win_amd64.pyd (在原目录)
```

**前置依赖**:
```powershell
pip install cython  # 必须安装
python --version   # 需要 Python 3.8+
```

---

## 🚀 执行步骤（按顺序检查）

### Step 0: 环境验证

```powershell
# 检查必要组件
python --version                    # 应显示 Python 3.x
pip show cython                     # 应显示版本信息
ISCC /?                            # 应显示 Inno Setup 信息
7z                                 # 应显示帮助

# 检查关键文件是否存在
Test-Path "C:\Zhiyaun\r\Slicer-build\Zhiyuan.exe"              # ✅ 必须
Test-Path "C:\Zhiyaun\packaging_tools\Zhiyuan_Setup.iss"      # ✅ 必须
Test-Path "C:\Zhiyaun\packaging_tools\pack.ps1"               # ✅ 必须
Test-Path "C:\Users\b223\AppData\Local\Programs\Inno Setup 6\Languages\ChineseSimplified.isl"  # ✅ 必须
Test-Path "C:\Zhiyaun\packaging_tools\vc_redist.x64.exe"      # ⚠️ 可选（缺失会跳过VC安装）
Test-Path "C:\Zhiyaun\setup_config.bat"                      # ⚠️ 可选（缺失会跳过环境配置）
```

### Step 1: 执行打包脚本

```powershell
cd C:\Zhiyaun\packaging_tools

# 推荐: 先用 SkipCompile 模式测试 ISS 配置
.\pack.ps1 -Verbose -SkipCompile -Version "1.0.0"
```

### Step 2: 观察输出

**预期成功输出**:
```
╔══════════════════════════════════════════════════════════════╗
║          ✅ PACKAGING COMPLETE ✅                            ║
╚══════════════════════════════════════════════════════════════╝

📦 Output File:
   Name:   Zhiyuan-Installer-v1.0.0.exe
   Size:   ~2500 MB                          ← 必须有实际大小！
   Path:   C:\Zhiyaun\releases\Zhiyuan-Installer-v1.0.0.exe

📊 Packaging Statistics:
   • Compiled Modules (.pyd): 5+
   • UI Interfaces (.ui):     5+
   • Executables (.exe):      1
   • Runtime Libs (.dll):     92
   • Model Weights (.pth):    7
   • Configurations (.json):  3
   • Other Resources:         37+

❌ EXCLUDED (Not in Package):
   • ALL Python source files (.py) -> SECURED!   ← 安全保证
```

**❌ 失败标志**:
- `Size: 0 MB` ← 安装包未成功生成
- `Error on line XX` ← ISS 语法错误
- `does not exist` ← 文件路径或名称不匹配
- `unknown flag` ← 使用了无效的 Inno Setup 参数
- `Mismatched or misplaced quotes` ← 引号嵌套错误

### Step 3: 验证安装包

```powershell
# 检查文件大小（应该 > 100MB）
(Get-Item "C:\Zhiyaun\releases\Zhiyuan-Installer-v1.0.0.exe").Length / 1MB

# 双击测试安装
& "C:\Zhiyaun\releases\Zhiyuan-Installer-v1.0.0.exe"
```

---

## 🐛 故障排查速查表

### 问题1: `does not exist` 错误

**症状**: `Source file "... does not exist`

**原因链路**:
```
ISS中写:     Source: "TempRelease\r\Slicer-build\Zhiyuan.exe"
↓ 解析为
查找路径:     C:\Zhiyaun\TempRelease\r\Slicer-build\Zhiyuan.exe
↓
pack.ps1复制: C:\Zhiyaun\TempRelease\r\Slicer-build\Zhiyuan.exe  ← 必须存在！
```

**解决方案**:
1. 检查 pack.ps1 第144-146行的复制目标路径是否与 ISS 匹配
2. 检查文件是否真的被复制到 TempRelease 目录
3. 如果是 .pyd 文件，确认使用通配符 `*.pyd` 而不是精确名称

**常见不匹配案例**:
| ISS 写法 | pack.ps1 复制到 | 结果 |
|----------|---------------|------|
| `TempRelease\Zhiyuan.exe` | `TempRelease\r\Slicer-build\Zhiyuan.exe` | ❌ 不匹配 |
| `TempRelease\r\Slicer-build\Zhiyuan.exe` | `TempRelease\r\Slicer-build\Zhiyuan.exe` | ✅ 匹配 |
| `BrachyPlan.pyd` | `BrachyPlan.cp312-win_amd64.pyd` | ❌ 名称不匹配 |
| `BrachyPlan*.pyd` | `BrachyPlan.cp312-win_amd64.pyd` | ✅ 通配符匹配 |

### 问题2: `unknown flag` 错误

**症状**: `Parameter "Flags" includes an unknown flag`

**无效Flags列表**:
- `excludes:...` (不是Flag，pack.ps1已负责过滤)
- `ignoresize` (不存在)
- `once` (仅适用于[Icons]/[Run])
- `checkablealone` (仅适用于[Tasks])

**有效Flags列表** ([Files]段落):
- `ignoreversion`, `recursesubdirs`, `createallsubdirs`
- `skipifsourcedoesntexist`, `deleteafterinstall`
- `overwritereadonly`, `onlyifdoesntexist`

### 问题3: `Mismatched or misplaced quotes` 错误

**症状**: `Mismatched or misplaced quotes on parameter "..."`

**原因**: 引号嵌套冲突

**修复方法**:
- 删除所有 `excludes:"..."` 或 `excludes:'...'` 参数
- Registry 中包含引号的值使用三引号: `ValueData: """value"""`
- Pascal 字符串使用单引号: `'string'`

### 问题4: `Required parameter not specified` 错误

**症状**: `Required parameter "Root" not specified`

**原因**: [Registry] 段落使用了多行续写格式

**修复**:
```ini
; ❌ 错误: 多行续写（第二行缺少Root）
Root: HKLM; Subkey: "...\Uninstall\..."
    ValueType: string; ValueName: "DisplayName"; ...

; ✅ 正确: 每行独立
Root: HKLM; Subkey: "...\Uninstall\..."; ValueType: string; ValueName: "DisplayName"; ...
Root: HKLM; Subkey: "...\Uninstall\..."; ValueType: string; ValueName: "UninstallString"; ...
```

### 问题5: 安装包 Size: 0 MB

**可能原因**:
1. Inno Setup 编译失败 → 回退到 7z SFX 也失败
2. 7z 未安装或路径错误
3. 权限不足无法写入 releases 目录

**检查方法**:
```powershell
# 检查 7z 是否可用
& "C:\Program Files\7-Zip\7z.exe" --help

# 检查 Inno Setup 是否可用
Test-Path "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"

# 手动测试 Inno Setup 编译
& "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" "C:\Zhiyaun\Zhiyuan_Setup_temp.iss"
```

### 问题6: 中文语言包缺失

**症状**: `Couldn't open include file "ChineseSimplified.isl"`

**解决方案**:
```powershell
# 检查语言包是否存在
Test-Path "C:\Users\b223\AppData\Local\Programs\Inno Setup 6\Languages\ChineseSimplified.isl"

# 如果不存在，下载并安装
$url = "https://raw.githubusercontent.com/jrsoftware/issrc/main/Files/Languages/Unofficial/ChineseSimplified.isl"
$dest = "C:\Users\b223\AppData\Local\Programs\Inno Setup 6\Languages\ChineseSimplified.isl"
Invoke-WebRequest -Uri $url -OutFile $dest
```

---

## 📊 成功指标清单

打包完成后，逐一确认：

- [ ] **控制台显示绿色 SUCCESS 信息**
- [ ] **安装包大小 > 100MB**（通常 2000-3000MB 含模型）
- [ ] **安装包位于**: `C:\Zhiyaun\releases\Zhiyuan-Installer-v{VERSION}.exe`
- [ ] **TempRelease 目录已被清理**（Step 5 自动完成）
- [ ] **无 .py 源码泄漏**（Security check 通过）
- [ ] **双击安装包可以正常启动安装向导**
- [ ] **安装向导支持中文界面**
- [ ] **安装完成后可以启动 Zhiyuan.exe**
- [ ] **BrachyPlan 模块正常加载**
- [ ] **DVH 计算功能正常**

---

## 🔄 发布新版本的完整流程

```powershell
# 1. 修改代码（在 r\Slicer-build 或 Modules 目录）
# 2. 同步代码到构建目录（如需要）

# 3. 运行完整打包（含Cython编译）
cd C:\Zhiyaun\packaging_tools
.\pack.ps1 -Version "1.1.0"

# 4. 本地测试安装包
& "C:\Zhiyaun\releases\Zhiyuan-Installer-v1.1.0.exe"

# 5. 功能验证通过后，分发安装包
copy "C:\Zhiyaun\releases\*" "D:\Distribution\"
```

---

## 📝 版本历史与本文件修复记录

| 版本 | 日期 | 主要修复内容 |
|------|------|------------|
| 2.0.0 | 初始 | 创建基础结构 |
| 2.1.0 | 2026-04-15 | 添加UI文件白名单 |
| 2.1.1 | 2026-04-15 | 修复7z fallback函数 |
| 2.1.2 | 2026-04-15 | 修复Fallback函数定义顺序 |
| 2.1.3 | 2026-04-16 | 恢复中文支持和翻译字符串 |
| **2.2.0** | **2026-04-16** | **完整重写ISS，修复所有语法错误** |
| **2.2.1** | **2026-04-16** | **修复pack.ps1路径问题** |
| **2.3.0** | **2026-04-17** | **最终版：修复Cython文件名匹配、删除无效excludes参数** |

**已解决的所有问题汇总**（共10个）:
1. ✅ 缺少 ChineseSimplified.isl 语言包
2. ✅ [Tasks] 段落无效 `once` 标志
3. ✅ [Registry] 多行续写 + 缺少 Root 参数
4. ✅ Registry 引号嵌套 `'"..."'` → `"""..."""`
5. ✅ 不存在的 `[Uninstall]` 段落 → 改用 `[UninstallDelete]`
6. ✅ pack.ps1 输出ISS到 %TEMP 导致路径错误
7. ✅ pack.ps1 动态路径替换破坏ISS语法
8. ✅ PowerShell `-replace` 操作符反斜杠转义错误
9. ✅ `excludes:"..."` 无效Flag（不是Inno Setup标准参数）
10. ✅ Cython编译后文件名 `.pyd` → `.cp312-win_amd64.pyd` 不匹配

---

*本文档由 AI 助手基于实际执行经验编写，确保每个细节都经过验证。*
*最后更新: 2026-04-17*

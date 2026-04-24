# Zhiyuan 打包安装指南

> 最后更新：2026-04-15

## 快速打包流程

### 前置条件
- 7-Zip 已安装（用于压缩和创建SFX）
- 代码已同步至源目录并上传GitHub

---

## 步骤1：代码检查与同步

### 1.1 检查绝对路径（确保无硬编码）
```powershell
# 在 BrachyPlan.py 中搜索硬编码路径
Select-String -Path "r\Slicer-build\lib\Zhiyuan-5.9\qt-scripted-modules\BrachyPlan.py" -Pattern "C:\\\\|C:/" | Select-Object -First 5
```

**预期结果**：只应找到 `__file__` 和 `dirname` 相关的相对路径用法，无硬编码绝对路径。

### 1.2 同步构建目录 → 源目录
```powershell
cd C:\Zhiyaun

# 同步主模块
xcopy /Y "r\Slicer-build\lib\Zhiyuan-5.9\qt-scripted-modules\BrachyPlan.py" "Modules\Scripted\BrachyPlan\BrachyPlan.py"

# 同步plans目录（含模型权重）
xcopy /Y /E "r\Slicer-build\lib\Zhiyuan-5.9\qt-scripted-modules\plans" "Modules\Scripted\BrachyPlan\plans"
```

### 1.3 上传GitHub
```powershell
cd C:\Zhiyaun
git add Modules/Scripted/BrachyPlan/BrachyPlan.py Modules/Scripted/BrachyPlan/plans PACKAGING_GUIDE.md CLAUDE.md
git commit -m "Update: [填写本次更改摘要]"
git push origin master
```

---

## 步骤2：创建7z压缩包

### 2.1 排除不必要的文件

确保 `exclude_list.txt` 内容如下：
```
r\Slicer-build\lib\Zhiyuan-5.9\qt-scripted-modules\plans\__pycache__\
r\Slicer-build\lib\Zhiyuan-5.9\qt-scripted-modules\plans\dose_pre\__pycache__\
r\Slicer-build\lib\Zhiyuan-5.9\qt-scripted-modules\plans\seg\total\nnunet\results\__MACOSX\
r\Slicer-build\lib\Zhiyuan-5.9\qt-scripted-modules\plans\seg\total\*.DS_Store
r\Slicer-build\lib\Zhiyuan-5.9\qt-scripted-modules\plans\seg\total\*._*
r\Slicer-build\lib\Zhiyuan-5.9\qt-scripted-modules\Temp\
```

### 2.2 执行压缩
```powershell
cd C:\Zhiyaun
& "C:\Program Files\7-Zip\7z.exe" a -t7z -m0=lzma2 -mx=9 -mfb=256 -md=32m -ms=on -xr@"C:\Zhiyaun\exclude_list.txt" "Zhiyuan-Portable-v{VERSION}.7z" "r\Slicer-build"
```

**参数说明**：
- `-t7z`：7z格式（压缩率最高）
- `-mx=9`：最大压缩级别
- `-mfb=256`：字典大小256MB
- `-md=32m`：匹配内存32MB
- `-ms=on`：固实压缩（提高压缩率）
- `-xr@exclude_list.txt`：排除缓存文件

**预期输出**：`Zhiyuan-Portable-v{VERSION}.7z`（约2.3GB）

---

## 步骤3：创建自解压Installer（SFX）

### 3.1 确保配置文件存在

`sfx_config.txt` 内容：
```ini
;!@Install@!UTF-8!
Title="Zhiyuan v{VERSION} - Brachytherapy Planning System"
BeginPrompt="欢迎使用 Zhiyuan 近距离放射治疗计划系统！\n\n本程序将安装 Zhiyuan 到您的电脑。\n\n安装路径: %PROGRAMFILES%\\Zhiyuan\n\n点击 '是' 继续，'取消' 退出。"
Progress="yes"
Directory="%%P\Zhiyuan"
ExecuteFile="r\Slicer-build\Zhiyuan.exe"
ExecuteParameters=""
;!@InstallEnd@!
```

> **注意**：将 `{VERSION}` 替换为实际版本号，如 `1.0.0`

### 3.2 合并生成Installer
```powershell
cd C:\Zhiyaun
cmd /c copy /b "C:\Program Files\7-Zip\7z.sfx" + "sfx_config.txt" + "Zhiyuan-Portable-v{VERSION}.7z" "Zhiyuan-Setup-v{VERSION}.exe"
```

**预期输出**：`Zhiyuan-Setup-v{VERSION}.exe`（约2.37GB）

---

## 步骤4：验证Installer

### 4.1 检查文件
```powershell
Get-Item "Zhiyuan-Setup-v{VERSION}.exe" | Select-Object Name, @{N='Size(MB)';E={[math]::Round($_.Length/1MB,2)}}, LastWriteTime
```

### 4.2 本地测试（可选但推荐）
1. 将 `Zhiyuan-Setup-v{VERSION}.exe` 复制到临时目录
2. 双击运行，选择测试安装路径（如 `D:\Test_Zhiyuan`）
3. 解压完成后运行 `setup_config.bat`
4. 验证能正常启动

---

## 目标机器安装流程

### 用户操作步骤

```
1️⃣ 复制 Zhiyuan-Setup-v{VERSION}.exe 到目标电脑

2️⃣ 双击运行 Installer
   → 选择安装路径（默认 C:\Program Files\Zhiyuan）
   → 点击"是"确认
   → 等待解压完成（3-5分钟）

3️⃣ 进入安装目录，双击 setup_config.bat
   → 自动设置环境变量
   → 自动创建桌面/开始菜单快捷方式

4️⃣ 重启电脑 或 注销重新登录
   （刷新环境变量）

5️⃣ 启动软件
   → 双击桌面 "Zhiyuan" 快捷方式
```

---

## 版本更新时的完整Checklist

每次发布新版本前，按此清单执行：

### 代码准备
- [ ] 所有代码修改已在构建目录 (`r\Slicer-build\...`) 完成
- [ ] 无硬编码绝对路径（仅用 `os.path.dirname(__file__)` 相对路径）
- [ ] Python语法检查通过：`python -m py_compile BrachyPlan.py`
- [ ] 功能测试通过（至少基本功能）

### 同步与备份
- [ ] 构建目录 → 源目录同步完成
- [ ] GitHub推送成功（记录commit hash）
- [ ] `PACKAGING_GUIDE.md` 已更新（如有变更）

### 打包
- [ ] 7z压缩包创建成功
- [ ] SFX配置文件版本号已更新
- [ ] Installer (.exe) 创建成功
- [ ] 文件大小合理（约2.3-2.4 GB）

### 测试
- [ ] 本地解压测试通过
- [ ] `setup_config.bat` 执行无报错
- [ ] 软件启动正常
- [ ] 核心功能可用（加载CT、规划、DVH显示）

---

## 文件结构总览

```
C:\Zhiyaun\
├── Zhiyuan-Setup-v{VERSION}.exe    ← 分发给用户的安装包
├── Zhiyuan-Portable-v{VERSION}.7z   ← 备用压缩包
├── sfx_config.txt                   ← SFX配置（不要删除）
├── setup_config.bat                 ← 安装后配置脚本
├── exclude_list.txt                 ← 打包排除列表
├── Create-Installer.ps1             ← 辅助脚本
├── PACKAGING_GUIDE.md               ← 详细打包文档
│
├── r\Slicer-build\                  ← 构建目录（源）
│   ├── Zhiyuan.exe
│   └── lib\Zhiyuan-5.9\
│       └── qt-scripted-modules\
│           ├── BrachyPlan.py       ← 主模块
│           └── plans\              ← 算法+模型权重
│
└── Modules\Scripted\BrachyPlan\     ← 源目录（Git追踪）
    ├── BrachyPlan.py
    ├── Resources\
    └── plans\
```

---

## 常见问题

| 问题 | 解决方案 |
|------|---------|
| **PowerShell报错 `positional parameter`** | 使用 `cmd /c copy /b ...` |
| **压缩包太大** | 检查是否误包含 `__pycache__` 或临时文件 |
| **目标机器无法启动** | 安装 VC++ Redistributable (x64) |
| **模型加载失败** | 运行 `setup_config.bat` 设置环境变量 |
| **需要更新版本号** | 修改 `sfx_config.txt` 中的 Title 字段 |

---

## 一键打包脚本（高级用法）

可将以下内容保存为 `pack.ps1`，每次只需修改版本号：

```powershell
param(
    [string]$Version = "1.0.0"
)

$ErrorActionPreference = "Stop"

Write-Host "=== Zhiyuan 打包脚本 v$Version ===" -ForegroundColor Cyan

# Step 1: Sync to source
Write-Host "`n[1/4] 同步代码到源目录..." -ForegroundColor Yellow
xcopy /Y "r\Slicer-build\lib\Zhiyuan-5.9\qt-scripted-modules\BrachyPlan.py" "Modules\Scripted\BrachyPlan\BrachyPlan.py"

# Step 2: Create 7z
Write-Host "[2/4] 创建压缩包..." -ForegroundColor Yellow
& "C:\Program Files\7-Zip\7z.exe" a -t7z -m0=lzma2 -mx=9 -mfb=256 -md=32m -ms=on `
    -xr@"C:\Zhiyaun\exclude_list.txt" `
    "Zhiyuan-Portable-v$Version.7z" "r\Slicer-build"

# Step 3: Create SFX Installer
Write-Host "[3/4] 创建安装包..." -ForegroundColor Yellow
$config = Get-Content "sfx_config.txt" -Raw -Replace "{VERSION}", $Version
Set-Content "sfx_config_temp.txt" $config
cmd /c copy /b "C:\Program Files\7-Zip\7z.sfx" + "sfx_config_temp.txt" + "Zhiyuan-Portable-v$Version.7z" "Zhiyuan-Setup-v$Version.exe"
Remove-Item "sfx_config_temp.txt" -Force

# Step 4: Verify
Write-Host "[4/4] 验证..." -ForegroundColor Yellow
$file = Get-Item "Zhiyuan-Setup-v$Version.exe"
Write-Host "`n✅ 打包完成！" -ForegroundColor Green
Write-Host "   文件: $($file.Name)" -ForegroundColor White
Write-Host "   大小: $([math]::Round($file.Length/1MB, 2)) MB" -ForegroundColor White
Write-Host "   时间: $($file.LastWriteTime)" -ForegroundColor White
```

**使用方法**：
```powershell
.\pack.ps1 -Version "1.1.0"
```

---

*此文档随项目更新而维护*

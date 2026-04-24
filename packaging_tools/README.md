# Zhiyuan Packaging Tools

> 专业源码保护与安装包生成工具集
> 版本: 2.0.0 | 更新日期: 2026-04-15

---

## 📁 目录结构

```
C:\Zhiyaun\packaging_tools\
├── smart_builder.py          # 核心：智能依赖分析 + Cython编译
├── Zhiyuan_Setup.iss         # Inno Setup 安装脚本（白名单机制）
├── pack.ps1                 # 一键打包主控脚本
├── UI_MIGRATION_GUIDE.md    # UI加载迁移指南
└── README.md                # 本文件
```

---

## 🚀 快速开始

### 前置条件

1. **Python 3.8+** 已安装
2. **Cython** 已安装 (`pip install cython`)
3. **7-Zip** 已安装 (用于备用方案)
4. **Inno Setup 6** (可选，推荐)

### 一键打包命令

```powershell
cd C:\Zhiyaun\packaging_tools

# 使用默认版本号 (1.0.0)
.\pack.ps1

# 指定版本号
.\pack.ps1 -Version "1.1.0"

# 跳过编译步骤（如果已编译过）
.\pack.ps1 -SkipCompile -Version "1.1.0"

# 详细输出模式
.\pack.ps1 -Verbose -Version "1.2.0"
```

---

## 🔧 工具详解

### 1. smart_builder.py - 智能构建器

**功能**：
- AST依赖分析（自动找出所有被引用的.py文件）
- 动态UI检测（自动发现引用的.ui文件）
- .ui → .py 编译（使用pyuic）
- Cython编译（.py → .pyd，源码保护）
- 中间文件清理

**手动运行**：
```python
cd C:\Zhiyaun
python packaging_tools/smart_builder.py
```

**配置项**（在脚本顶部修改）：
- `PROJECT_ROOT`: 项目根目录
- `BUILD_DIR`: 构建目录
- `ENTRY_POINT`: 入口模块（BrachyPlan.py）
- `manual_include_list`: 动态加载的额外文件
- `EXCLUDE_FILES`: 要排除的废弃文件列表

---

### 2. Zhiyuan_Setup.iss - Inno Setup 配置

**特性**：
- ✅ 白名单打包机制（只包含必要文件）
- ✅ 排除所有源码（.py, .ui）
- ✅ 排除废弃版本（v1备份等）
- ✅ 自动创建快捷方式
- ✅ 安装后运行配置脚本
- ✅ 版本号动态传入

**参数**：
```bash
ISCC.exe "Zhiyuan_Setup.iss" /DMyAppVersion=1.0.0
```

---

### 3. pack.ps1 - 主控脚本

**工作流程**：
```
接收版本号
    ↓
[Step 0] 环境验证
    ↓
[Step 1] Cython编译（调用smart_builder.py）
    ↓
[Step 2] 创建沙箱目录（TempRelease/）
    ↓
[Step 3] 白名单文件复制（仅复制必要文件）
    ↓
[Step 4] 生成Installer（Inno Setup 或 7z SFX）
    ↓
[Step 5] 清理沙箱目录
    ↓
输出: Zhiyuan-Installer-v{VERSION}.exe
```

**参数说明**：

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `-Version` | string | `"1.0.0"` | 软件版本号 |
| `-SkipCompile` | switch | `$false` | 跳过Cython步骤 |
| `-Verbose` | switch | `$false` | 详细输出 |
| `-SourceDir` | string | `"r\Slicer-build"` | 构建目录名 |
| `-OutputDir` | string | `"releases"` | 输出目录名 |
| `-TempDir` | string | `"TempRelease"` | 临时沙箱目录 |

---

### 4. UI_MIGRATION_GUIDE.md - 迁移指南

**内容**：
- 从 loadUI() 到 compiled .pyd 的迁移方法
- 多UI文件处理方案
- 向后兼容的fallback机制
- 测试检查清单

---

## 📦 输出产物

执行 `pack.ps1` 后生成：

```
C:\Zhiyaun\releases\
└── Zhiyuan-Installer-v1.0.0.exe   (~2.4 GB)
```

**包含内容**：
- ✅ Zhiyuan.exe（主程序）
- ✅ 所有 .pyd 文件（编译后的Python模块）
- ✅ DLL库（运行时依赖）
- ✅ 模型权重.pth文件（~1.2GB）
- ✅ 配置.json文件
- ✅ 图标、图片资源
- ✅ setup_config.bat（自动配置）

**不包含**：
- ❌ 任何 .py 源码文件
- ❌ 任何 .ui 设计文件
- ❌ 废弃版本（v1, backup等）
- ❌ __pycache__ 缓存
- ❌ 构建中间文件

---

## ⚠️ 注意事项

### 动态加载处理

如果代码使用了以下方式加载模块，需要手动添加到 `manual_include_list`：
- `__import__()`
- `importlib.import_module()`
- `exec()` / `eval()` 字符串导入
- 基于条件的 import

### Cython兼容性

部分Python特性可能无法被Cython正确编译：
- `*args`, `**kwargs` 在某些情况下
- 装饰器 @property 的复杂用法
- 元类(metaclass)动态创建
- `type()` 动态类创建

遇到问题时，将对应文件从编译列表中排除即可。

---

## 🔍 故障排查

### 问题：Cython编译失败
```powershell
# 检查Cython是否安装
pip show cython

# 重新安装
pip install --upgrade cython
```

### 问题：Inno Setup找不到
```powershell
# 使用7z SFX作为备选方案
# pack.ps1会自动降级为SFX方式
```

### 问题：某些模块找不到
```powershell
# 手动添加到 manual_include_list
# 编辑 packaging_tools/smart_builder.py
manual_include_list = [
    "plans/special_module.py",
]
```

---

## 📊 工作流对比

| 方案 | 源码保护 | 用户体验 | 打包大小 | 复杂度 |
|------|----------|----------|----------|--------|
| **旧方案 (7z SFX)** | ❌ 无 | ⭐⭐ 一般 | ~2.3 GB | 低 |
| **新方案 (Cython+Inno)** | ✅ 强 | ⭐⭐⭐⭐ 专业 | ~2.4 GB | 中 |

---

## 🔄 更新软件后重新打包

```powershell
cd C:\Zhiyaun\packaging_tools

# 1. 同步代码（如果有更改）
# （确保 r/Slicer-build 是最新的）

# 2. 执行打包
.\pack.ps1 -Version "1.1.0"

# 3. 分发 releases/Zhiyuan-Installer-v1.1.0.exe
```

---

*此工具集由 Zhiyuan 开发团队维护*

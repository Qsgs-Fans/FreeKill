# ============================================================
#  FreeKill 一键编译 & 部署脚本
#  用法: .\build.ps1 [-Clean] [-NoDeploy] [-ServerOnly] [-Run]
# ============================================================
param(
    [switch]$Clean,        # 清理后重新编译
    [switch]$NoDeploy,     # 仅编译，不部署 DLL
    [switch]$ServerOnly,   # 编译纯服务器版（无 GUI）
    [switch]$Run           # 编译完成后直接运行
)

$ErrorActionPreference = "Stop"
$ScriptDir = $PSScriptRoot
$BuildDir  = Join-Path $ScriptDir "build"
$IncludeDir = Join-Path $ScriptDir "include"
$LibDir     = Join-Path $ScriptDir "lib\win"
$CMakeModuleDir = Join-Path $ScriptDir "cmake"

# ---- 路径配置 ----
$QtDir      = "C:\Qt\6.11.1\mingw_64"
$MinGWDir   = "C:\Qt\Tools\mingw1310_64"
$OpenSSLDir = "$MinGWDir\opt"
$CMakeBin   = "C:\Program Files\CMake\bin"
$GitBin     = "C:\Program Files\Git\bin"   # 提供 sh，供 genfkver.sh 使用
$CMake      = "$CMakeBin\cmake.exe"

# ---- 环境设置 ----
$env:Path = "$MinGWDir\bin;$QtDir\bin;$CMakeBin;$GitBin;$env:Path"

# CMake 4.x 要求路径用正斜杠（在 PATH 设置之后再规范化，避免影响 PATH）
$QtDir = $QtDir -replace '\\', '/'
$OpenSSLDir = $OpenSSLDir -replace '\\', '/'
$IncludeDir = $IncludeDir -replace '\\', '/'
$LibDir = $LibDir -replace '\\', '/'
$CMakeModuleDir = $CMakeModuleDir -replace '\\', '/'

# ---- 前置: 终止已有进程 ----
$exePath = Join-Path $BuildDir "FreeKill.exe"
if (Get-Process -Name "FreeKill" -ErrorAction SilentlyContinue) {
    Write-Host "[*] 终止已运行的 FreeKill..." -ForegroundColor DarkYellow
    taskkill /F /IM FreeKill.exe 2>$null | Out-Null
    Start-Sleep -Seconds 1
}

# ---- 检查依赖文件 ----
if (-not (Test-Path "$IncludeDir\lua\lua.h")) {
    throw "缺少 Lua 头文件: $IncludeDir\lua\lua.h"
}
if (-not (Test-Path "$LibDir\lua54.dll")) {
    throw "缺少 Lua DLL: $LibDir\lua54.dll"
}
if (-not (Test-Path "$LibDir\sqlite3.dll")) {
    throw "缺少 SQLite3 DLL: $LibDir\sqlite3.dll"
}
if (-not (Test-Path "$LibDir\libgit2.dll")) {
    throw "缺少 libgit2 DLL: $LibDir\libgit2.dll"
}

# ---- 步骤 1: 清理（可选） ----
if ($Clean) {
    Write-Host "[1/4] 清理旧构建..." -ForegroundColor Cyan
    if (Test-Path $BuildDir) {
        Remove-Item -Recurse -Force $BuildDir
    }
}

# 确保 stub chrono_io.h 存在（MinGW 13.1 兼容性修复）
$stubDir = Join-Path $IncludeDir "bits"
if (-not (Test-Path "$stubDir\chrono_io.h")) {
    New-Item -ItemType Directory -Path $stubDir -Force | Out-Null
    "" | Out-File "$stubDir\chrono_io.h" -Encoding UTF8
}

# ---- 步骤 2: 创建 build 目录并 CMake 配置 ----
if (-not (Test-Path $BuildDir)) {
    Write-Host "[1/4] 创建 build 目录..." -ForegroundColor Cyan
    New-Item -ItemType Directory -Path $BuildDir -Force | Out-Null
}

Write-Host "[2/4] CMake 配置..." -ForegroundColor Cyan
Push-Location $BuildDir
try {
    $CMakeArgs = @(
        "..",
        "-G", "MinGW Makefiles",
        "-DCMAKE_PREFIX_PATH=$QtDir",
        "-DOPENSSL_ROOT_DIR=$OpenSSLDir",
        "-DLUA_INCLUDE_DIR=$IncludeDir/lua",
        "-DLUA_LIBRARY=$LibDir/lua54.dll",
        "-DSQLite3_INCLUDE_DIR=$IncludeDir",
        "-DSQLite3_LIBRARY=$LibDir/sqlite3.dll",
        "-DCMAKE_MODULE_PATH=$CMakeModuleDir"
    )
    if ($ServerOnly) {
        $CMakeArgs += "-DFK_SERVER_ONLY=ON"
    }
    & $CMake $CMakeArgs
    if ($LASTEXITCODE -ne 0) { throw "CMake 配置失败" }
} finally {
    Pop-Location
}

# ---- 步骤 3: 编译 ----
Write-Host "[3/4] 编译中..." -ForegroundColor Cyan
Push-Location $BuildDir
try {
    & $CMake --build . --parallel
    if ($LASTEXITCODE -ne 0) { throw "编译失败" }
} finally {
    Pop-Location
}

# ---- 步骤 4: 部署 DLL (可选) ----
if (-not $NoDeploy) {
    Write-Host "[4/4] 部署 DLL..." -ForegroundColor Cyan

    # 项目 DLL (客户端/服务器都需要)
    Copy-Item "$LibDir\*.dll" $BuildDir -Force

    # OpenSSL DLL (网络加密需要)
    $OpenSSLBin = "$MinGWDir\opt\bin"
    Copy-Item "$OpenSSLBin\libcrypto-1_1-x64.dll" $BuildDir -Force -ErrorAction SilentlyContinue
    Copy-Item "$OpenSSLBin\libssl-1_1-x64.dll"   $BuildDir -Force -ErrorAction SilentlyContinue

    # 仅 GUI 版需要 Qt 运行时与 QML 模块
    if (-not $ServerOnly) {
        # windeployqt (stderr 有警告时不要中断脚本)
        $WinDeployQt = Join-Path $QtDir "bin\windeployqt.exe"
        $ExePath = Join-Path $BuildDir "FreeKill.exe"
        $QmlDir   = Join-Path $ScriptDir "packages\freekill-core\Fk"
        try {
            & $WinDeployQt $ExePath --qmldir $QmlDir 2>&1 | Out-Null
        } catch {
            Write-Host "  [!] windeployqt 有警告 (通常无害)" -ForegroundColor DarkYellow
        }

        # Qt.labs.qmlmodels (windeployqt 可能遗漏 labs 模块)
        Copy-Item -Recurse "$QtDir\qml\Qt\labs\qmlmodels" "$BuildDir\qml\Qt\labs\" -Force -ErrorAction SilentlyContinue
        Copy-Item "$QtDir\bin\Qt6LabsQmlModels.dll" $BuildDir -Force -ErrorAction SilentlyContinue
        Copy-Item "$QtDir\bin\Qt6QmlMeta.dll" $BuildDir -Force -ErrorAction SilentlyContinue
    }
}

# ---- 完成 ----
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  编译完成！可执行文件: $exePath" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

if ($Run) {
    Write-Host ""
    Write-Host "启动 FreeKill..." -ForegroundColor Cyan
    Set-Location $ScriptDir   # FreeKill 需要从仓库根目录运行
    & $exePath
}

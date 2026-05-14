#Requires -Version 5.1
<#
.SYNOPSIS
    Build ONNX Runtime as a static library on Windows.

.DESCRIPTION
    Wraps tools/ci_build/build.py to produce static .lib files suitable
    for linking into a cross-platform application.

.PARAMETER Config
    CMake build configuration: Debug, Release, RelWithDebInfo, or MinSizeRel.
    Default: Release

.PARAMETER BuildDir
    Output directory for the build. Default: <repo root>\build\Windows

.PARAMETER Parallel
    Number of parallel compile jobs. 0 means "use all cores". Default: 0

.PARAMETER ExtraArgs
    Additional arguments forwarded verbatim to tools/ci_build/build.py.

.EXAMPLE
    .\scripts\build_static.ps1
    .\scripts\build_static.ps1 -Config RelWithDebInfo
    .\scripts\build_static.ps1 -Config Debug -Parallel 4
    .\scripts\build_static.ps1 -ExtraArgs "--use_cuda","--cuda_home","C:\cuda"
#>

[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release', 'RelWithDebInfo', 'MinSizeRel')]
    [string]$Config = 'Release',

    [string]$BuildDir = '',

    [int]$Parallel = 0,

    [string[]]$ExtraArgs = @()
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RootDir   = (Resolve-Path "$PSScriptRoot\..").Path
$BuildDir  = if ($BuildDir) { $BuildDir } else { Join-Path $RootDir 'build\Windows' }

# ---------- locate Python ----------
$PythonExe = $env:PYTHON
if (-not $PythonExe) { $PythonExe = 'python' }
if (-not (Get-Command $PythonExe -ErrorAction SilentlyContinue)) {
    Write-Error "ERROR: '$PythonExe' not found. Set `$env:PYTHON or add Python to PATH."
    exit 1
}

Write-Host '====================================================================' -ForegroundColor Cyan
Write-Host '  Building ONNX Runtime as a static library'
Write-Host "  Config     : $Config"
Write-Host "  Build dir  : $BuildDir"
if ($ExtraArgs) { Write-Host "  Extra args : $($ExtraArgs -join ' ')" }
Write-Host '====================================================================' -ForegroundColor Cyan

$BuildPy = Join-Path $RootDir 'tools\ci_build\build.py'

$Args = @(
    $BuildPy
    '--build_dir', $BuildDir
    '--config',    $Config
    '--update'
    '--build'
    '--skip_tests'
    '--parallel',  $Parallel
    '--cmake_extra_defines'
        'CMAKE_POSITION_INDEPENDENT_CODE=ON'
        'onnxruntime_BUILD_UNIT_TESTS=OFF'
        'CMAKE_DISABLE_FIND_PACKAGE_Protobuf=ON'
        'CMAKE_DISABLE_FIND_PACKAGE_protobuf=ON'
) + $ExtraArgs

& $PythonExe @Args

if ($LASTEXITCODE -ne 0) {
    Write-Error "Build FAILED (exit code $LASTEXITCODE)."
    exit $LASTEXITCODE
}

$OutDir = Join-Path $BuildDir "$Config\$Config"
Write-Host ''
Write-Host '====================================================================' -ForegroundColor Green
Write-Host '  Build complete.'
Write-Host "  Static libraries are in: $OutDir"
Write-Host '  Key artifacts:'
Write-Host '    onnxruntime.lib'
Write-Host '    onnxruntime_common.lib'
Write-Host "  Public headers: $(Join-Path $RootDir 'include\onnxruntime')"
Write-Host '====================================================================' -ForegroundColor Green

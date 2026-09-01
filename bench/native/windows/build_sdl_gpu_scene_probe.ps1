param(
    [switch]$Run,
    [int]$Width = 3780,
    [int]$Height = 2430,
    [int]$Warmup = 30,
    [int]$Frames = 180,
    [int]$Repeats = 3,
    [string]$SdlRuntime = ''
)

$ErrorActionPreference = 'Stop'

$repo = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$target = Join-Path $repo 'target\native-probe'
$archive = Join-Path $target 'SDL3-3.4.12.zip'
$sourceRoot = Join-Path $target 'SDL3-3.4.12-source'
$sdlSource = Join-Path $sourceRoot 'SDL3-3.4.12'
$headers = Join-Path $sdlSource 'include'
$shaders = Join-Path $sdlSource 'src\render\gpu\shaders'
$source = Join-Path $repo 'bench\native\windows\sdl_gpu_scene_probe.cpp'
$executable = Join-Path $target 'sdl_gpu_scene_probe.exe'
$runtimeCopy = Join-Path $target 'SDL3.dll'
$report = Join-Path $repo 'bench\results\sdl-gpu-scene-probe.json'
$downloadUrl = 'https://github.com/libsdl-org/SDL/releases/download/release-3.4.12/SDL3-3.4.12.zip'
$expectedSha256 = '3d4de8967a49c0451e775a0c1e9022092c19fdef41ba38a83fcf031c5a6496e2'

if ([string]::IsNullOrWhiteSpace($SdlRuntime)) {
    $SdlRuntime = Join-Path (Split-Path -Parent $repo) 'CangjieSDL\.sdl3\SDL3.dll'
}
if (-not (Test-Path -LiteralPath $SdlRuntime -PathType Leaf)) {
    throw "SDL runtime not found: $SdlRuntime"
}

New-Item -ItemType Directory -Force -Path $target | Out-Null
if (-not (Test-Path -LiteralPath $archive -PathType Leaf) -or
    (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expectedSha256) {
    Invoke-WebRequest -Uri $downloadUrl -OutFile $archive
}
$actualSha256 = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actualSha256 -ne $expectedSha256) {
    throw "SDL source archive SHA-256 mismatch: $actualSha256"
}
if (-not (Test-Path -LiteralPath $headers -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $sourceRoot | Out-Null
    Expand-Archive -LiteralPath $archive -DestinationPath $sourceRoot -Force
}
if (-not (Test-Path -LiteralPath (Join-Path $headers 'SDL3\SDL.h') -PathType Leaf) -or
    -not (Test-Path -LiteralPath (Join-Path $shaders 'tri_color.vert.dxil.h') -PathType Leaf)) {
    throw 'Verified SDL 3.4.12 headers or renderer shaders are missing after extraction.'
}

$compiler = (Get-Command clang++ -ErrorAction Stop).Source
$arguments = @(
    '-std=c++20',
    '-O2',
    '-Wall',
    '-Wextra',
    '-Werror',
    '-fstack-protector-all',
    "-I$headers",
    "-I$shaders",
    $source,
    '-o',
    $executable
)
& $compiler @arguments
if ($LASTEXITCODE -ne 0) {
    throw "SDL GPU representative-scene probe compilation failed with exit code $LASTEXITCODE"
}
Copy-Item -LiteralPath $SdlRuntime -Destination $runtimeCopy -Force

Write-Output "Built $executable against verified SDL 3.4.12 headers/shaders."
if ($Run) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $report) | Out-Null
    & $executable --width $Width --height $Height --warmup $Warmup --frames $Frames --repeats $Repeats --output $report
    if ($LASTEXITCODE -ne 0) {
        throw "SDL GPU representative-scene probe failed with exit code $LASTEXITCODE"
    }
    Write-Output "Wrote $report"
}

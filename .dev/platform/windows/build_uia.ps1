$ErrorActionPreference = 'Stop'

$devRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$repo = Split-Path -Parent $devRoot
$architecture = switch ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()) {
    'X64' { 'x86_64' }
    'Arm64' { 'arm64' }
    default { throw "Unsupported Windows UIA architecture: $([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture)" }
}
$source = Join-Path $repo 'platform\windows\accessibility\uia\cui_uia.cpp'
$runtimeDirectory = Join-Path $repo "target\native\windows\$architecture"
$runtime = Join-Path $runtimeDirectory 'cui_uia.dll'
$importLibrary = Join-Path $runtimeDirectory 'cui_uia.lib'
$legacyRuntime = Join-Path $runtimeDirectory 'libcui_uia.dll'
$legacyImportLibrary = Join-Path $runtimeDirectory 'libcui_uia.lib'
$compiler = (Get-Command clang++ -ErrorAction Stop).Source

$null = New-Item -ItemType Directory -Path $runtimeDirectory -Force

$arguments = @(
    '-std=c++20',
    '-shared',
    '-O2',
    '-Wall',
    '-Wextra',
    '-Werror',
    '-fstack-protector-all',
    $source,
    '-o',
    $runtime,
    '-lUIAutomationCore',
    '-lOleAut32',
    '-lOle32',
    '-lComCtl32',
    '-lUser32'
)

& $compiler @arguments
if ($LASTEXITCODE -ne 0) {
    throw "Windows UIA native bridge compilation failed with exit code $LASTEXITCODE"
}
if (Test-Path -LiteralPath $importLibrary) {
    Remove-Item -LiteralPath $importLibrary -Force
}
if (Test-Path -LiteralPath $legacyRuntime) {
    Remove-Item -LiteralPath $legacyRuntime -Force
}
if (Test-Path -LiteralPath $legacyImportLibrary) {
    Remove-Item -LiteralPath $legacyImportLibrary -Force
}

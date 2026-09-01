$ErrorActionPreference = 'Stop'

$repo = Split-Path -Parent $PSScriptRoot
$fixture = Join-Path $PSScriptRoot 'fixtures\uia_probe'
$bin = Join-Path $fixture 'target\release\bin'
$architecture = switch ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()) {
    'X64' { 'x86_64' }
    'Arm64' { 'arm64' }
    default { throw "Unsupported Windows UIA architecture: $([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture)" }
}
$runtime = Join-Path $repo "target\native\windows\$architecture\cui_uia.dll"
$process = $null

try {
    & (Join-Path $PSScriptRoot 'build_windows_uia.ps1')
    Push-Location $fixture
    try {
        & cjpm build
        if ($LASTEXITCODE -ne 0) {
            throw "UIA probe build failed with exit code $LASTEXITCODE"
        }
    } finally {
        Pop-Location
    }

    Copy-Item -LiteralPath $runtime -Destination $bin -Force
    Copy-Item -LiteralPath (Join-Path $repo '..\CangjieSDL\.sdl3\SDL3.dll') -Destination $bin -Force
    Copy-Item -LiteralPath (Join-Path $repo '..\CangjieSDL\.sdl3\SDL3_ttf.dll') -Destination $bin -Force

    $executable = Get-ChildItem -LiteralPath $bin -Filter '*.exe' | Select-Object -First 1
    if ($null -eq $executable) {
        throw 'UIA probe executable was not produced'
    }
    $process = Start-Process -FilePath $executable.FullName -WorkingDirectory $bin -PassThru -WindowStyle Hidden

    $deadline = [DateTime]::UtcNow.AddSeconds(10)
    do {
        Start-Sleep -Milliseconds 50
        $process.Refresh()
    } while ($process.MainWindowHandle -eq 0 -and !$process.HasExited -and [DateTime]::UtcNow -lt $deadline)
    if ($process.HasExited -or $process.MainWindowHandle -eq 0) {
        throw 'UIA probe window did not become discoverable'
    }

    Add-Type -AssemblyName UIAutomationClient
    Add-Type -AssemblyName UIAutomationTypes
    $root = [System.Windows.Automation.AutomationElement]::FromHandle([IntPtr]$process.MainWindowHandle)
    $condition = [System.Windows.Automation.PropertyCondition]::new(
        [System.Windows.Automation.AutomationElement]::AutomationIdProperty,
        'uia-action'
    )
    $button = $root.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $condition)
    if ($null -eq $button) {
        throw 'UIA client could not find AutomationId uia-action'
    }
    # Keep this Windows PowerShell 5.1-compatible script ASCII-only while still validating UTF-8 end to end.
    $initialName = -join @([char]0x8C03, [char]0x7528, [char]0x6211, [char]0x20, [char]0x00B7,
        [char]0x20, 'Invoke')
    $invokedName = -join @([char]0x5DF2, [char]0x8C03, [char]0x7528, [char]0x20, [char]0x00B7,
        [char]0x20, 'Invoked')
    if ($button.Current.Name -ne $initialName) {
        throw "Unexpected initial UIA name '$($button.Current.Name)'"
    }
    $querySamples = for ($index = 0; $index -lt 200; $index++) {
        $timer = [System.Diagnostics.Stopwatch]::StartNew()
        $null = $button.Current.Name
        $timer.Stop()
        $timer.Elapsed.TotalMilliseconds
    }
    [Array]::Sort($querySamples)
    $queryP50Ms = $querySamples[[Math]::Floor($querySamples.Count / 2)]
    if ($queryP50Ms -gt 10.0) {
        throw "UIA property query P50 regressed to $queryP50Ms ms"
    }
    $pattern = $button.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
    $roundTrip = [System.Diagnostics.Stopwatch]::StartNew()
    $pattern.Invoke()

    $deadline = [DateTime]::UtcNow.AddSeconds(5)
    do {
        Start-Sleep -Milliseconds 5
    } while ($button.Current.Name -ne $invokedName -and [DateTime]::UtcNow -lt $deadline)
    if ($button.Current.Name -ne $invokedName) {
        throw 'UIA Invoke did not round-trip through the UI thread'
    }
    $roundTrip.Stop()
    if ($roundTrip.Elapsed.TotalMilliseconds -gt 1000.0) {
        throw "UIA Invoke round-trip regressed to $($roundTrip.Elapsed.TotalMilliseconds) ms"
    }
    Write-Output ("Windows UIA provider OK: property query P50 {0:N3} ms, Invoke round-trip {1:N3} ms." -f `
        $queryP50Ms, $roundTrip.Elapsed.TotalMilliseconds)
} finally {
    if ($null -ne $process -and !$process.HasExited) {
        Stop-Process -Id $process.Id
        $process.WaitForExit()
    }
}

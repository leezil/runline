param([int]$Port = 5000)

$ErrorActionPreference = 'Stop'
$flutter = Join-Path $PSScriptRoot '.tools\flutter\bin\flutter.bat'
if (-not (Test-Path -LiteralPath $flutter)) {
    $installedFlutter = Get-Command flutter -ErrorAction SilentlyContinue
    if (-not $installedFlutter) {
        throw 'Flutter SDK is missing. Install Flutter before running this script.'
    }
    $flutter = $installedFlutter.Source
}

$env:PUB_CACHE = Join-Path $PSScriptRoot '.tools\pub-cache'
Push-Location (Join-Path $PSScriptRoot 'runline')
try {
    Write-Host 'Chrome preview: press r to hot reload, R to restart, q to stop.'
    $configArgs = @()
    foreach ($name in @('kakao.web', 'route-api', 'facilities')) {
        $configPath = "config/$name.local.json"
        if (Test-Path -LiteralPath $configPath) {
            $configArgs += "--dart-define-from-file=$configPath"
        }
    }
    & $flutter run -d chrome --web-hostname localhost --web-port $Port @configArgs
    if ($LASTEXITCODE -ne 0) { throw 'Chrome preview failed.' }
} finally {
    Pop-Location
}

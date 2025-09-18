# Run-Backup.ps1
#requires -Version 5.1
chcp 65001 > $null

Write-Host "[INFO] Запуск процесса резервного копирования..." -ForegroundColor Yellow

$pipelinePath = Join-Path $PSScriptRoot 'core\Pipeline.psm1'
if (!(Test-Path $pipelinePath)) {
    Write-Error "Не найден Pipeline.psm1: $pipelinePath"
    exit 1
}
Import-Module -Force -DisableNameChecking $pipelinePath -ErrorAction Stop

$configRoot = Join-Path $PSScriptRoot 'config'
$basesDir   = Join-Path $configRoot 'bases'
$logDir     = Join-Path $PSScriptRoot 'logs'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }

$after = 3
$settingsFile = Join-Path $configRoot 'settings.json'
if (Test-Path $settingsFile) {
    try { $after = [int]((Get-Content $settingsFile -Raw | ConvertFrom-Json).AfterBackup) } catch { $after = 3 }
}

$bases = Get-ChildItem -Path $basesDir -Filter *.json -ErrorAction SilentlyContinue | ForEach-Object { $_.BaseName }
if (-not $bases -or $bases.Count -eq 0) {
    Write-Error "Не найдено ни одной базы в $basesDir"
    exit 1
}

$sessionLog = Join-Path $logDir ("backup_{0}.log" -f (Get-Date -Format 'yyyy-MM-dd_HHmmss'))
function Write-Log {
    param([string]$Message)
    $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[$ts] $Message"
    $line | Out-File -FilePath $sessionLog -Append -Encoding UTF8
    Write-Host $line
}

foreach ($tag in $bases) {
    try {
        $ctx = @{
            Tag        = $tag
            ConfigRoot = $configRoot
            ConfigDir  = $basesDir
            Log        = { param($msg) Write-Log ("[{0}] {1}" -f $tag, $msg) }
        }
        Invoke-Pipeline -Ctx $ctx
    }
    catch {
        Write-Log ("[ОШИБКА][{0}] {1}" -f $tag, $_.Exception.Message)
    }
}

switch ($after) {
    1 { Write-Log "[INFO] Выключаем ПК";  Stop-Computer -Force }
    2 { Write-Log "[INFO] Перезагружаем ПК"; Restart-Computer -Force }
    default { Write-Log "[INFO] Завершено. Действий с ПК нет." }
}

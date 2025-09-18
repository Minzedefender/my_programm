# Run-Backup.ps1
#requires -Version 5.1
chcp 65001 > $null

Write-Host "[INFO] Запуск процесса резервного копирования..." -ForegroundColor Yellow

$modulesRoot = Join-Path $PSScriptRoot 'modules'
Import-Module -Force -DisableNameChecking (Join-Path $modulesRoot 'Common.Crypto.psm1') -ErrorAction Stop
Import-Module -Force -DisableNameChecking (Join-Path $modulesRoot 'Notifications.Telegram.psm1') -ErrorAction Stop

function ConvertTo-Hashtable {
    param([Parameter(Mandatory)]$Object)

    if ($null -eq $Object) { return @{} }
    if ($Object -is [hashtable]) { return $Object }

    if ($Object -is [System.Collections.IDictionary]) {
        $ht = @{}
        foreach ($key in $Object.Keys) {
            $ht[$key] = $Object[$key]
        }
        return $ht
    }

    $result = @{}
    if ($Object.PSObject) {
        foreach ($prop in $Object.PSObject.Properties) {
            $result[$prop.Name] = $prop.Value
        }
    }
    return $result
}

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

$settingsFile = Join-Path $configRoot 'settings.json'
$settingsData = @{}
if (Test-Path $settingsFile) {
    try {
        $settingsData = ConvertTo-Hashtable (Get-Content $settingsFile -Raw | ConvertFrom-Json)
    } catch { $settingsData = @{} }
}

$after = 3
if ($settingsData.ContainsKey('AfterBackup')) {
    try { $after = [int]$settingsData['AfterBackup'] } catch { $after = 3 }
}

$telegramConfig = @{}
if ($settingsData.ContainsKey('Notifications')) {
    $notifications = ConvertTo-Hashtable $settingsData['Notifications']
    if ($notifications.ContainsKey('Telegram')) {
        $telegramConfig = ConvertTo-Hashtable $notifications['Telegram']
    }
}

$telegramEnabled = $false
$telegramChatId  = ''
$telegramSilent  = $false
if ($telegramConfig.Count -gt 0) {
    if ($telegramConfig.ContainsKey('Enabled')) { $telegramEnabled = [bool]$telegramConfig['Enabled'] }
    if ($telegramConfig.ContainsKey('ChatId'))   { $telegramChatId  = "" + $telegramConfig['ChatId'] }
    if ($telegramConfig.ContainsKey('DisableNotification')) { $telegramSilent = [bool]$telegramConfig['DisableNotification'] }
}

$telegramToken = $null
$keyPath     = Join-Path $configRoot 'key.bin'
$secretsPath = Join-Path $configRoot 'secrets.json.enc'
if ($telegramEnabled -and (Test-Path $keyPath) -and (Test-Path $secretsPath)) {
    try {
        $allSecrets = ConvertTo-Hashtable (Decrypt-Secrets -InFile $secretsPath -KeyPath $keyPath)
        if ($allSecrets.ContainsKey('__TelegramBotToken')) {
            $telegramToken = [string]$allSecrets['__TelegramBotToken']
        }
    } catch {
        $telegramToken = $null
    }
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

$results = @()

foreach ($tag in $bases) {
    $artifact = $null
    $status   = 'Success'
    $message  = ''
    try {
        $ctx = @{
            Tag        = $tag
            ConfigRoot = $configRoot
            ConfigDir  = $basesDir
            Log        = { param($msg) Write-Log ("[{0}] {1}" -f $tag, $msg) }
        }
        $artifact = Invoke-Pipeline -Ctx $ctx
    }
    catch {
        $errMessage = $_.Exception.Message
        Write-Log ("[ОШИБКА][{0}] {1}" -f $tag, $errMessage)
        $status  = 'Failed'
        $message = $errMessage
    }

    if ($status -eq 'Success') {
        if ($artifact) {
            $fileName = Split-Path $artifact -Leaf
            if ([string]::IsNullOrWhiteSpace($fileName)) {
                $fileName = 'Успешно'
            }
            $message = $fileName
        } else {
            $status  = 'Skipped'
            $message = 'Отключено в конфиге'
        }
    }

    $results += [pscustomobject]@{
        Tag      = $tag
        Status   = $status
        Message  = $message
        Artifact = $artifact
    }
}

if ($telegramEnabled) {
    if (-not $telegramChatId) {
        Write-Log "[WARN] Telegram-отчёт включён, но chat_id не задан."
    }
    elseif (-not $telegramToken) {
        Write-Log "[WARN] Telegram-отчёт включён, но токен бота отсутствует или не расшифрован."
    }
    else {
        $lines = @("Резервное копирование: $(Get-Date -Format 'dd.MM.yyyy HH:mm:ss')")
        foreach ($result in $results) {
            switch ($result.Status) {
                'Success' {
                    $lines += "✅ $($result.Tag) — $($result.Message)"
                }
                'Skipped' {
                    $lines += "⚠️ $($result.Tag) — $($result.Message)"
                }
                default {
                    $err = if ($result.Message) { [string]$result.Message } else { 'Сбой' }
                    if ($err.Length -gt 200) { $err = $err.Substring(0,200) + '...' }
                    $lines += "❌ $($result.Tag) — $err"
                }
            }
        }

        $actionLine = switch ($after) {
            1 { 'Действие после завершения: выключение ПК' }
            2 { 'Действие после завершения: перезагрузка ПК' }
            default { 'Действие после завершения: без дополнительных действий' }
        }
        $lines += $actionLine

        $text = $lines -join "`n"
        try {
            if ($telegramSilent) {
                Send-TelegramMessage -Token $telegramToken -ChatId $telegramChatId -Text $text -DisableNotification
            } else {
                Send-TelegramMessage -Token $telegramToken -ChatId $telegramChatId -Text $text
            }
            Write-Log "[INFO] Отчёт отправлен в Telegram."
        } catch {
            Write-Log ("[ОШИБКА] Не удалось отправить отчёт в Telegram: {0}" -f $_.Exception.Message)
        }
    }
}

switch ($after) {
    1 { Write-Log "[INFO] Выключаем ПК";  Stop-Computer -Force }
    2 { Write-Log "[INFO] Перезагружаем ПК"; Restart-Computer -Force }
    default { Write-Log "[INFO] Завершено. Действий с ПК нет." }
}
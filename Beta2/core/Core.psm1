# core\Core.psm1

function New-Context {
    param (
        [string]$Tag,
        [string]$ProjectRoot
    )

    # Папка логов
    $logDir = Join-Path $ProjectRoot "logs"
    if (!(Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir | Out-Null
    }

    # Путь к лог-файлу
    $logPath = Join-Path $logDir "$Tag.log"

    # Контекст
    $ctx = [ordered]@{
        Tag        = $Tag
        Root       = $ProjectRoot
        LogPath    = $logPath
        Log        = $null
        Config     = $null
    }

    # Логгер (после определения LogPath)
    Import-Module -Force (Join-Path $ProjectRoot "modules\Common.Logging.psm1")
    $ctx.Log = (New-Logger -LogPath $logPath)

    # Конфигурация
    $cfgPath = Join-Path $ProjectRoot "config\bases\$Tag.json"
    if (-not (Test-Path $cfgPath)) {
        & $ctx.Log "Файл конфигурации не найден: $cfgPath" 'ERROR'
        throw "Конфигурация не найдена: $cfgPath"
    }

    try {
        $ctx.Config = Get-Content $cfgPath -Raw | ConvertFrom-Json
    } catch {
        & $ctx.Log "Ошибка при чтении конфигурации: $($_.Exception.Message)" 'ERROR'
        throw
    }

    return $ctx
}

Export-ModuleMember -Function New-Context

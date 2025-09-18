# modules\System.Services.psm1
function Stop-ConfiguredServices {
    param(
        [hashtable]$Ctx
    )

    $cfg = $Ctx.Config
    $services = $cfg.Services.Names
    $timeout = $cfg.Services.StopTimeoutSec

    if (-not $services -or $services.Count -eq 0) {
        & $Ctx.Log "Список служб для остановки пуст. Пропускаем..." 'DEBUG'
        return
    }

    & $Ctx.Log "Остановка служб: $($services -join ', ')"

    foreach ($name in $services) {
        try {
            Stop-Service -Name $name -Force -ErrorAction Stop
            & $Ctx.Log "Остановлена служба: $name"
        } catch {
            & $Ctx.Log "Не удалось остановить службу $name: $_" 'WARNING'
        }
    }

    if ($timeout -gt 0) {
        & $Ctx.Log "Ожидание $timeout секунд перед продолжением..."
        Start-Sleep -Seconds $timeout
    }
}

function Start-ConfiguredServices {
    param(
        [hashtable]$Ctx
    )

    $cfg = $Ctx.Config
    $services = $cfg.Services.Names

    if (-not $services -or $services.Count -eq 0) {
        & $Ctx.Log "Список служб для запуска пуст. Пропускаем..." 'DEBUG'
        return
    }

    & $Ctx.Log "Запуск служб: $($services -join ', ')"

    foreach ($name in $services) {
        try {
            Start-Service -Name $name -ErrorAction Stop
            & $Ctx.Log "Запущена служба: $name"
        } catch {
            & $Ctx.Log "Не удалось запустить службу $name: $_" 'WARNING'
        }
    }
}

Export-ModuleMember -Function Stop-ConfiguredServices, Start-ConfiguredServices

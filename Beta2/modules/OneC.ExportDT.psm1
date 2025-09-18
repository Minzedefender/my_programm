# modules\OneC.ExportDT.psm1
function Invoke-ExportDT {
    param([hashtable]$Ctx)

    $cfg = $Ctx.Config
    $conn = $cfg.Backup.Conn
    $exe = $cfg.Backup.Path1CExe
    $destDir = $cfg.Backup.Dest
    $login = $cfg.Backup.Login
    $pass = $cfg.Backup.Password

    if (-not (Test-Path $exe)) {
        & $Ctx.Log "Файл 1cestart.exe не найден: $exe" 'ERROR'
        throw "Не найден путь к 1cestart.exe"
    }

    if (-not (Test-Path $conn)) {
        & $Ctx.Log "Каталог базы не найден: $conn" 'ERROR'
        throw "Путь к базе не найден"
    }

    if (-not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Force -Path $destDir | Out-Null
    }

    $timestamp = Get-Date -Format "yyyyMMdd_HHmm"
    $dtFile = Join-Path $destDir ("{0}_{1}.dt" -f $Ctx.Tag, $timestamp)
    $logFile = $dtFile + ".log"

    # Авторизация, если задана
    $auth = ""
    if ($login) {
        Import-Module -Force (Join-Path $Ctx.Root "modules\\Common.Crypto.psm1")
        $auth = "/N$login /P$(Unprotect-String $pass)"
    }

    $cmd = @(
        'DESIGNER'
        "/F""$conn"""
        $auth
        "/DumpIB""$dtFile"""
        "/Out""$logFile"""
    ) -join ' '

    & $Ctx.Log "Запуск конфигуратора: $exe $cmd"
    $proc = Start-Process -FilePath $exe -ArgumentList $cmd -Wait -PassThru -WindowStyle Hidden

    if ($proc.ExitCode -ne 0) {
        & $Ctx.Log "1С завершилась с ошибкой. Код: $($proc.ExitCode)" 'ERROR'
        throw "Ошибка выгрузки .dt"
    }

    if (-not (Test-Path $dtFile)) {
        & $Ctx.Log "Файл .dt не создан: $dtFile" 'ERROR'
        throw "Файл .dt не был создан"
    }

    return $dtFile
}

Export-ModuleMember -Function Invoke-ExportDT

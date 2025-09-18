# modules\OneC.FileCopy.psm1
function Invoke-FileCopy {
    param([hashtable]$Ctx)

    $cfg = $Ctx.Config
    $src = $cfg.Backup.Source1CD
    $destDir = $cfg.Backup.Dest

    if (-not (Test-Path $src)) {
        & $Ctx.Log "Файл не найден: $src" 'ERROR'
        throw "Файл .1CD не найден: $src"
    }

    if (-not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Force -Path $destDir | Out-Null
    }

    $timestamp = Get-Date -Format "yyyyMMdd_HHmm"
    $filename = \"{0}_{1}.1CD\" -f $Ctx.Tag, $timestamp
    $target = Join-Path $destDir $filename

    & $Ctx.Log \"Копирование базы: $src -> $target\"
    Copy-Item -Path $src -Destination $target -Force

    return $target
}

Export-ModuleMember -Function Invoke-FileCopy

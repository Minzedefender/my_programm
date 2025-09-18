function New-Logger {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$LogPath
    )

    if (-not $LogPath) {
        throw "LogPath не задан. Невозможно создать логгер."
    }

    return {
        param (
            [string]$Message,
            [string]$Level = 'INFO'
        )

        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $line = "[$timestamp][$Level] $Message"

        try {
            [System.IO.File]::AppendAllText($LogPath, $line + "`r`n")
        } catch {
            Write-Warning "Не удалось записать в лог: $($_.Exception.Message)"
        }

        $color = switch ($Level) {
            'INFO'  { 'Gray' }
            'WARN'  { 'Yellow' }
            'ERROR' { 'Red' }
            default { 'White' }
        }

        Write-Host $line -ForegroundColor $color
    }
}

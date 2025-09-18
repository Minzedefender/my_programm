#requires -Version 5.1
# encoding: UTF-8
$ErrorActionPreference = 'Stop'

# ---- Пути ---------------------------------------------------------
$ConfigRoot = Join-Path $PSScriptRoot '..\config'
$BasesDir   = Join-Path $ConfigRoot  'bases'
if (-not (Test-Path $BasesDir)) { New-Item -ItemType Directory -Path $BasesDir | Out-Null }

# ---- Утилиты ввода ------------------------------------------------
function Read-Choice([string]$Prompt,[string[]]$Choices){
    Write-Host ''
    Write-Host $Prompt
    for($i=0;$i -lt $Choices.Count;$i++){
        Write-Host ("{0} - {1}" -f ($i+1), $Choices[$i])
    }
    do { $x = Read-Host ("Ваш выбор (1/{0})" -f $Choices.Count) }
    while(-not ($x -match '^\d+$') -or [int]$x -lt 1 -or [int]$x -gt $Choices.Count)
    return [int]$x
}

function Get-BaseList(){
    Get-ChildItem -Path $BasesDir -Filter *.json -File |
        Select-Object -ExpandProperty BaseName |
        Sort-Object
}

function Choose-Base([string[]]$List){
    if(-not $List -or $List.Count -eq 0){ throw "В папке '$BasesDir' нет конфигов *.json" }
    Write-Host "`nТекущие базы:`n"
    for($i=0;$i -lt $List.Count;$i++){
        Write-Host ("{0}) {1}" -f ($i+1), $List[$i])
    }
    do { $n = Read-Host ("Выберите номер (1-{0})" -f $List.Count) }
    while(-not ($n -match '^\d+$') -or [int]$n -lt 1 -or [int]$n -gt $List.Count)
    # Важно: возвращаем строку целиком (без [0])
    return $List[[int]$n-1]
}

function Load-Config([string]$Tag){
    $path = Join-Path $BasesDir ("{0}.json" -f $Tag)
    if(-not (Test-Path $path)){ throw "Конфиг не найден: $path" }
    Get-Content $path -Raw | ConvertFrom-Json
}

function Save-Config([string]$Tag,$Obj){
    $path = Join-Path $BasesDir ("{0}.json" -f $Tag)
    $Obj | ConvertTo-Json -Depth 12 | Set-Content -Encoding UTF8 $path
}

function Prompt-Int([string]$Label, $Current){
    $inp = Read-Host ("{0} (текущее: {1})" -f $Label, $Current)
    if([string]::IsNullOrWhiteSpace($inp)){ return $Current }
    $n = 0
    if([int]::TryParse($inp, [ref]$n)){ return $n }
    Write-Host "Некорректное число, оставляю: $Current"
    return $Current
}

# ---- Действия -----------------------------------------------------
function Action-Edit{
    $list = Get-BaseList
    $tag  = Choose-Base $list
    $cfg  = Load-Config $tag

    Write-Host ("`nРедактирование [{0}]. Пустое значение — оставить как есть." -f $tag)

    # Общие поля
    if($cfg.PSObject.Properties.Name -contains 'BackupType'){
        $cur = $cfg.BackupType
        $val = Read-Host ("BackupType (текущее: {0})" -f $cur)
        if($val -ne ''){ $cfg.BackupType = $val }
    }
    if($cfg.PSObject.Properties.Name -contains 'SourcePath'){
        $cur = $cfg.SourcePath
        $val = Read-Host ("SourcePath (текущее: {0})" -f $cur)
        if($val -ne ''){ $cfg.SourcePath = $val }
    }
    if($cfg.PSObject.Properties.Name -contains 'DestinationPath'){
        $cur = $cfg.DestinationPath
        $val = Read-Host ("DestinationPath (текущее: {0})" -f $cur)
        if($val -ne ''){ $cfg.DestinationPath = $val }
    }
    if($cfg.PSObject.Properties.Name -contains 'Keep'){
        $cfg.Keep = Prompt-Int 'Keep (сколько копий хранить)' $cfg.Keep
    }
    if($cfg.PSObject.Properties.Name -contains 'CloudType'){
        $cur = $cfg.CloudType
        $val = Read-Host ("CloudType (текущее: {0})" -f $cur)
        if($val -ne ''){ $cfg.CloudType = $val }
    }

    # Только для DT
    if(($cfg.PSObject.Properties.Name -contains 'BackupType') -and ($cfg.BackupType -eq 'DT')){
        if($cfg.PSObject.Properties.Name -contains 'ExePath'){
            $cur = $cfg.ExePath
            $val = Read-Host ("ExePath (текущее: {0})" -f $cur)
            if($val -ne ''){ $cfg.ExePath = $val }
        }

        # StopServices
        $curSS = '<пусто>'
        if($cfg.PSObject.Properties.Name -contains 'StopServices'){
            if($cfg.StopServices){
                $curSS = ($cfg.StopServices -join ', ')
            }
        }
        $val = Read-Host ("StopServices через запятую (текущее: {0})" -f $curSS)
        if($val -ne ''){
            $cfg.StopServices = ($val -split ',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
        }

        if($cfg.PSObject.Properties.Name -contains 'DumpTimeoutMin'){
            $cfg.DumpTimeoutMin = Prompt-Int 'DumpTimeoutMin (минут)' $cfg.DumpTimeoutMin
        }
    }

    Save-Config $tag $cfg
    Write-Host "Сохранено."
}

function Action-Toggle{
    $list = Get-BaseList
    $tag  = Choose-Base $list
    $cfg  = Load-Config $tag

    $enabled = $true
    if($cfg.PSObject.Properties.Name -contains 'Disabled'){
        $enabled = -not [bool]$cfg.Disabled
    }

    $state = if($enabled){'ВКЛЮЧЕНО'} else {'ОТКЛЮЧЕНО'}
    $ch = Read-Choice ("Сейчас: $state. Что сделать?") @('Включить','Отключить','Отмена')
    switch($ch){
        1 { $cfg.Disabled = $false; Save-Config $tag $cfg; Write-Host "База [$tag] включена." }
        2 { $cfg.Disabled = $true;  Save-Config $tag $cfg; Write-Host "База [$tag] отключена." }
        default { Write-Host "Без изменений." }
    }
}

function Action-Delete{
    $list = Get-BaseList
    $tag  = Choose-Base $list
    $path = Join-Path $BasesDir ("{0}.json" -f $tag)
    $ch   = Read-Choice ("Удалить конфиг [$tag]?") @('Да','Нет')
    if($ch -eq 1){
        Remove-Item -LiteralPath $path -Force
        Write-Host "Удалено: $path"
    }
}

# ---- Меню ---------------------------------------------------------
try {
    while($true){
        $a = Read-Choice "Выберите действие" @(
            'Редактировать базу',
            'Включить/Отключить базу',
            'Удалить базу',
            'Выход'
        )
        switch($a){
            1 { Action-Edit }
            2 { Action-Toggle }
            3 { Action-Delete }
            default { break }
        }
    }
}
catch {
    Write-Host ("ОШИБКА: {0}" -f $_.Exception.Message) -ForegroundColor Red
    $host.SetShouldExit(1)
}

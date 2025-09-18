#requires -Version 5.1
using namespace System.Security.Cryptography
using namespace System.Text

function New-RandomKey {
    $k = New-Object byte[] 32
    [RandomNumberGenerator]::Create().GetBytes($k)
    return $k
}

function Ensure-KeyFile {
    param(
        [Parameter(Mandatory)][string]$KeyPath
    )
    $dir = [IO.Path]::GetDirectoryName($KeyPath)
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
    if (-not (Test-Path $KeyPath)) {
        $key = New-RandomKey
        [IO.File]::WriteAllBytes($KeyPath, $key)
    }
}

function Encrypt-Secrets {
    param(
        [Parameter(Mandatory)][hashtable]$Secrets,
        [Parameter(Mandatory)][string]$KeyPath,
        [Parameter(Mandatory)][string]$OutFile
    )

    # гарантируем наличие ключа и каталога
    Ensure-KeyFile -KeyPath $KeyPath
    $outDir = [IO.Path]::GetDirectoryName($OutFile)
    if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }

    $key = [IO.File]::ReadAllBytes($KeyPath)

    $json = $Secrets | ConvertTo-Json -Depth 10
    $plain = [Encoding]::UTF8.GetBytes($json)

    $aes = [Aes]::Create()
    $aes.Key = $key
    $aes.GenerateIV()

    $enc = $aes.CreateEncryptor().TransformFinalBlock($plain, 0, $plain.Length)

    $blob = New-Object byte[] ($aes.IV.Length + $enc.Length)
    [Array]::Copy($aes.IV, 0, $blob, 0, $aes.IV.Length)
    [Array]::Copy($enc,   0, $blob, $aes.IV.Length, $enc.Length)

    [IO.File]::WriteAllBytes($OutFile, $blob)
}

function Decrypt-Secrets {
    param(
        [Parameter(Mandatory)][string]$InFile,
        [Parameter(Mandatory)][string]$KeyPath
    )

    if (-not (Test-Path $InFile))  { throw "Файл секретов не найден: $InFile" }
    if (-not (Test-Path $KeyPath)) { throw "Ключ не найден: $KeyPath" }

    $key   = [IO.File]::ReadAllBytes($KeyPath)
    $bytes = [IO.File]::ReadAllBytes($InFile)

    if ($bytes.Length -lt 17) { throw "Файл секретов повреждён или пустой: $InFile" }

    $iv     = $bytes[0..15]
    $cipher = $bytes[16..($bytes.Length-1)]

    $aes = [Aes]::Create()
    $aes.Key = $key
    $aes.IV  = $iv

    $plain = $aes.CreateDecryptor().TransformFinalBlock($cipher, 0, $cipher.Length)
    $json  = [Encoding]::UTF8.GetString($plain)

    return $json | ConvertFrom-Json
}

#requires -Version 5.1

function Send-TelegramMessage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Token,
        [Parameter(Mandatory)][string]$ChatId,
        [Parameter(Mandatory)][string]$Text,
        [switch]$DisableNotification
    )

    if ([string]::IsNullOrWhiteSpace($Token)) {
        throw "Token не задан"
    }
    if ([string]::IsNullOrWhiteSpace($ChatId)) {
        throw "ChatId не задан"
    }
    if ($null -eq $Text) {
        $Text = ''
    }

    $body = @{
        chat_id = $ChatId
        text    = [string]$Text
    }
    if ($DisableNotification.IsPresent) {
        $body.disable_notification = $true
    }

    $url = "https://api.telegram.org/bot$Token/sendMessage"

    $prevProto = [Net.ServicePointManager]::SecurityProtocol
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    } catch {
        # игнорируем, если невозможно установить протокол
    }

    try {
        Invoke-RestMethod -Method Post -Uri $url -Body $body -ContentType 'application/x-www-form-urlencoded' -ErrorAction Stop | Out-Null
    }
    catch {
        throw "Не удалось отправить сообщение в Telegram: $($_.Exception.Message)"
    }
    finally {
        try { [Net.ServicePointManager]::SecurityProtocol = $prevProto } catch {}
    }
}

Export-ModuleMember -Function Send-TelegramMessage

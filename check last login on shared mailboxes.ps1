Connect-MgGraph -Scopes "AuditLog.Read.All","Directory.Read.All"
Connect-ExchangeOnline

$DateRange = (Get-Date).AddDays(-30)
$DateISO   = $DateRange.ToString("yyyy-MM-ddTHH:mm:ss.fffZ")

$SharedMailboxes = Get-Mailbox -RecipientTypeDetails SharedMailbox -ResultSize Unlimited

$Results = foreach ($mb in $SharedMailboxes) {
    $UPN = $mb.UserPrincipalName

    # Filter using corrected ISO date format
    $Filter = "userPrincipalName eq '$UPN' and createdDateTime ge $DateISO"

    try {
        $SignIns = Get-MgAuditLogSignIn -Filter $Filter -All
    } catch {
        Write-Warning "Query failed for $UPN — $_"
        continue
    }

    $Last = $null
    if ($SignIns) {
        $Last = ($SignIns | Sort-Object createdDateTime -Descending | Select-Object -First 1).createdDateTime
    }

    [PSCustomObject]@{
        DisplayName = $mb.DisplayName
        UPN         = $UPN
        LastSignIn  = $Last
    }
}

$Results | Format-Table -AutoSize

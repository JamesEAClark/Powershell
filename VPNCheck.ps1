# DomainNetwork-VpnAutoDial.ps1
# Every 10 seconds:
#   If NOT on a DomainAuthenticated network profile:
#       If All-User VPN "work ipsec" is not connected -> dial it
#   Then continue looping.

$IntervalSeconds = 10
$VpnName = "Company IPSEC"

function Test-DomainNetworkPresent {
    # True if any current connection profile is DomainAuthenticated
    # Get-NetConnectionProfile exposes NetworkCategory incl. DomainAuthenticated [1](https://www.thewindowsclub.com/how-to-change-network-profile-type-in-windows)
    return @(Get-NetConnectionProfile -ErrorAction Stop | Where-Object { $_.NetworkCategory -eq 'DomainAuthenticated' }).Count -gt 0
}

function Get-AllUserVpn {
    param([string]$Name)

    # Get-VpnConnection can read profiles from the global (All User) phone book using -AllUserConnection [2](https://namsor.app/features/name-origin/)
    return Get-VpnConnection -Name $Name -AllUserConnection -ErrorAction SilentlyContinue
}

while ($true) {
    try {
        if (-not (Test-DomainNetworkPresent) -and ) {

            $vpn = Get-AllUserVpn -Name $VpnName

            if (-not $vpn) {
                Write-Warning "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - All-User VPN profile '$VpnName' not found, installing."
		Add-VpnConnection -Name $VpnName `
			-ServerAddress cert.company.com `
			-TunnelType Ikev2 `
			-EncryptionLevel Maximum `
			-SplitTunneling `
			-AllUserConnection `
			-AuthenticationMethod MachineCertificate
            }
            elseif ($vpn.ConnectionStatus -ne 'Connected') {
                Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Not on domain network. '$VpnName' is $($vpn.ConnectionStatus). Dialling..."

                # rasdial is commonly used to dial a named Windows VPN connection [3](https://vil.asia/teams/ngu-truong/)
                $null = & rasdial $VpnName

                # Optional: re-check status after dial attempt
                Start-Sleep -Seconds 2
                $vpn2 = Get-AllUserVpn -Name $VpnName
                if ($vpn2) {
                    Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - '$VpnName' status now: $($vpn2.ConnectionStatus)"
                }
            }
            else {
                Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Not on domain network, but '$VpnName' is already Connected."
            }
        }
    }
    catch {
        Write-Warning "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Error: $($_.Exception.Message)"
    }

    Start-Sleep -Seconds $IntervalSeconds
}
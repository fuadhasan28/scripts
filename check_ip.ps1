
$initialIp = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike '169.*' -and $_.IPAddress -ne '127.0.0.1' }).IPAddress
Write-Host "Initial IP: $initialIp" -ForegroundColor Green

$currentIp = $initialIp
$counter = 0
while ($true) {
    $newIp = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike '169.*' -and $_.IPAddress -ne '127.0.0.1' }).IPAddress
    if ($newIp -ne $currentIp) {
        Write-Host "IP is changed: $newIp" -ForegroundColor Red
        $currentIp = $newIp
        $counter = 0
    } else {
        $counter++
        if ($counter -ge 180) {
            Write-Host "IP is not changed yet" -ForegroundColor Green
            $counter = 0
        }
    }
    Start-Sleep -Seconds 5
}
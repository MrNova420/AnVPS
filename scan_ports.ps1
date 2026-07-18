$tgt = "192.168.4.196"
$ports = @(22, 80, 443, 8022, 2222, 8080, 8000, 5555, 3000, 5000, 7070, 9090, 4444, 8888, 9099, 7033)

foreach ($port in $ports) {
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $connect = $tcp.BeginConnect($tgt, $port, $null, $null)
        $wait = $connect.AsyncWaitHandle.WaitOne(2000, $false)
        if ($wait) {
            $tcp.EndConnect($connect)
            Write-Host "OPEN: $port"
            $tcp.Close()
        }
    } catch {}
}
Write-Host "Scan complete"

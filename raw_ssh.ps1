$tcp = New-Object System.Net.Sockets.TcpClient
$connect = $tcp.BeginConnect('192.168.4.196', 8022, $null, $null)
$wait = $connect.AsyncWaitHandle.WaitOne(5000, $false)
if ($wait) {
    $tcp.EndConnect($connect)
    $stream = $tcp.GetStream()
    Write-Host "Connected!"
    # Send SSH version string
    $ver = [System.Text.Encoding]::ASCII.GetBytes("SSH-2.0-OpenSSH_8.9p1`r`n")
    $stream.Write($ver, 0, $ver.Length)
    $stream.Flush()
    Start-Sleep -Milliseconds 2000
    # Read response
    $buf = New-Object byte[] 1024
    $stream.ReadTimeout = 5000
    try {
        $read = $stream.Read($buf, 0, $buf.Length)
        if ($read -gt 0) {
            $text = [System.Text.Encoding]::ASCII.GetString($buf, 0, $read)
            Write-Host "Server sent ($read bytes): $text"
        } else {
            Write-Host "Server sent nothing"
        }
    } catch {
        Write-Host "Read error: $($_.Exception.Message)"
    }
    $tcp.Close()
} else {
    Write-Host "Connection timeout"
}

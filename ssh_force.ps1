param(
    [string]$Host = "192.168.4.196",
    [int]$Port = 8022,
    [string]$User = "u0_a275",
    [string]$Password = "s5600"
)

Write-Host "Connecting to $Host`:$Port..."
$tcp = New-Object System.Net.Sockets.TcpClient
$connect = $tcp.BeginConnect($Host, $Port, $null, $null)
$wait = $connect.AsyncWaitHandle.WaitOne(10000, $false)
if (-not $wait) { Write-Host "Connection timeout"; exit 1 }
$tcp.EndConnect($connect)
Write-Host "Connected!"

$stream = $tcp.GetStream()
$stream.ReadTimeout = 10000
$stream.WriteTimeout = 10000

# Send client version immediately (some servers need this kick)
$ver = [System.Text.Encoding]::ASCII.GetBytes("SSH-2.0-OpenSSH_for_Windows_9.5`r`n")
$stream.Write($ver, 0, $ver.Length)
$stream.Flush()
Write-Host "Sent client version, waiting for server..."

# Wait for server banner
$buf = New-Object byte[] 4096
Start-Sleep -Milliseconds 2000
try {
    $read = $stream.Read($buf, 0, $buf.Length)
    if ($read -gt 0) {
        $text = [System.Text.Encoding]::ASCII.GetString($buf, 0, $read)
        Write-Host "Server response ($read bytes): $text"
    } else {
        Write-Host "Server sent nothing"
    }
} catch {
    Write-Host "Read error: $($_.Exception.Message)"
}

$tcp.Close()

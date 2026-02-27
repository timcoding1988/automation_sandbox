#ps1_sysnative
# Bootstrap script for Windows Server on OCI
# Configures WinRM HTTPS for Packer (based on automation_images approach)

# Create marker file to confirm script ran
$markerFile = "C:\Windows\Temp\packer-bootstrap-ran.txt"
"Bootstrap started at $(Get-Date)" | Out-File -FilePath $markerFile

$logFile = "C:\Windows\Temp\packer-bootstrap.log"
function Log-Message {
    param([string]$message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "$timestamp - $message"
    $logLine | Out-File -Append -FilePath $logFile
    Write-Host $logLine
}

Log-Message "=== Starting WinRM HTTPS bootstrap for Packer ==="

try {
    # Set execution policy
    Set-ExecutionPolicy Unrestricted -Scope LocalMachine -Force -ErrorAction SilentlyContinue
    Log-Message "Set execution policy"

    # Set password for opc user
    Log-Message "Setting password for opc user..."
    $password = ConvertTo-SecureString "${winrm_password}" -AsPlainText -Force
    try {
        Set-LocalUser -Name "opc" -Password $password -ErrorAction Stop
        Log-Message "Password set for opc user via Set-LocalUser"
    } catch {
        Log-Message "Set-LocalUser failed: $($_.Exception.Message), trying net user..."
        $netResult = net user opc "${winrm_password}" 2>&1
        Log-Message "net user result: $netResult"
    }

    # Stop WinRM to reconfigure
    Log-Message "Stopping WinRM service..."
    Stop-Service WinRM -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2

    # Remove any existing WinRM listeners
    Log-Message "Removing existing WinRM listeners..."
    Remove-Item -Path WSMan:\Localhost\listener\listener* -Recurse -Force -ErrorAction SilentlyContinue

    # Create a self-signed certificate for HTTPS (like automation_images)
    Log-Message "Creating self-signed certificate..."
    $Cert = New-SelfSignedCertificate -CertstoreLocation Cert:\LocalMachine\My -DnsName "packer"
    Log-Message "Certificate created with thumbprint: $($Cert.Thumbprint)"

    # Configure WinRM settings
    Log-Message "Configuring WinRM settings..."
    cmd.exe /c winrm set "winrm/config" '@{MaxTimeoutms="1800000"}' 2>&1 | Out-File -Append -FilePath $logFile
    cmd.exe /c winrm set "winrm/config/service/auth" '@{Basic="true"}' 2>&1 | Out-File -Append -FilePath $logFile
    cmd.exe /c winrm set "winrm/config/client/auth" '@{Basic="true"}' 2>&1 | Out-File -Append -FilePath $logFile

    # Create HTTPS listener with certificate
    Log-Message "Creating HTTPS listener..."
    $listenerCmd = "winrm create `"winrm/config/listener?Address=*+Transport=HTTPS`" `"@{Port=`"5986`";Hostname=`"packer`";CertificateThumbprint=`"$($Cert.Thumbprint)`"}`""
    Log-Message "Running: $listenerCmd"
    cmd.exe /c $listenerCmd 2>&1 | Out-File -Append -FilePath $logFile
    Log-Message "HTTPS listener created"

    # Configure firewall
    Log-Message "Configuring Windows Firewall..."
    cmd.exe /c netsh advfirewall firewall set rule group="remote administration" new enable=yes 2>&1 | Out-File -Append -FilePath $logFile
    cmd.exe /c netsh advfirewall firewall add rule name="WinRM HTTPS" dir=in action=allow protocol=TCP localport=5986 2>&1 | Out-File -Append -FilePath $logFile
    Log-Message "Firewall configured"

    # Enable and start WinRM service
    Log-Message "Starting WinRM service..."
    cmd.exe /c sc config winrm start= auto 2>&1 | Out-File -Append -FilePath $logFile
    cmd.exe /c net start winrm 2>&1 | Out-File -Append -FilePath $logFile
    Start-Sleep -Seconds 3
    Log-Message "WinRM service started"

    # Verify WinRM is listening on HTTPS
    Log-Message "Verifying WinRM HTTPS listener..."
    $testResult = cmd.exe /c winrm enumerate winrm/config/listener 2>&1
    $testResult | Out-File -Append -FilePath $logFile
    Log-Message "WinRM listener enumeration complete"

    # Check if port 5986 is listening
    $tcpListener = Get-NetTCPConnection -LocalPort 5986 -ErrorAction SilentlyContinue
    if ($tcpListener) {
        Log-Message "SUCCESS: TCP port 5986 is listening"
    } else {
        Log-Message "WARNING: TCP port 5986 is NOT listening yet"
    }

    Log-Message "=== WinRM HTTPS bootstrap completed successfully ==="
    "Bootstrap completed at $(Get-Date)" | Out-File -Append -FilePath $markerFile
}
catch {
    Log-Message "ERROR: $($_.Exception.Message)"
    Log-Message "Stack: $($_.ScriptStackTrace)"
    "Bootstrap FAILED at $(Get-Date): $($_.Exception.Message)" | Out-File -Append -FilePath $markerFile
}

#ps1_sysnative
# Bootstrap script for Windows Server on OCI
# Runs via cloudbase-init to configure WinRM for Packer

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

Log-Message "=== Starting WinRM bootstrap for Packer ==="

try {
    # Set execution policy
    Set-ExecutionPolicy Unrestricted -Scope LocalMachine -Force -ErrorAction SilentlyContinue
    Log-Message "Set execution policy"

    # Set password for opc user
    Log-Message "Setting password for opc user..."
    $password = ConvertTo-SecureString "${winrm_password}" -AsPlainText -Force
    try {
        Set-LocalUser -Name "opc" -Password $password -ErrorAction Stop
        Log-Message "Password set for opc user"
    } catch {
        Log-Message "Warning: Could not set opc password: $($_.Exception.Message)"
        # Try alternative method
        net user opc "${winrm_password}" 2>&1 | Out-File -Append -FilePath $logFile
    }

    # Stop WinRM to reconfigure
    Log-Message "Stopping WinRM service..."
    Stop-Service WinRM -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2

    # Delete all existing listeners
    Log-Message "Removing existing WinRM listeners..."
    Remove-Item -Path WSMan:\Localhost\listener\* -Recurse -Force -ErrorAction SilentlyContinue

    # Quick configure WinRM
    Log-Message "Running winrm quickconfig..."
    winrm quickconfig -quiet -force 2>&1 | Out-File -Append -FilePath $logFile

    # Create HTTP listener explicitly
    Log-Message "Creating HTTP listener..."
    New-Item -Path WSMan:\Localhost\Listener -Transport HTTP -Address * -Force -ErrorAction SilentlyContinue | Out-Null

    # Configure WinRM service settings
    Log-Message "Configuring WinRM settings..."
    Set-Item WSMan:\localhost\Service\AllowUnencrypted -Value $true -Force
    Set-Item WSMan:\localhost\Service\Auth\Basic -Value $true -Force
    Set-Item WSMan:\localhost\Client\Auth\Basic -Value $true -Force
    Set-Item WSMan:\localhost\Client\TrustedHosts -Value '*' -Force
    Set-Item WSMan:\localhost\Shell\MaxMemoryPerShellMB -Value 2048 -Force
    Set-Item WSMan:\localhost\MaxTimeoutms -Value 1800000 -Force
    Log-Message "WinRM settings configured"

    # Configure firewall
    Log-Message "Configuring Windows Firewall..."

    # Enable existing WinRM rules
    Get-NetFirewallRule -DisplayGroup "Windows Remote Management" -ErrorAction SilentlyContinue |
        Enable-NetFirewallRule -ErrorAction SilentlyContinue

    # Add explicit rule for port 5985
    New-NetFirewallRule -DisplayName "WinRM HTTP Packer" `
        -Direction Inbound `
        -Protocol TCP `
        -LocalPort 5985 `
        -Action Allow `
        -Profile Any `
        -ErrorAction SilentlyContinue | Out-Null
    Log-Message "Firewall configured"

    # Start WinRM service
    Log-Message "Starting WinRM service..."
    Set-Service -Name WinRM -StartupType Automatic
    Start-Service WinRM
    Start-Sleep -Seconds 3
    Log-Message "WinRM service started"

    # Verify WinRM is listening
    $listeners = Get-ChildItem WSMan:\Localhost\Listener -ErrorAction SilentlyContinue
    Log-Message "WinRM listeners count: $($listeners.Count)"
    foreach ($listener in $listeners) {
        $transport = ($listener | Get-ChildItem | Where-Object { $_.Name -eq "Transport" }).Value
        $port = ($listener | Get-ChildItem | Where-Object { $_.Name -eq "Port" }).Value
        Log-Message "  Listener: $transport on port $port"
    }

    # Verify WinRM is accepting connections
    $tcpListener = Get-NetTCPConnection -LocalPort 5985 -ErrorAction SilentlyContinue
    if ($tcpListener) {
        Log-Message "TCP port 5985 is listening"
    } else {
        Log-Message "WARNING: TCP port 5985 is NOT listening"
    }

    # Test WinRM locally
    Log-Message "Testing WinRM locally..."
    $testResult = winrm enumerate winrm/config/listener 2>&1
    $testResult | Out-File -Append -FilePath $logFile

    Log-Message "=== WinRM bootstrap completed successfully ==="
    "Bootstrap completed at $(Get-Date)" | Out-File -Append -FilePath $markerFile
}
catch {
    Log-Message "ERROR: $($_.Exception.Message)"
    Log-Message "Stack: $($_.ScriptStackTrace)"
    "Bootstrap FAILED at $(Get-Date): $($_.Exception.Message)" | Out-File -Append -FilePath $markerFile
}

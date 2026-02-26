#ps1_sysnative
# Bootstrap script for Windows Server on OCI
# Configures WinRM and sets opc user password for Packer provisioning

$ErrorActionPreference = "Stop"

# Log to a file for debugging
$logFile = "C:\Windows\Temp\packer-bootstrap.log"
function Log-Message {
    param([string]$message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $message" | Out-File -Append -FilePath $logFile
    Write-Host $message
}

Log-Message "Starting WinRM bootstrap for Packer..."

try {
    # Allow powershell scripts to execute
    Set-ExecutionPolicy Unrestricted -Scope LocalMachine -Force -ErrorAction SilentlyContinue
    Log-Message "Set execution policy to Unrestricted"

    # Set password for opc user (used by Packer)
    Log-Message "Setting password for opc user..."
    $securePassword = ConvertTo-SecureString "${winrm_password}" -AsPlainText -Force
    Set-LocalUser -Name "opc" -Password $securePassword
    Log-Message "Password set for opc user"

    # Enable WinRM service
    Log-Message "Configuring WinRM service..."
    Set-Service -Name WinRM -StartupType Automatic
    Start-Service WinRM
    Log-Message "WinRM service started"

    # Configure WinRM for HTTP (port 5985)
    Log-Message "Configuring WinRM listeners..."

    # Remove existing listeners
    Get-ChildItem WSMan:\Localhost\Listener -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

    # Enable WinRM
    winrm quickconfig -quiet

    # Create HTTP listener on all addresses
    New-Item -Path WSMan:\Localhost\Listener -Transport HTTP -Address * -Force -ErrorAction SilentlyContinue | Out-Null
    Log-Message "Created HTTP listener on port 5985"

    # Configure WinRM settings for Packer
    Set-Item WSMan:\localhost\Client\TrustedHosts -Value '*' -Force
    Set-Item WSMan:\localhost\Service\AllowUnencrypted -Value $true -Force
    Set-Item WSMan:\localhost\Service\Auth\Basic -Value $true -Force
    Set-Item WSMan:\localhost\Client\Auth\Basic -Value $true -Force
    Set-Item WSMan:\localhost\Shell\MaxMemoryPerShellMB -Value 2048 -Force
    Set-Item WSMan:\localhost\MaxTimeoutms -Value 1800000 -Force
    Log-Message "WinRM settings configured"

    # Configure firewall for WinRM HTTP (5985)
    Log-Message "Configuring firewall..."

    # Enable firewall rules for WinRM
    Enable-NetFirewallRule -DisplayGroup "Windows Remote Management" -ErrorAction SilentlyContinue

    # Add explicit firewall rule for WinRM HTTP
    New-NetFirewallRule -DisplayName "WinRM HTTP for Packer" `
        -Direction Inbound `
        -Protocol TCP `
        -LocalPort 5985 `
        -Action Allow `
        -Profile Any `
        -ErrorAction SilentlyContinue | Out-Null
    Log-Message "Firewall rule added for port 5985"

    # Restart WinRM to apply changes
    Restart-Service WinRM
    Log-Message "WinRM service restarted"

    # Verify WinRM is listening
    $listeners = Get-ChildItem WSMan:\Localhost\Listener -ErrorAction SilentlyContinue
    Log-Message "WinRM listeners: $($listeners.Count)"

    Log-Message "WinRM bootstrap completed successfully"
}
catch {
    Log-Message "ERROR: $($_.Exception.Message)"
    Log-Message "Stack trace: $($_.ScriptStackTrace)"
    # Don't throw - let cloudbase-init continue
}

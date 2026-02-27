# Windows Server finalization script for OCI
# Secures the image and prepares for deployment

$ErrorActionPreference = "stop"

Write-Host "=== Windows Server Finalization ==="

# Disable WinRM as a security precaution
Write-Host "Disabling WinRM..."
Set-Service winrm -StartupType Disabled

# Disable RDP by default (can be enabled via user-data)
Write-Host "Disabling RDP..."
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 1
Disable-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction SilentlyContinue

# Re-enable real-time virus scanning
Write-Host "Re-enabling Windows Defender..."
Set-MpPreference -DisableRealtimeMonitoring 0

# Clean up temporary files
Write-Host "Cleaning up temporary files..."
Remove-Item -Path "c:\temp" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue

# Clear event logs (some logs like Analytic can't be cleared - ignore errors)
Write-Host "Clearing event logs..."
$logs = wevtutil el
foreach ($log in $logs) {
    try {
        wevtutil cl $log 2>&1 | Out-Null
    } catch {
        # Ignore - some logs can't be cleared
    }
}

Write-Host "=== Windows Server Finalization Complete ==="
Exit 0

<powershell>
# Bootstrap script for Windows Server on OCI
# Based on proven automation_images approach

Set-ExecutionPolicy Unrestricted -Scope LocalMachine -Force -ErrorAction Ignore
$ErrorActionPreference = "stop"

# Log to file for debugging
$logFile = "C:\Windows\Temp\packer-bootstrap.log"
"Bootstrap started at $(Get-Date)" | Out-File -FilePath $logFile

try {
    # Set password for opc user
    "Setting opc password..." | Out-File -Append -FilePath $logFile
    net user opc "${winrm_password}" 2>&1 | Out-File -Append -FilePath $logFile

    # Remove any existing WinRM listeners
    "Removing existing listeners..." | Out-File -Append -FilePath $logFile
    Remove-Item -Path WSMan:\Localhost\listener\listener* -Recurse -ErrorAction SilentlyContinue

    # Create a self-signed certificate for https
    "Creating self-signed certificate..." | Out-File -Append -FilePath $logFile
    $Cert = New-SelfSignedCertificate -CertstoreLocation Cert:\LocalMachine\My -DnsName "packer"
    "Certificate thumbprint: $($Cert.Thumbprint)" | Out-File -Append -FilePath $logFile

    # Configure WinRM over https
    "Configuring WinRM..." | Out-File -Append -FilePath $logFile
    cmd.exe /c winrm set "winrm/config" '@{MaxTimeoutms="1800000"}' 2>&1 | Out-File -Append -FilePath $logFile
    cmd.exe /c winrm set "winrm/config/service/auth" '@{Basic="true"}' 2>&1 | Out-File -Append -FilePath $logFile
    cmd.exe /c winrm set "winrm/config/client/auth" '@{Basic="true"}' 2>&1 | Out-File -Append -FilePath $logFile
    cmd.exe /c winrm create "winrm/config/listener?Address=*+Transport=HTTPS" "@{Port=`"5986`";Hostname=`"packer`";CertificateThumbprint=`"$($Cert.Thumbprint)`"}" 2>&1 | Out-File -Append -FilePath $logFile

    # Configure firewall
    "Configuring firewall..." | Out-File -Append -FilePath $logFile
    cmd.exe /c netsh advfirewall firewall set rule group="remote administration" new enable=yes 2>&1 | Out-File -Append -FilePath $logFile
    cmd.exe /c netsh advfirewall firewall add rule name="WinRM HTTPS" dir=in action=allow protocol=TCP localport=5986 2>&1 | Out-File -Append -FilePath $logFile

    # Start and Enable WinRM
    "Starting WinRM service..." | Out-File -Append -FilePath $logFile
    cmd.exe /c sc config winrm start= auto 2>&1 | Out-File -Append -FilePath $logFile
    cmd.exe /c net start winrm 2>&1 | Out-File -Append -FilePath $logFile

    "Bootstrap completed successfully at $(Get-Date)" | Out-File -Append -FilePath $logFile
}
catch {
    "ERROR: $($_.Exception.Message)" | Out-File -Append -FilePath $logFile
    throw
}
</powershell>

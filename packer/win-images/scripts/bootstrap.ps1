<powershell>
# Bootstrap script for Windows Server on OCI
# Configures WinRM for Packer provisioning

# Allow powershell scripts to execute
Set-ExecutionPolicy Unrestricted -Scope LocalMachine -Force -ErrorAction Ignore
$ErrorActionPreference = "stop"

# Remove any existing WinRM HTTP listener
Remove-Item -Path WSMan:\Localhost\listener\listener* -Recurse -ErrorAction SilentlyContinue

# Create a self-signed certificate for HTTPS
$Cert = New-SelfSignedCertificate -CertstoreLocation Cert:\LocalMachine\My -DnsName "packer"

# Configure WinRM over HTTPS for Packer
cmd.exe /c winrm set "winrm/config" '@{MaxTimeoutms="1800000"}'
cmd.exe /c winrm set "winrm/config/service/auth" '@{Basic="true"}'
cmd.exe /c winrm set "winrm/config/client/auth" '@{Basic="true"}'
cmd.exe /c winrm create "winrm/config/listener?Address=*+Transport=HTTPS" "@{Port=`"5986`";Hostname=`"packer`";CertificateThumbprint=`"$($Cert.Thumbprint)`"}"

# Configure firewall
cmd.exe /c netsh advfirewall firewall set rule group="remote administration" new enable=yes
cmd.exe /c netsh firewall add portopening TCP 5986 "Port 5986"

# Start and enable WinRM service
cmd.exe /c sc config winrm start= auto
cmd.exe /c net start winrm
</powershell>

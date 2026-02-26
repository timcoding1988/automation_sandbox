# Windows Server setup script for OCI
# Installs required tools and enables Hyper-V/WSL

$ErrorActionPreference = "stop"

function Check-Exit {
    param([int[]]$AllowedCodes = @(0))
    if ($AllowedCodes -notcontains $LASTEXITCODE) {
        throw "Command failed with exit code $LASTEXITCODE"
    }
}

function retryInstall {
    param([string[]]$packages)
    foreach ($pkg in $packages) {
        $retries = 3
        while ($retries -gt 0) {
            try {
                choco install -y $pkg
                Check-Exit
                break
            } catch {
                $retries--
                if ($retries -eq 0) { throw }
                Write-Host "Retrying $pkg install..."
                Start-Sleep -Seconds 10
            }
        }
    }
}

Write-Host "=== Windows Server Setup ==="

# Disable runtime virus scanning during setup
Set-MpPreference -DisableRealtimeMonitoring 1

# Install Chocolatey package manager
Write-Host "Installing Chocolatey..."
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Install basic tools via Chocolatey
Write-Host "Installing basic tools..."
retryInstall 7zip, git, golang, mingw, StrawberryPerl, zstandard, vim, curl, jq

# Enable Windows Update service (required for some features)
Set-Service -Name wuauserv -StartupType "Manual"; Check-Exit

# Install .NET SDK for WiX and other tools
Write-Host "Installing .NET SDK..."
Invoke-WebRequest -Uri https://dotnet.microsoft.com/download/dotnet/scripts/v1/dotnet-install.ps1 -OutFile dotnet-install.ps1
.\dotnet-install.ps1 -InstallDir 'C:\Program Files\dotnet'

# Configure NuGet
& 'C:\Program Files\dotnet\dotnet.exe' nuget add source https://api.nuget.org/v3/index.json -n nuget.org

# Install WiX toolset
Write-Host "Installing WiX..."
& 'C:\Program Files\dotnet\dotnet.exe' tool install --global wix --version 5.0.2

# Enable Hyper-V features
Write-Host "Enabling Hyper-V..."
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All -NoRestart
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-Management-PowerShell -All -NoRestart
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-Management-Clients -All -NoRestart

# Install WSL
Write-Host "Installing WSL..."
$wslOutput = wsl --install
Check-Exit 0, 1  # WSL returns 1 when reboot is required
Write-Host $wslOutput

Write-Host "=== Windows Server Setup Complete (reboot required) ==="
Exit 0

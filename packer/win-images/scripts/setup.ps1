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
    param([string]$pkg)
    $retries = 3
    while ($retries -gt 0) {
        try {
            Write-Host "  Installing $pkg..."
            choco install -y $pkg --no-progress
            Check-Exit
            Write-Host "  $pkg installed successfully"
            return
        } catch {
            $retries--
            if ($retries -eq 0) { throw }
            Write-Host "  Retrying $pkg install..."
            Start-Sleep -Seconds 10
        }
    }
}

Write-Host "=== Windows Server Setup ==="
Write-Host "$(Get-Date -Format 'HH:mm:ss') Starting setup..."

# Disable runtime virus scanning during setup
Write-Host "$(Get-Date -Format 'HH:mm:ss') Disabling Windows Defender real-time scanning..."
Set-MpPreference -DisableRealtimeMonitoring 1

# Install Chocolatey package manager
Write-Host "$(Get-Date -Format 'HH:mm:ss') Installing Chocolatey..."
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
Write-Host "$(Get-Date -Format 'HH:mm:ss') Chocolatey installed"

# Install basic tools via Chocolatey (one at a time with progress)
Write-Host "$(Get-Date -Format 'HH:mm:ss') Installing basic tools..."
$packages = @('7zip', 'git', 'golang', 'mingw', 'StrawberryPerl', 'zstandard', 'vim', 'curl', 'jq')
foreach ($pkg in $packages) {
    retryInstall $pkg
}
Write-Host "$(Get-Date -Format 'HH:mm:ss') All packages installed"

# Enable Windows Update service (required for some features)
Write-Host "$(Get-Date -Format 'HH:mm:ss') Enabling Windows Update service..."
Set-Service -Name wuauserv -StartupType "Manual"; Check-Exit

# Install .NET SDK for WiX and other tools
Write-Host "$(Get-Date -Format 'HH:mm:ss') Downloading .NET SDK installer..."
Invoke-WebRequest -Uri https://dotnet.microsoft.com/download/dotnet/scripts/v1/dotnet-install.ps1 -OutFile dotnet-install.ps1
Write-Host "$(Get-Date -Format 'HH:mm:ss') Installing .NET SDK..."
.\dotnet-install.ps1 -InstallDir 'C:\Program Files\dotnet'
Write-Host "$(Get-Date -Format 'HH:mm:ss') .NET SDK installed"

# Configure NuGet - skip if source already exists (ignore errors)
Write-Host "$(Get-Date -Format 'HH:mm:ss') Configuring NuGet..."
try {
    & 'C:\Program Files\dotnet\dotnet.exe' nuget add source https://api.nuget.org/v3/index.json -n nuget.org 2>&1 | Out-Null
} catch {
    Write-Host "  NuGet source already configured (skipping)"
}
# Reset error state
$LASTEXITCODE = 0

# Install WiX toolset
Write-Host "$(Get-Date -Format 'HH:mm:ss') Installing WiX..."
& 'C:\Program Files\dotnet\dotnet.exe' tool install --global wix --version 5.0.2
Write-Host "$(Get-Date -Format 'HH:mm:ss') WiX installed"

# Enable Hyper-V features (may fail on VMs without nested virtualization - that's OK)
Write-Host "$(Get-Date -Format 'HH:mm:ss') Enabling Hyper-V (this may take a while)..."
try {
    Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All -NoRestart -ErrorAction SilentlyContinue
    Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-Management-PowerShell -All -NoRestart -ErrorAction SilentlyContinue
    Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-Management-Clients -All -NoRestart -ErrorAction SilentlyContinue
    Write-Host "$(Get-Date -Format 'HH:mm:ss') Hyper-V features enabled"
} catch {
    Write-Host "$(Get-Date -Format 'HH:mm:ss') Hyper-V features may not be available on this VM shape (continuing)"
}

# Install WSL (capture stderr to avoid false errors)
Write-Host "$(Get-Date -Format 'HH:mm:ss') Installing WSL..."
$wslResult = Start-Process -FilePath "wsl" -ArgumentList "--install", "--no-launch" -Wait -PassThru -NoNewWindow 2>&1
Write-Host "$(Get-Date -Format 'HH:mm:ss') WSL install exit code: $($wslResult.ExitCode)"
# WSL returns 0 on success, 1 if reboot required - both are OK
if ($wslResult.ExitCode -notin @(0, 1)) {
    Write-Host "WARNING: WSL install may have failed, but continuing..."
}

Write-Host "$(Get-Date -Format 'HH:mm:ss') === Windows Server Setup Complete (reboot required) ==="
Exit 0

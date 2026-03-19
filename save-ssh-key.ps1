#!/usr/bin/env pwsh
# save-ssh-key.ps1
# Generates an SSH key pair (if needed) and installs it on a remote host.
#
# Usage:
#   .\save-ssh-key.ps1
#   .\save-ssh-key.ps1 root@192.168.1.1
#   .\save-ssh-key.ps1 root@192.168.1.1:2222
#   .\save-ssh-key.ps1 192.168.1.1
#   .\save-ssh-key.ps1 192.168.1.1:2222
#
# Default user: root
# Default port: 22

param(
    [string]$Target = ""
)

$User      = ""
$HostAddr  = ""
$Port      = ""

# Parse user@host:port / user@host / host:port / host
if ($Target -ne "") {
    if ($Target -match '^([^@]+)@([^:]+):(\d+)$') {
        $User     = $Matches[1]
        $HostAddr = $Matches[2]
        $Port     = $Matches[3]
    } elseif ($Target -match '^([^@]+)@([^:]+)$') {
        $User     = $Matches[1]
        $HostAddr = $Matches[2]
    } elseif ($Target -match '^([^:]+):(\d+)$') {
        $HostAddr = $Matches[1]
        $Port     = $Matches[2]
    } elseif ($Target -match '^([^:@]+)$') {
        $HostAddr = $Matches[1]
    } else {
        Write-Error "Invalid target format: $Target"
        Write-Host "Use: user@host:port | user@host | host:port | host"
        exit 1
    }
}

# Defaults
if ([string]::IsNullOrWhiteSpace($User)) {
    $User = "root"
}

if ([string]::IsNullOrWhiteSpace($Port)) {
    $Port = "22"
}

if ([string]::IsNullOrWhiteSpace($HostAddr)) {
    $HostAddr = Read-Host "Remote host (IP or DNS)"
}

Write-Host "Target: ${User}@${HostAddr}:${Port}"

# Ensure ssh tools are available
foreach ($cmd in @("ssh", "ssh-keygen")) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Write-Error "Missing required command: $cmd`nInstall OpenSSH (Settings > Apps > Optional features > OpenSSH Client) or Git for Windows."
        exit 1
    }
}

# Key paths
$SshDir  = Join-Path $env:USERPROFILE ".ssh"
$KeyPath = Join-Path $SshDir "id_ed25519"
$PubPath = "$KeyPath.pub"

if (-not (Test-Path $SshDir)) {
    New-Item -ItemType Directory -Path $SshDir | Out-Null
}

# Generate key if missing
if (-not (Test-Path $KeyPath) -or -not (Test-Path $PubPath)) {
    Write-Host "No SSH key found. Generating: $KeyPath"
    ssh-keygen -t ed25519 -f $KeyPath -N '""'
} else {
    Write-Host "SSH key already exists: $KeyPath"
}

$PubKey = Get-Content $PubPath -Raw

# Install public key on remote host
Write-Host ""
Write-Host "Installing public key to remote host..."
Write-Host "When prompted, enter remote password once."
Write-Host ""

$RemoteCmd = @"
mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo '$($PubKey.Trim())' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys
"@

ssh -p $Port "${User}@${HostAddr}" $RemoteCmd

Write-Host ""
Write-Host "Done. Test passwordless login:"
Write-Host "  ssh -p $Port ${User}@${HostAddr}"

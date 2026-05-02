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
    [string]$Target = "",
    [switch]$Debug
)

function Log { if ($Debug) { Write-Host $args } }

$User      = ""
$HostAddr  = ""
$Port      = ""
$UserExplicit = $false
$PortExplicit = $false

# Parse user@host:port / user@host / host:port / host
if ($Target -ne "") {
    if ($Target -match '^([^@]+)@([^:]+):(\d+)$') {
        $User     = $Matches[1]
        $HostAddr = $Matches[2]
        $Port     = $Matches[3]
        $UserExplicit = $true
        $PortExplicit = $true
    } elseif ($Target -match '^([^@]+)@([^:]+)$') {
        $User     = $Matches[1]
        $HostAddr = $Matches[2]
        $UserExplicit = $true
    } elseif ($Target -match '^([^:]+):(\d+)$') {
        $HostAddr = $Matches[1]
        $Port     = $Matches[2]
        $PortExplicit = $true
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

# Resolve SSH config alias: if HostAddr matches a Host alias, use its HostName/User/Port
$ResolvedFromAlias = $false
$ConfigPath = Join-Path $env:USERPROFILE ".ssh\config"
if (Test-Path $ConfigPath) {
    $ConfigContent = Get-Content $ConfigPath
    $_InAnyBlock = $false
    $IsTarget = $false
    $BlockHostName = ""
    $BlockUser = ""
    $BlockPort = ""
    $ResolvedHostName = ""
    $ResolvedUser = ""
    $ResolvedPort = ""
    foreach ($Line in $ConfigContent) {
        if ($Line -match '^\s*Host\s+(.+)$') {
            # Save previous target block's values before they get overwritten
            if ($IsTarget -and -not [string]::IsNullOrWhiteSpace($BlockHostName)) {
                $ResolvedHostName = $BlockHostName
                $ResolvedUser = $BlockUser
                $ResolvedPort = $BlockPort
                break
            }
            $IsTarget = $false
            foreach ($Alias in ($Matches[1].Trim() -split '\s+')) {
                if ($Alias -eq $HostAddr) {
                    $IsTarget = $true
                    break
                }
            }
            if ($IsTarget) {
                $BlockHostName = ""
                $BlockUser = ""
                $BlockPort = ""
            }
            $_InAnyBlock = $true
        } elseif ($_InAnyBlock -and $Line -match '^\s+\S') {
            if ($IsTarget) {
                if ($Line -match '^\s*HostName\s+(.+)$') { $BlockHostName = $Matches[1].Trim() }
                if ($Line -match '^\s*User\s+(.+)$')     { $BlockUser = $Matches[1].Trim() }
                if ($Line -match '^\s*Port\s+(.+)$')     { $BlockPort = $Matches[1].Trim() }
            }
        } else {
            $_InAnyBlock = $false
        }
    }
    # Also save if the LAST block was the target
    if ($IsTarget -and -not [string]::IsNullOrWhiteSpace($BlockHostName)) {
        $ResolvedHostName = $BlockHostName
        $ResolvedUser = $BlockUser
        $ResolvedPort = $BlockPort
    }
    if (-not [string]::IsNullOrWhiteSpace($ResolvedHostName)) {
        $HostAddr = $ResolvedHostName
        $ResolvedFromAlias = $true
        if (-not $UserExplicit -and -not [string]::IsNullOrWhiteSpace($ResolvedUser)) {
            $User = $ResolvedUser
        }
        if (-not $PortExplicit -and -not [string]::IsNullOrWhiteSpace($ResolvedPort)) {
            $Port = $ResolvedPort
        }
    }
}

if ([string]::IsNullOrWhiteSpace($HostAddr)) {
    $HostAddr = Read-Host "Remote host (IP or DNS)"
}

Log "Target: ${User}@${HostAddr}:${Port}"

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
    Log "No SSH key found. Generating: $KeyPath"
    ssh-keygen -t ed25519 -f $KeyPath -N '""' 2>$null
} else {
    Log "SSH key already exists: $KeyPath"
}

$PubKey = Get-Content $PubPath -Raw

# Install public key on remote host
Log "Installing public key to remote host..."

# Include legacy RSA host key support for older servers (additive — does not downgrade modern servers)
$SshOpts = @("-o", "HostKeyAlgorithms=+ssh-rsa", "-o", "PubkeyAcceptedKeyTypes=+ssh-rsa")

$RemoteCmd = @"
AUTH_DIR=`$( [ -d /etc/dropbear ] && echo /etc/dropbear || echo ~/.ssh ) && mkdir -p `$AUTH_DIR && chmod 700 `$AUTH_DIR && ( grep -qxF '$($PubKey.Trim())' `$AUTH_DIR/authorized_keys 2>/dev/null || echo '$($PubKey.Trim())' >> `$AUTH_DIR/authorized_keys ) && chmod 600 `$AUTH_DIR/authorized_keys
"@

ssh @SshOpts -p $Port "${User}@${HostAddr}" $RemoteCmd 2>$null

# Save to SSH config (skip if resolved from existing alias)
$Date = Get-Date -Format "yyyy-MM-dd"
$HostAlias = if ($Port -eq "22") { "${User}@${HostAddr}" } else { "${User}@${HostAddr}:${Port}" }

$Duplicate = $false
if ($ResolvedFromAlias) {
    $Duplicate = $true
    Log "Using existing SSH config alias for $HostAddr"
} elseif (Test-Path $ConfigPath) {
    # Dedup: check if same HostName + User + Port already exists
    $ConfigRaw = Get-Content $ConfigPath -Raw
    $Blocks = $ConfigRaw -split "(?m)(?=^Host\s)"
    foreach ($Block in $Blocks) {
        if ($Block -match "HostName\s+$([regex]::Escape($HostAddr))") {
            $HasUser = $Block -match "User\s+$([regex]::Escape($User))"
            $HasPort = if ($Port -eq "22") { ($Block -notmatch "Port\s+") -or ($Block -match "Port\s+22\b") } else { $Block -match "Port\s+$Port\b" }
            if ($HasUser -and $HasPort) {
                $Duplicate = $true
                break
            }
        }
    }
}

if ($Duplicate) {
    if (-not $ResolvedFromAlias) {
        Log "SSH config already has entry for $HostAlias"
    }
} else {
    $Entry = @"

# Added by ssk - $Date
Host $HostAlias
    HostName $HostAddr
    User $User
    Port $Port

"@
    if (-not (Test-Path $ConfigPath)) {
        Set-Content -Path $ConfigPath -Value $Entry.TrimStart() -NoNewline
    } else {
        Add-Content -Path $ConfigPath -Value $Entry
    }
    Log "Saved to SSH config: Host $HostAlias"
}

ssh @SshOpts -p $Port "${User}@${HostAddr}"

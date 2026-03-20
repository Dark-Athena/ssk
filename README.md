# ssk — SSH Key Installer

[中文文档](README_zh.md)

Automatically generates an SSH key pair (if needed) and installs it on a remote host for passwordless login.

Supports **Windows** (PowerShell + batch wrapper) and **Linux/macOS** (Bash).

---

## Files

| File | Platform | Description |
|------|----------|-------------|
| `save-ssh-key.ps1` | Windows | PowerShell script — generates key and installs it via SSH |
| `ssk.cmd` | Windows | Batch wrapper — double-click or call from CMD |
| `ssk.sh` | Linux / macOS | Bash script — uses `ssh-copy-id` |

---

## Usage

### Windows

**Double-click** `ssk.cmd`, or run from Command Prompt / PowerShell:

```cmd
ssk.cmd
ssk.cmd root@192.168.1.1
ssk.cmd root@192.168.1.1:2222
ssk.cmd 192.168.1.1
ssk.cmd 192.168.1.1:2222
```

You can also call the PowerShell script directly:

```powershell
.\save-ssh-key.ps1
.\save-ssh-key.ps1 root@192.168.1.1
.\save-ssh-key.ps1 root@192.168.1.1:2222
.\save-ssh-key.ps1 192.168.1.1
.\save-ssh-key.ps1 192.168.1.1:2222
```

### Linux / macOS

```bash
chmod +x ssk.sh

./ssk.sh
./ssk.sh root@192.168.1.1
./ssk.sh root@192.168.1.1:2222
./ssk.sh 192.168.1.1
./ssk.sh 192.168.1.1:2222
```

---

## Argument format

```
[user@]host[:port]
```

| Example | User | Host | Port |
|---------|------|------|------|
| `root@192.168.1.1:2222` | root | 192.168.1.1 | 2222 |
| `root@192.168.1.1` | root | 192.168.1.1 | 22 |
| `192.168.1.1:2222` | root *(default)* | 192.168.1.1 | 2222 |
| `192.168.1.1` | root *(default)* | 192.168.1.1 | 22 |
| *(no argument)* | root *(default)* | prompted | 22 |

- **Default user**: `root`
- **Default port**: `22`

---

## Requirements

### Windows
- Windows 10 / 11 with **OpenSSH Client** enabled  
  *(Settings → Apps → Optional features → OpenSSH Client)*  
  or **Git for Windows** (includes `ssh`, `ssh-keygen`)
- PowerShell 5.1 or later (built-in on Windows 10+)

### Linux / macOS
- `ssh`, `ssh-keygen`, `ssh-copy-id` (standard on most distributions)

---

## How it works

1. Checks whether `~/.ssh/id_ed25519` already exists.  
   If not, generates a new **Ed25519** key pair with an empty passphrase.
2. Prompts you to enter the remote host's password **once**.
3. Installs your public key in `~/.ssh/authorized_keys` on the remote host.
4. Future logins are passwordless.

---

## Security notes

- The generated private key has **no passphrase** for convenience.  
  If you need a passphrase-protected key, run `ssh-keygen` manually.
- Make sure `~/.ssh/` and `~/.ssh/authorized_keys` have correct permissions  
  (`700` and `600` respectively) — the scripts set these automatically on Linux.

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

### Connect to a host

**Windows** — double-click `ssk.cmd`, or run from Command Prompt / PowerShell:

```cmd
ssk
ssk root@192.168.1.1
ssk root@192.168.1.1:2222
ssk 192.168.1.1
ssk 192.168.1.1:2222
ssk myserver
```

**Linux / macOS:**

```bash
chmod +x ssk.sh

./ssk.sh
./ssk.sh root@192.168.1.1
./ssk.sh root@192.168.1.1:2222
./ssk.sh 192.168.1.1
./ssk.sh 192.168.1.1:2222
./ssk.sh myserver
```

You can also call the PowerShell script directly:

```powershell
.\save-ssh-key.ps1
.\save-ssh-key.ps1 root@192.168.1.1
```

### List saved hosts

After connecting, ssk automatically saves the host to `~/.ssh/config`:

```cmd
:: Windows
ssk list
```

```bash
# Linux / macOS
./ssk.sh list
```

Example output:

```
1  root@192.168.1.1:22  [root@192.168.1.1]
2  admin@10.0.0.5:2222  [admin@10.0.0.5:2222]
```

### Connect by index

Use the number from `ssk list` to connect directly:

```cmd
:: Windows
ssk --id 2
```

```bash
# Linux / macOS
./ssk.sh --id 2
```

### Rename host aliases

Give a host a friendly name for easier `ssh` access:

```cmd
:: Windows
ssk list rename root@192.168.1.1 myserver
```

```bash
# Linux / macOS
./ssk.sh list rename root@192.168.1.1 myserver
```

### Debug mode

Add `--debug` for verbose output:

```cmd
ssk --debug root@192.168.1.1
```

```bash
./ssk.sh --debug root@192.168.1.1
```

After renaming, connect with `ssh myserver` instead of the full address. You can also edit `~/.ssh/config` directly to add comments — ssk will not overwrite existing entries.

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
| `myserver` | *(from config)* | *(from config)* | *(from config)* |
| *(no argument)* | root *(default)* | prompted | 22 |

- **Default user**: `root`
- **Default port**: `22`
- **SSH config aliases**: if the host matches a `Host` alias in `~/.ssh/config`, ssk resolves the real HostName, User, and Port from it. Explicit `user@` or `:port` in the argument override config values.

---

## Requirements

### Windows
- Windows 10 / 11 with **OpenSSH Client** enabled
  *(Settings → Apps → Optional features → OpenSSH Client)*
  or **Git for Windows** (includes `ssh`, `ssh-keygen`)
- PowerShell 5.1 or later (built-in on Windows 10+)

### Linux / macOS
- `ssh`, `ssh-keygen` (standard on most distributions)
- `ssh-copy-id` — used for standard OpenSSH servers; not required for Dropbear targets

---

## How it works

1. Checks whether `~/.ssh/id_ed25519` already exists.
   If not, generates a new **Ed25519** key pair with an empty passphrase.
2. Probes the remote server to detect its SSH implementation and supported host key types.
3. Prompts you to enter the remote host's password **once**.
4. Installs your public key on the remote host (skipped if already present):
   - **Dropbear** servers: writes to `/etc/dropbear/authorized_keys` (or `~/.ssh/` if that path doesn't exist).
   - **Standard OpenSSH** servers: uses `ssh-copy-id` to write to `~/.ssh/authorized_keys`.
5. Saves the connection info to `~/.ssh/config` (skipped if already exists).
6. Connects to the remote host immediately — no extra step needed.

---

## Security notes

- The generated private key has **no passphrase** for convenience.
  If you need a passphrase-protected key, run `ssh-keygen` manually.
- Make sure `~/.ssh/` and `~/.ssh/authorized_keys` have correct permissions
  (`700` and `600` respectively) — the scripts set these automatically on Linux.
- Legacy RSA host key algorithms are enabled only when the server requires them; modern servers are unaffected.

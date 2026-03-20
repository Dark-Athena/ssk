# ssk — SSH 密钥安装工具

自动生成 SSH 密钥对（如不存在）并将其安装到远程主机，实现免密码登录。

支持 **Windows**（PowerShell + 批处理脚本）和 **Linux/macOS**（Bash）。

---

## 文件说明

| 文件 | 平台 | 说明 |
|------|------|------|
| `save-ssh-key.ps1` | Windows | PowerShell 脚本 — 生成密钥并通过 SSH 安装 |
| `ssk.cmd` | Windows | 批处理脚本 — 双击或在 CMD 中调用 |
| `ssk.sh` | Linux / macOS | Bash 脚本 — 使用 `ssh-copy-id` |

---

## 使用方法

### Windows

**双击** `ssk.cmd`，或在命令提示符 / PowerShell 中运行：

```cmd
ssk.cmd
ssk.cmd root@192.168.1.1
ssk.cmd root@192.168.1.1:2222
ssk.cmd 192.168.1.1
ssk.cmd 192.168.1.1:2222
```

也可以直接调用 PowerShell 脚本：

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

## 参数格式

```
[用户名@]主机地址[:端口]
```

| 示例 | 用户名 | 主机地址 | 端口 |
|------|--------|----------|------|
| `root@192.168.1.1:2222` | root | 192.168.1.1 | 2222 |
| `root@192.168.1.1` | root | 192.168.1.1 | 22 |
| `192.168.1.1:2222` | root *(默认)* | 192.168.1.1 | 2222 |
| `192.168.1.1` | root *(默认)* | 192.168.1.1 | 22 |
| *(不传参数)* | root *(默认)* | 交互输入 | 22 |

- **默认用户名**：`root`
- **默认端口**：`22`

---

## 环境要求

### Windows
- Windows 10 / 11，已启用 **OpenSSH 客户端**  
  *(设置 → 应用 → 可选功能 → OpenSSH 客户端)*  
  或已安装 **Git for Windows**（包含 `ssh`、`ssh-keygen`）
- PowerShell 5.1 或更高版本（Windows 10+ 内置）

### Linux / macOS
- `ssh`、`ssh-keygen`、`ssh-copy-id`（大多数发行版已内置）

---

## 工作原理

1. 检查 `~/.ssh/id_ed25519` 是否已存在。  
   若不存在，则自动生成一对新的 **Ed25519** 密钥对，密码短语为空。
2. 提示输入远程主机密码**一次**。
3. 将公钥安装到远程主机的 `~/.ssh/authorized_keys` 中。
4. 此后登录无需密码。

---

## 安全说明

- 生成的私钥**不设置密码短语**，方便使用。  
  如需保护私钥，请手动运行 `ssh-keygen` 并设置密码短语。
- 请确保 `~/.ssh/` 和 `~/.ssh/authorized_keys` 拥有正确的权限  
  （分别为 `700` 和 `600`）— 脚本会在 Linux 上自动设置。

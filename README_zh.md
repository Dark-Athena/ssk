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

### 交互模式

不带参数运行 `ssk`（或 `ssk.cmd` / `./ssk.sh`）即可进入交互式主机选择界面。会列出所有已保存的主机，输入序号、连接字符串或别名即可连接。连接结束后自动返回提示符，无需退出脚本。

```cmd
:: Windows
ssk
```

```bash
# Linux / macOS
./ssk.sh
```

#### 交互命令

| 命令 | 说明 |
|------|------|
| `/ls` `/list` | 显示主机列表 |
| `/del <序号>` | 删除指定序号的连接 |
| `/rename <序号> <新别名>` | 重命名指定序号的主机别名 |
| `/add <user@host>` | 保存新连接到 SSH config |
| `/filter <关键词>` | 按关键词过滤列表 |
| `/clear` | 清屏 |
| `/help` `/h` | 显示帮助 |
| `/q` `/quit` `/exit` | 退出交互模式 |
| `<序号>` | 按序号连接 |
| `<连接字符串>` | 按 user@host:port 或别名连接 |

### 直接连接主机

```cmd
:: Windows
ssk root@192.168.1.1
ssk root@192.168.1.1:2222
ssk 192.168.1.1
ssk 192.168.1.1:2222
ssk myserver
```

```bash
# Linux / macOS
./ssk.sh root@192.168.1.1
./ssk.sh root@192.168.1.1:2222
./ssk.sh 192.168.1.1
./ssk.sh 192.168.1.1:2222
./ssk.sh myserver
```

也可以直接调用 PowerShell 脚本：

```powershell
.\save-ssh-key.ps1
.\save-ssh-key.ps1 root@192.168.1.1
```

### 查看已保存的主机

连接成功后，ssk 会自动将主机信息保存到 `~/.ssh/config`：

```cmd
:: Windows
ssk list
```

```bash
# Linux / macOS
./ssk.sh list
```

输出示例：

```
1  root@192.168.1.1:22  [root@192.168.1.1]
2  admin@10.0.0.5:2222  [admin@10.0.0.5:2222]
```

### 通过序号连接

使用 `ssk list` 显示的序号直接连接：

```cmd
:: Windows
ssk --id 2
```

```bash
# Linux / macOS
./ssk.sh --id 2
```

### 重命名主机别名

给主机起一个好记的名字，之后用 `ssh 别名` 即可快速连接：

```cmd
:: Windows
ssk list rename root@192.168.1.1 myserver
```

```bash
# Linux / macOS
./ssk.sh list rename root@192.168.1.1 myserver
```

### 调试模式

添加 `--debug` 查看详细输出：

```cmd
ssk --debug root@192.168.1.1
```

```bash
./ssk.sh --debug root@192.168.1.1
```

重命名后，用 `ssh myserver` 代替完整地址连接。你也可以直接编辑 `~/.ssh/config` 添加注释 — ssk 不会覆盖已有条目。

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
| `myserver` | *(从 config 读取)* | *(从 config 读取)* | *(从 config 读取)* |
| *(不传参数)* | root *(默认)* | 交互输入 | 22 |

- **默认用户名**：`root`
- **默认端口**：`22`
- **SSH config 别名**：如果主机名匹配 `~/.ssh/config` 中的 `Host` 别名，ssk 会自动解析出真实的 HostName、User 和 Port。参数中显式指定的 `用户名@` 或 `:端口` 优先级高于 config。

---

## 环境要求

### Windows
- Windows 10 / 11，已启用 **OpenSSH 客户端**
  *(设置 → 应用 → 可选功能 → OpenSSH 客户端)*
  或已安装 **Git for Windows**（包含 `ssh`、`ssh-keygen`）
- PowerShell 5.1 或更高版本（Windows 10+ 内置）

### Linux / macOS
- `ssh`、`ssh-keygen`（大多数发行版已内置）
- `ssh-copy-id` — 用于标准 OpenSSH 服务器；连接 Dropbear 目标时不需要

---

## 工作原理

1. 检查 `~/.ssh/id_ed25519` 是否已存在。
   若不存在，则自动生成一对新的 **Ed25519** 密钥对，密码短语为空。
2. 探测远程服务器，检测其 SSH 实现类型及支持的主机密钥算法。
3. 提示输入远程主机密码**一次**。
4. 将公钥安装到远程主机（已存在则跳过）：
   - **Dropbear** 服务器：写入 `/etc/dropbear/authorized_keys`（若该路径不存在则写入 `~/.ssh/`）。
   - **标准 OpenSSH** 服务器：使用 `ssh-copy-id` 写入 `~/.ssh/authorized_keys`。
5. 将连接信息保存到 `~/.ssh/config`（已存在则跳过）。
6. 安装完成后立即连接远程主机，无需额外操作。

---

## 安全说明

- 生成的私钥**不设置密码短语**，方便使用。
  如需保护私钥，请手动运行 `ssh-keygen` 并设置密码短语。
- 请确保 `~/.ssh/` 和 `~/.ssh/authorized_keys` 拥有正确的权限
  （分别为 `700` 和 `600`）— 脚本会在 Linux 上自动设置。
- 仅在服务器需要时才启用旧版 RSA 主机密钥算法，不影响现代服务器。

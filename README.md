# 🔌 Clash VPN Toggle

一键开关 Clash Verge VPN 代理，**无需管理员权限**。

## ✨ 功能

- **开 VPN** — 启动 Clash 核心 + 启用系统代理 (`127.0.0.1:7897`)
- **关 VPN** — 关闭系统代理（让网络走直连）
- **安全网** — 测试模式下自动回退，防止操作失误断网
- **零权限** — 只改用户级注册表，不碰 Windows 服务

## 🚀 快速开始

```powershell
# 查看 VPN 状态
.\toggle-clash.ps1 status

# 开启 VPN
.\toggle-clash.ps1 on

# 关闭 VPN
.\toggle-clash.ps1 off

# 开启 VPN（带 30 秒安全网，测试时推荐）
.\toggle-clash.ps1 on -SafeSecs 30
```

## 📋 环境要求

- Windows 10/11
- [Clash Verge Rev](https://github.com/clash-verge-rev/clash-verge-rev) 已安装
- PowerShell 5.1+

## 🔧 工作原理

| 操作 | 做了什么 |
|------|---------|
| `on` | 启动 `clash-verge.exe` GUI（如核心未运行）→ 等待端口 7897 就绪 → 启用系统代理 |
| `off` | 禁用系统代理（Clash 核心保持后台运行，不占资源） |
| `-SafeSecs N` | 先备份当前代理设置，生成独立后台进程，N 秒后自动恢复；测试网络可达后取消 |

### 为什么 OFF 不关闭核心进程？

Clash 核心由 Windows 服务 (`clash_verge_service`) 管理，普通用户权限无法直接终止。但关闭系统代理后流量不再经过代理，效果等同于关闭 VPN。核心后台空转几乎不消耗资源。

## 📝 配置

默认配置已硬编码在脚本顶部，可按需修改：

```powershell
$installDir  = "I:\b"                        # Clash Verge 安装目录
$proxyServer = "127.0.0.1:7897"              # 代理端口
```

## 📦 安装为 opencode 技能

将本仓库克隆到技能目录：

```powershell
git clone https://github.com/id5463/clash-toggle.git $env:USERPROFILE\.agents\skills\clash-toggle
```

之后在 opencode 中直接说「开 VPN」「关 VPN」即可触发。

## 📄 License

MIT

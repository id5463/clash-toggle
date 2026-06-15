---
name: clash-toggle
description: "Toggle Clash Verge VPN on/off by controlling Windows system proxy. No admin privileges required. Use when user mentions VPN, Clash, proxy, 翻墙, 代理, 科学上网, 开启VPN, 关闭VPN, 开关Clash etc."
version: 1.0.0
author: id5463
license: MIT
platforms: [windows]
metadata:
  tags: [vpn, clash, proxy, network]
---

# Clash VPN Toggle

Toggle Clash Verge VPN on/off by controlling the Windows system proxy. No admin privileges required.

## When to Use

- User asks to turn on/off VPN, Clash, proxy, 翻墙, 代理, 科学上网
- User asks about network proxy status
- User mentions "开启VPN", "关闭VPN", "开关Clash" etc.

## How It Works

- **ON**: Ensures Clash core is running (launches `clash-verge.exe` GUI if needed), then enables system proxy (`127.0.0.1:7897`)
- **OFF**: Disables system proxy. Core process stays running (managed by Windows service) but idle.
- **STATUS**: Shows current proxy state and core process info.

## Commands

Open/close the VPN proxy using the toggle script:

```powershell
# Check status
& "C:\Users\a\.agents\skills\clash-toggle\toggle-clash.ps1" status

# Turn VPN ON
& "C:\Users\a\.agents\skills\clash-toggle\toggle-clash.ps1" on

# Turn VPN OFF
& "C:\Users\a\.agents\skills\clash-toggle\toggle-clash.ps1" off

# Turn ON with 30-second safety net (auto-restores if network breaks)
& "C:\Users\a\.agents\skills\clash-toggle\toggle-clash.ps1" on -SafeSecs 30

# Turn OFF with 20-second safety net
& "C:\Users\a\.agents\skills\clash-toggle\toggle-clash.ps1" off -SafeSecs 20
```

## Safety Net

When testing or when network reliability is uncertain, use `-SafeSecs N`. This:
1. Backs up current proxy settings
2. Spawns a background watcher that restores settings after N seconds
3. After making changes, tests internet connectivity
4. If internet works: cancel watcher, keep changes
5. If internet fails: wait for watcher to auto-restore settings

**Always use `-SafeSecs 30` when testing toggle operations.**

## Configuration

| Setting | Value |
|---------|-------|
| Install dir | `I:\b\` |
| Core binary | `I:\b\verge-mihomo.exe` |
| GUI app | `I:\b\clash-verge.exe` |
| Proxy port | `127.0.0.1:7897` |
| API port | `127.0.0.1:9097` |
| Config dir | `%APPDATA%\io.github.clash-verge-rev.clash-verge-rev\` |
| Service | `clash_verge_service` (runs automatically) |

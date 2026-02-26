# Windows 远程桌面端口修改工具

A PowerShell script to safely change the Windows Remote Desktop (RDP) listening port.  
一个用于安全修改 Windows 远程桌面（RDP）监听端口的 PowerShell 脚本。

This tool modifies the RDP port in the Windows registry and ensures the Windows Firewall rule is properly configured for the new port.  
该工具会修改 Windows 注册表中的 RDP 端口，并自动配置 Windows 防火墙规则。

It is designed to be executed directly from GitHub using PowerShell `IEX` (Invoke-Expression).  
脚本支持通过 PowerShell 的 `IEX` 方式直接从 GitHub 在线执行。


## Features | 功能特点

- Interactive port selection  
  交互式输入端口

- Validates port range (1025–65535)  
  自动校验端口范围（1025–65535）

- Detects if the port is already in use  
  自动检测端口是否被占用

- Updates Windows registry RDP port  
  修改注册表中的 RDP 端口

- Automatically creates or updates Windows Firewall rule  
  自动创建或更新 Windows 防火墙规则

- Optional immediate activation by restarting Remote Desktop Service  
  可选择立即重启远程桌面服务使其生效

- Auto administrator elevation (UAC prompt)  
  自动申请管理员权限（UAC 提示）


## Quick Run | 快速执行

Open **PowerShell as Administrator** and run:  
请以 **管理员身份打开 PowerShell** 并执行：

```powershell
iex ((Invoke-RestMethod https://api.github.com/repos/yytmy4lq/Set-WindowRDPPort/contents/Set-RDPPort.ps1?ref=main).content | % { [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($_)) })
```


## The script will:
脚本将会：
1.	Ask which port to use
询问你要使用的端口
2.	Verify the port is available
检查端口是否可用
3.	Change the RDP port
修改远程桌面端口
4.	Configure Windows Firewall
配置 Windows 防火墙规则
5.	Optionally restart the Remote Desktop service
可选择立即重启远程桌面服务


## Why Change the RDP Port? | 为什么要修改 RDP 端口？

Changing the default RDP port (3389) helps reduce:  
修改默认 RDP 端口（3389）可以减少：

- Automated internet scanning
网络自动扫描
- Basic brute-force attacks
暴力破解攻击
- Common botnet probing
僵尸网络探测

This is not a replacement for security hardening, but it significantly reduces attack noise.  
这并不能替代安全加固，但能显著减少被扫描和攻击的概率。


## Requirements | 系统要求
	•	Windows 10 / Windows 11 / Windows Server
	•	Administrator privileges | 管理员权限
	•	PowerShell 5.1 or newer


## After Changing the Port | 修改后如何连接

When connecting via Remote Desktop, you must specify the port:
使用远程桌面连接时必须指定端口：
IP地址:端口
```
IP_ADDRESS:PORT
```

Example | 示例：
```
192.168.1.10:33901
```


## Security Notes | 安全说明

- Only modifies RDP registry PortNumber
仅修改 RDP 注册表端口

- Only creates/updates a firewall inbound rule
仅创建/更新一个防火墙入站规则

- Does NOT open UDP RDP 
不开启 UDP RDP

- Does NOT disable Windows security features
不会关闭 Windows 安全功能


## Restore Default Port | 恢复默认端口

Default RDP port:
默认端口：
```
3389
```

Simply run the script again and enter 3389.
再次运行脚本并输入 3389 即可恢复。


## Important Notice | 重要提示

Always make sure you have another way to access the machine before changing RDP settings.
修改前请务必确认你仍有其他方式进入系统（例如本地、KVM、控制台等）。

You may lose remote access if firewall or service restart fails.
如果防火墙或服务重启失败，可能会导致远程无法连接。


## Disclaimer | 免责声明

This script modifies system configuration. Use at your own risk.
该脚本会修改系统配置，请自行承担使用风险。

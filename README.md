# Set-WindowsRDPPort

A PowerShell script to safely change the Windows Remote Desktop (RDP) listening port.

This tool modifies the RDP port in the Windows registry and ensures the Windows Firewall rule is properly configured for the new port.

It is designed to be executed directly from GitHub using PowerShell `IEX` (Invoke-Expression).

---

## Features

- Interactive port selection
- Validates port range (1025–65535)
- Detects if the port is already in use (TCP)
- Updates Windows registry RDP port
- Automatically creates or updates Windows Firewall rule
- Optional immediate activation by restarting Remote Desktop Service
- Auto administrator elevation (UAC prompt)

---

## Quick Run (Recommended)

Open **PowerShell as Administrator** and run:

```powershell
iex ((Invoke-RestMethod https://api.github.com/repos/yytmy4lq/Set-WindowRDPPort/contents/Set-RDPPort.ps1?ref=main).content | % { [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($_)) })

# =========================
# Set-RDPPort.ps1 (IEX-ready)
# - 交互式指定端口
# - 检查端口范围 (1025-65535)
# - 检查端口是否已被占用（TCP/UDP 任一占用即终止）
# - 写入注册表 RDP PortNumber
# - 创建/更新防火墙入站规则（TCP+UDP）
# - 可选重启 TermService 让端口立即生效
# - 自动申请管理员权限（适合 IEX / GitHub raw 执行）
# =========================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Ensure-Admin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  $p  = New-Object Security.Principal.WindowsPrincipal($id)
  if (-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "需要管理员权限，正在请求 UAC 提升..." -ForegroundColor Yellow
    $args = @(
      "-NoProfile",
      "-ExecutionPolicy", "Bypass",
      "-Command",
      "& { $($MyInvocation.MyCommand.Definition) }"
    )
    Start-Process -FilePath "powershell.exe" -Verb RunAs -ArgumentList $args | Out-Null
    exit 0
  }
}

function Read-ValidPort {
  while ($true) {
    $inputPort = Read-Host "请输入要使用的 RDP 端口（1025-65535）"
    if ($inputPort -notmatch '^\d+$') {
      Write-Host "错误：请输入纯数字端口。" -ForegroundColor Red
      continue
    }
    $port = [int]$inputPort
    if ($port -le 1024 -or $port -ge 65535) {
      Write-Host "错误：端口必须在 1025-65535 之间。" -ForegroundColor Red
      continue
    }
    return $port
  }
}

function Test-PortInUse {
  param([Parameter(Mandatory=$true)][int]$Port)

  $tcpInUse = $false
  $udpInUse = $false

  # TCP
  try {
    if (Get-Command Get-NetTCPConnection -ErrorAction SilentlyContinue) {
      $tcpInUse = @(Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue).Count -gt 0
    } else {
      $tcpInUse = (netstat -ano -p tcp | Select-String -Pattern "[:.]$Port\s").Count -gt 0
    }
  } catch { $tcpInUse = $true }

  # UDP
  try {
    if (Get-Command Get-NetUDPEndpoint -ErrorAction SilentlyContinue) {
      $udpInUse = @(Get-NetUDPEndpoint -LocalPort $Port -ErrorAction SilentlyContinue).Count -gt 0
    } else {
      $udpInUse = (netstat -ano -p udp | Select-String -Pattern "[:.]$Port\s").Count -gt 0
    }
  } catch { $udpInUse = $true }

  return ($tcpInUse -or $udpInUse)
}

function Get-CurrentRdpPort {
  $path = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp"
  $v = (Get-ItemProperty -Path $path -Name "PortNumber").PortNumber
  return [int]$v
}

function Set-RdpPort {
  param([Parameter(Mandatory=$true)][int]$Port)

  $path = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp"
  Set-ItemProperty -Path $path -Name "PortNumber" -Value $Port -Type DWord
}

function Upsert-FirewallRule {
  param(
    [Parameter(Mandatory=$true)][string]$Name,
    [Parameter(Mandatory=$true)][string]$Protocol,
    [Parameter(Mandatory=$true)][int]$Port
  )

  $existing = Get-NetFirewallRule -DisplayName $Name -ErrorAction SilentlyContinue
  if ($null -ne $existing) {
    Set-NetFirewallRule -DisplayName $Name -Enabled True | Out-Null
    Set-NetFirewallRule -DisplayName $Name -Profile Any | Out-Null
    Set-NetFirewallRule -DisplayName $Name -Direction Inbound | Out-Null
    Set-NetFirewallRule -DisplayName $Name -Action Allow | Out-Null
    Set-NetFirewallRule -DisplayName $Name -Protocol $Protocol | Out-Null
    Set-NetFirewallRule -DisplayName $Name -LocalPort $Port | Out-Null
  } else {
    New-NetFirewallRule -DisplayName $Name -Profile Any -Direction Inbound -Action Allow -Protocol $Protocol -LocalPort $Port | Out-Null
  }
}

function Restart-RdpServiceIfWanted {
  $ans = Read-Host "是否立即重启远程桌面服务 TermService 以立刻生效？(Y/N)"
  if ($ans -match '^(y|Y)$') {
    Write-Host "正在重启 TermService..." -ForegroundColor Yellow
    Restart-Service -Name "TermService" -Force
  } else {
    Write-Host "已跳过重启。RDP 端口可能需要重启服务或重启系统后才会完全生效。" -ForegroundColor Yellow
  }
}

# -------------------------
# Main
# -------------------------
Ensure-Admin

Write-Host "RDP 端口修改工具（IEX 版本）" -ForegroundColor Cyan
$oldPort = Get-CurrentRdpPort
Write-Host ("当前 RDP 端口：{0}" -f $oldPort)

$port = Read-ValidPort

if (Test-PortInUse -Port $port) {
  Write-Host ("错误：端口 {0} 已被占用（TCP/UDP），不会继续操作。" -f $port) -ForegroundColor Red
  exit 1
}

Write-Host ("端口 {0} 可用，开始写入注册表..." -f $port) -ForegroundColor Green
Set-RdpPort -Port $port

Write-Host "正在配置防火墙入站规则（TCP/UDP）..." -ForegroundColor Green
Upsert-FirewallRule -Name "RDPPORTLatest-TCP-In" -Protocol "TCP" -Port $port
Upsert-FirewallRule -Name "RDPPORTLatest-UDP-In" -Protocol "UDP" -Port $port

Write-Host ("完成：RDP 端口已从 {0} 修改为 {1}" -f $oldPort, $port) -ForegroundColor Cyan
Restart-RdpServiceIfWanted
Write-Host "全部操作完成。" -ForegroundColor Cyan
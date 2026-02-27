# =========================
# Set-RDPPort.ps1 (IEX-ready / GitHub-ready)
# - 交互式指定端口
# - 检查端口范围 (1025-65535)
# - 仅检查 TCP 端口是否已被占用（占用则终止）
# - 写入注册表 RDP PortNumber
# - 确保防火墙入站规则存在且指向新端口（TCP，Profile=Any）
#   * 规则不存在：创建
#   * 规则存在且已指向新端口：不做任何事（不报错、不终止）
#   * 规则存在但端口不同：更新到新端口
# - 可选重启 TermService 让端口立即生效
# - 自动申请管理员权限（IEX / GitHub raw 执行稳定）
# =========================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# IMPORTANT: 这里填你自己的 GitHub raw URL（用于 IEX 场景提权后“自我再下载执行”）
# 例如：https://raw.githubusercontent.com/<user>/<repo>/main/Set-RDPPort.ps1
$SelfUrl = "https://raw.githubusercontent.com/yytmy4lq/Set-WindowRDPPort/main/Set-RDPPort.ps1"

function Ensure-Admin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  $p  = New-Object Security.Principal.WindowsPrincipal($id)

  if ($p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    return
  }

  Write-Host "需要管理员权限，正在请求 UAC 提升..." -ForegroundColor Yellow

  # 1) 如果是从文件运行（双击/本地执行），用 -File 最稳
  if ($PSCommandPath -and (Test-Path -LiteralPath $PSCommandPath)) {
    $args = @(
      "-NoProfile",
      "-ExecutionPolicy", "Bypass",
      "-File", "`"$PSCommandPath`""
    )
    Start-Process -FilePath "powershell.exe" -Verb RunAs -ArgumentList $args | Out-Null
    Write-Host "已在新窗口以管理员权限继续执行（原窗口将退出）。" -ForegroundColor Yellow
    Start-Sleep -Seconds 2
    exit 0
  }

  # 2) IEX / 远程执行场景：提权后再从 $SelfUrl 下载并执行（避免传递脚本文本出错）
  if ([string]::IsNullOrWhiteSpace($SelfUrl)) {
    Write-Host "错误：当前为 IEX 场景，但未设置 SelfUrl，无法在提权后继续执行。" -ForegroundColor Red
    Write-Host "请在脚本顶部设置 `$SelfUrl 为你的 GitHub raw 地址。" -ForegroundColor Red
    Read-Host "按回车退出"
    exit 1
  }

  $cmd = "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; iex (irm '$SelfUrl')"
  $args2 = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-Command", $cmd
  )
  Start-Process -FilePath "powershell.exe" -Verb RunAs -ArgumentList $args2 | Out-Null
  Write-Host "已在新窗口以管理员权限继续执行（原窗口将退出）。" -ForegroundColor Yellow
  Start-Sleep -Seconds 2
  exit 0
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

function Test-TcpPortInUse {
  param([Parameter(Mandatory=$true)][int]$Port)

  try {
    if (Get-Command Get-NetTCPConnection -ErrorAction SilentlyContinue) {
      return (@(Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue).Count -gt 0)
    } else {
      # 兼容旧系统：用 netstat
      return ((netstat -ano -p tcp | Select-String -Pattern "[:.]$Port\s").Count -gt 0)
    }
  } catch {
    # 检查失败时，为安全起见当作占用
    return $true
  }
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

function Ensure-FirewallRuleTcpAny {
  param(
    [Parameter(Mandatory=$true)][string]$Name,
    [Parameter(Mandatory=$true)][int]$Port
  )

  $rule = Get-NetFirewallRule -DisplayName $Name -ErrorAction SilentlyContinue

  if ($null -eq $rule) {
    New-NetFirewallRule -DisplayName $Name -Profile Any -Direction Inbound -Action Allow -Protocol TCP -LocalPort $Port | Out-Null
    Write-Host ("已创建防火墙规则：{0} (TCP {1}, Profile=Any)" -f $Name, $Port) -ForegroundColor Green
    return
  }

  # 规则存在：读取当前端口
  $pf = Get-NetFirewallPortFilter -AssociatedNetFirewallRule $rule -ErrorAction SilentlyContinue
  $currentPort = $null
  if ($pf) { $currentPort = @($pf)[0].LocalPort }

  # 已经是目标端口 -> 不做事
  if (-not [string]::IsNullOrWhiteSpace($currentPort) -and $currentPort -ne "Any" -and $currentPort -eq "$Port") {
    Write-Host ("防火墙规则已存在且已指向目标端口：{0} (TCP {1})，无需处理。" -f $Name, $Port) -ForegroundColor Green
    return
  }

  # 否则更新到目标端口，并统一关键属性
  Set-NetFirewallRule -DisplayName $Name -Enabled True -Profile Any -Direction Inbound -Action Allow | Out-Null
  Set-NetFirewallPortFilter -AssociatedNetFirewallRule $rule -Protocol TCP -LocalPort $Port | Out-Null

  Write-Host ("防火墙规则已更新：{0} -> TCP {1}, Profile=Any" -f $Name, $Port) -ForegroundColor Yellow
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

Write-Host "Windows RDP 端口修改工具（IEX 版本）" -ForegroundColor Cyan

$oldPort = Get-CurrentRdpPort
Write-Host ("当前 RDP 端口：{0}" -f $oldPort) -ForegroundColor Cyan

$port = Read-ValidPort

if (Test-TcpPortInUse -Port $port) {
  Write-Host ("错误：端口 {0} 已被占用（TCP），不会继续操作。" -f $port) -ForegroundColor Red
  exit 1
}

Write-Host ("端口 {0} 可用，开始写入注册表..." -f $port) -ForegroundColor Green
Set-RdpPort -Port $port

Write-Host "正在检查并确保防火墙入站规则（TCP，Profile=Any）..." -ForegroundColor Green
Ensure-FirewallRuleTcpAny -Name "RDPPORTLatest-TCP-In" -Port $port

Write-Host ("完成：RDP 端口已从 {0} 修改为 {1}" -f $oldPort, $port) -ForegroundColor Cyan
Restart-RdpServiceIfWanted
Write-Host "全部操作完成。" -ForegroundColor Cyan

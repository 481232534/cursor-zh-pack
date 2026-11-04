# Cursor 界面汉化 —— 硬编码文案补丁引擎（不依赖 Python）
# 用法：
#   patch.ps1 -Mode Apply    应用汉化（自动提权）
#   patch.ps1 -Mode Restore  还原英文（自动提权）
#   patch.ps1 -Mode Check    只检查状态（不需要管理员）
#   patch.ps1 -Mode Apply -CursorDir "D:\Apps\Cursor"   手动指定安装目录
param(
    [ValidateSet('Apply', 'Restore', 'Check')]
    [string] $Mode = 'Apply',
    [string] $CursorDir,
    [switch] $NoElevate
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot          # 包根目录
$logPath = Join-Path $root 'patch.log'
$anchorsPath = Join-Path $PSScriptRoot 'anchors.json'

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Resolve-CursorDir {
    param([string] $explicit)
    if ($explicit) {
        if (-not (Test-Path -LiteralPath (Join-Path $explicit 'resources\app'))) {
            throw "指定的目录不像 Cursor 安装目录：$explicit"
        }
        return $explicit
    }
    # 1) 系统里注册的 cursor:// 协议指向真实 exe
    try {
        $cmd = (Get-Item -LiteralPath 'Registry::HKEY_CLASSES_ROOT\cursor\shell\open\command').GetValue('')
        if ($cmd) {
            $m = [regex]::Match($cmd, '"([^"]+\.exe)"')
            $exe = if ($m.Success) { $m.Groups[1].Value } else { ($cmd -split '\s+--')[0].Trim('"') }
            $dir = Split-Path -Parent $exe
            if (Test-Path -LiteralPath (Join-Path $dir 'resources\app')) { return $dir }
        }
    } catch { }
    # 2) 常见安装位置
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\cursor'),
        (Join-Path $env:ProgramFiles 'Cursor'),
        (Join-Path ${env:ProgramFiles(x86)} 'Cursor'),
        'D:\CursorSetup\cursor'
    )
    foreach ($c in $candidates) {
        if ($c -and (Test-Path -LiteralPath (Join-Path $c 'resources\app'))) { return $c }
    }
    throw '没找到 Cursor 安装目录。请用 -CursorDir 指定，例如：-CursorDir "D:\CursorSetup\cursor"'
}

function Read-Utf8 {
    param([string] $path)
    [IO.File]::ReadAllText($path, (New-Object Text.UTF8Encoding($false, $false)))
}

function Write-Utf8 {
    param([string] $path, [string] $text)
    [IO.File]::WriteAllText($path, $text, (New-Object Text.UTF8Encoding($false)))
}

function Get-Sha256Base64 {
    param([string] $path)
    $sha = [Security.Cryptography.SHA256]::Create()
    $fs = [IO.File]::OpenRead($path)
    try { $hash = $sha.ComputeHash($fs) } finally { $fs.Dispose(); $sha.Dispose() }
    [Convert]::ToBase64String($hash).TrimEnd('=')
}

# 同步 product.json 的 checksums，否则 Cursor 会提示「安装似乎损坏」
function Sync-Checksums {
    param([string] $appDir)
    $pj = Join-Path $appDir 'product.json'
    if (-not (Test-Path -LiteralPath $pj)) { return }
    $raw = [IO.File]::ReadAllText($pj, (New-Object Text.UTF8Encoding($false, $false)))
    $obj = $raw | ConvertFrom-Json
    if (-not $obj.checksums) { Write-Host '  [校验和] product.json 无 checksums，跳过'; return }
    $outDir = Join-Path $appDir 'out'
    $changed = 0
    $newText = $raw
    foreach ($prop in $obj.checksums.PSObject.Properties) {
        $key = $prop.Name
        $file = Join-Path $outDir $key
        if (-not (Test-Path -LiteralPath $file)) { continue }
        $real = Get-Sha256Base64 $file
        if ($real -ne $prop.Value) {
            $pattern = [regex]::Escape('"' + $key + '"') + '\s*:\s*"[^"]*"'
            $replacement = '"' + $key + '": "' + $real + '"'
            $newText = [regex]::Replace($newText, $pattern, $replacement)
            $changed++
        }
    }
    if ($changed -eq 0) { Write-Host '  [校验和] 与文件实际内容一致，无需改动'; return }
    $bak = $pj + '.zhbak'
    if (-not (Test-Path -LiteralPath $bak)) { Copy-Item -LiteralPath $pj -Destination $bak }
    [IO.File]::WriteAllText($pj, $newText, (New-Object Text.UTF8Encoding($false)))
    Write-Host "  [校验和] 已更新 product.json（$changed 项）"
}

function Invoke-Patch {
    $dir = Resolve-CursorDir $CursorDir
    Write-Host "安装目录：$dir"
    $appDir = Join-Path $dir 'resources\app'
    $wb = Join-Path $appDir 'out\vs\workbench'
    $files = @{
        'glass' = Join-Path $wb 'workbench.glass.main.js'
        'desktop' = Join-Path $wb 'workbench.desktop.main.js'
        'xai' = Join-Path $wb 'workbench.xai-commerce-prepaid.js'
    }
    foreach ($k in @('glass', 'desktop', 'xai')) {
        if (-not (Test-Path -LiteralPath $files[$k])) { throw "缺少文件：$($files[$k])" }
    }
    if (-not (Test-Path -LiteralPath $anchorsPath)) { throw "缺少锚点表：$anchorsPath" }
    $anchors = Read-Utf8 $anchorsPath | ConvertFrom-Json

    if ($Mode -eq 'Check') {
        foreach ($k in @('glass', 'desktop', 'xai')) {
            $text = Read-Utf8 $files[$k]
            $left = 0; $done = 0
            foreach ($rule in $anchors.$k) {
                if ($text.IndexOf($rule.old, [StringComparison]::Ordinal) -ge 0) { $left++ }
                if ($rule.new -and $text.IndexOf($rule.new, [StringComparison]::Ordinal) -ge 0) { $done++ }
            }
            $total = $anchors.$k.Count
            Write-Host ("  [{0}] 仍是英文的规则 {1} 条 / 已汉化 {2} 条（规则共 {3} 条）" -f $k, $left, $done, $total)
        }
        return
    }

    foreach ($k in @('glass', 'desktop', 'xai')) {
        $path = $files[$k]
        $bak = $path + '.zhbak'
        if ($Mode -eq 'Restore') {
            if (Test-Path -LiteralPath $bak) {
                Copy-Item -LiteralPath $bak -Destination $path -Force
                Write-Host "  [$k] 已还原为原版（$((Get-Item -LiteralPath $path).Length) 字节）"
            } else {
                Write-Host "  [$k] 没有备份，跳过（说明从未打过补丁）"
            }
            continue
        }

        if (-not (Test-Path -LiteralPath $bak)) {
            Copy-Item -LiteralPath $path -Destination $bak
            Write-Host "  [$k] 已备份原文件 -> $([IO.Path]::GetFileName($bak))"
        }
        $text = Read-Utf8 $path
        $before = $text.Length
        $hits = 0; $miss = 0
        foreach ($rule in $anchors.$k) {
            if ($text.IndexOf($rule.old, [StringComparison]::Ordinal) -lt 0) {
                $miss++
                continue
            }
            $text = $text.Replace($rule.old, $rule.new)
            $hits++
        }
        if ($hits -gt 0) {
            Write-Utf8 $path $text
        }
        Write-Host ("  [$k] 命中 {0} 条规则，未命中 {1} 条（版本差异或已汉化），文件 {2} -> {3} 字符" -f `
            $hits, $miss, $before, $text.Length)
    }

    Sync-Checksums $appDir
}

function Invoke-Elevated {
    $argv = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"{0}"' -f $PSCommandPath), '-Mode', $Mode, '-NoElevate')
    if ($CursorDir) { $argv += @('-CursorDir', ('"{0}"' -f $CursorDir)) }
    Write-Host '需要管理员权限（安装目录对普通用户只读），请在 UAC 弹窗里点「是」...'
    $p = Start-Process -FilePath 'powershell' -Verb RunAs -ArgumentList $argv -Wait -PassThru
    if (Test-Path -LiteralPath $logPath) {
        Get-Content -LiteralPath $logPath -Encoding UTF8 | ForEach-Object { Write-Host $_ }
    }
    if ($p.ExitCode -ne 0) { Write-Host "提权执行返回码 $($p.ExitCode)，可能被取消或失败。" }
    return
}

# 主流程（提权后的子进程把输出写进日志，父进程再读出来）
if (-not $NoElevate -and $Mode -ne 'Check' -and -not (Test-Admin)) {
    Invoke-Elevated
} else {
    if (-not (Test-Admin) -and $Mode -ne 'Check') {
        Write-Host '警告：当前不是管理员权限，写入很可能失败。'
    }
    $transcript = & {
        try { Invoke-Patch } catch {
            Write-Host "出错：$($_.Exception.Message)"
            Write-Host '如果提示「Permission denied / 拒绝访问」，说明需要管理员权限，请重新双击 bat。'
            return 1
        }
    } 6>&1
    $lines = @($transcript | ForEach-Object { "$_" })
    $lines | ForEach-Object { Write-Host $_ }
    if ($NoElevate) {
        # 被提权子进程调用时，落盘供父进程读取
        $lines | Set-Content -LiteralPath $logPath -Encoding UTF8
    }
}

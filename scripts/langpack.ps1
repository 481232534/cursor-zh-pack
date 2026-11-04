# Cursor 中文语言包 —— 安装 / 修复（不需要管理员权限）
# 做三件事：确保语言包扩展就位 → 写入合并版译文 → 重建 languagepacks.json 并清缓存
param(
    [string] $CursorDir
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$packDir = Join-Path $root '语言包'
$mergedSrc = Join-Path $packDir 'main.i18n.merged.json'
$localPack = Join-Path $packDir 'polang233.cursor-language-pack-1.1.1-universal'
$userHome = Join-Path $env:USERPROFILE '.cursor'
$extRoot = Join-Path $userHome 'extensions'
$extName = 'polang233.cursor-language-pack-1.1.1-universal'
$extDir = Join-Path $extRoot $extName
$lpFile = Join-Path $userHome 'languagepacks.json'
$argvFile = Join-Path $userHome 'argv.json'
$clpDir = Join-Path $env:APPDATA 'Cursor\clp'

function Write-Step($text) { Write-Host ""; Write-Host "== $text ==" }

Write-Step '1/4 检查语言包扩展'
if (Test-Path -LiteralPath (Join-Path $extDir 'package.json')) {
    Write-Host "  已存在：$extDir"
} else {
    $installed = $false
    # 先尝试用 Cursor 自带命令行从扩展市场安装（需要联网）
    $cli = $null
    if ($CursorDir) { $cli = Join-Path $CursorDir 'resources\app\bin\cursor.cmd' }
    if (-not $cli -or -not (Test-Path -LiteralPath $cli)) {
        try {
            $cmd = (Get-Item -LiteralPath 'Registry::HKEY_CLASSES_ROOT\cursor\shell\open\command').GetValue('')
            $m = [regex]::Match($cmd, '"([^"]+\.exe)"')
            if ($m.Success) { $cli = Join-Path (Split-Path -Parent $m.Groups[1].Value) 'resources\app\bin\cursor.cmd' }
        } catch { }
    }
    if ($cli -and (Test-Path -LiteralPath $cli)) {
        Write-Host "  尝试从扩展市场安装（需要联网）..."
        try {
            & $cli --install-extension polang233.cursor-language-pack 2>&1 | ForEach-Object { Write-Host "    $_" }
            if (Test-Path -LiteralPath (Join-Path $extDir 'package.json')) { $installed = $true }
        } catch { Write-Host "    CLI 安装失败：$($_.Exception.Message)" }
    }
    if (-not $installed) {
        # 回退：直接把包里自带的那份扩展拷进去
        if (Test-Path -LiteralPath (Join-Path $localPack 'package.json')) {
            Write-Host "  改为复制包内自带的扩展文件..."
            New-Item -ItemType Directory -Path $extDir -Force | Out-Null
            Copy-Item -LiteralPath $localPack -Destination $extRoot -Recurse -Force
            $installed = $true
        } else {
            throw '扩展未安装，且包内没有自带副本。请先联网安装：cursor --install-extension polang233.cursor-language-pack'
        }
    }
    Write-Host '  已就位'
}

Write-Step '2/4 写入合并版译文（24,197 条，比原版多 255 条、补回 185 条英文）'
$target = Join-Path $extDir 'translations\zh-cn\main.i18n.json'
if (-not (Test-Path -LiteralPath $mergedSrc)) { throw "包里缺少合并译文：$mergedSrc" }
if (Test-Path -LiteralPath $target) {
    $bak = $target + '.bak'
    if (-not (Test-Path -LiteralPath $bak)) { Copy-Item -LiteralPath $target -Destination $bak }
}
Copy-Item -LiteralPath $mergedSrc -Destination $target -Force
Write-Host "  已写入：$target（$((Get-Item -LiteralPath $target).Length) 字节）"

Write-Step '3/4 重建 languagepacks.json'
$zh = Join-Path $extDir 'translations\zh-cn'
$map = [ordered]@{}
$map['vscode'] = (Join-Path $zh 'main.i18n.json')
$extTr = Join-Path $zh 'extensions'
if (Test-Path -LiteralPath $extTr) {
    Get-ChildItem -LiteralPath $extTr -Filter '*.i18n.json' -File | ForEach-Object {
        $id = $_.Name -replace '\.i18n\.json$', ''
        $map[$id] = $_.FullName
    }
}
$lp = [ordered]@{ 'zh-cn' = [ordered]@{ 'translations' = $map; 'hash' = 'zh-cn-1.1.1' } }
$lp | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $lpFile -Encoding UTF8
Write-Host "  已写入 $($map.Count) 条映射 -> $lpFile"

Write-Step '4/4 设置启动语言并清缓存'
$argv = @{}
if (Test-Path -LiteralPath $argvFile) {
    try { $argv = Get-Content -LiteralPath $argvFile -Raw -Encoding UTF8 | ConvertFrom-Json -AsHashtable } catch { $argv = @{} }
}
$argv['locale'] = 'zh-cn'
$argv | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $argvFile -Encoding UTF8
Write-Host "  argv.json locale = zh-cn"

if (Test-Path -LiteralPath $clpDir) {
    Get-ChildItem -LiteralPath $clpDir -Directory | ForEach-Object {
        Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
    }
    Write-Host '  已清理语言包编译缓存（%APPDATA%\Cursor\clp）'
}

Write-Host ''
Write-Host '完成。请完全退出 Cursor 再重新打开，界面才会切换成中文。'

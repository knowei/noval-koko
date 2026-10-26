# Fetch public Legado book-source collections from GitHub (ASCII-only script;
# Chinese query terms are built from code points to dodge PS 5.1 ANSI decoding).
$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$outDir = Join-Path $PSScriptRoot 'scan_raw'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

# 书源 = U+4E66 U+6E90 | 阅读 = U+9605 U+8BFB | 小说 = U+5C0F U+8BF4
$SHUYUAN = [string][char]0x4E66 + [char]0x6E90
$YUEDU   = [string][char]0x9605 + [char]0x8BFB
$XIAOSHUO = [string][char]0x5C0F + [char]0x8BF4

$ghHeaders = @{
  'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'
  'Accept'     = 'application/vnd.github+json'
}

$queries = @(
  "legado $SHUYUAN",
  "$YUEDU $SHUYUAN",
  "$XIAOSHUO $SHUYUAN",
  "bookSource $YUEDU",
  'legado booksource',
  'yuedu source'
)

$repos = @{}
foreach ($q in $queries) {
  $enc = [Uri]::EscapeDataString($q)
  $url = "https://api.github.com/search/repositories?q=$enc&sort=updated&order=desc&per_page=15"
  try {
    $r = Invoke-RestMethod -Uri $url -Headers $ghHeaders -TimeoutSec 25
    foreach ($it in $r.items) {
      if (-not $repos.ContainsKey($it.full_name)) { $repos[$it.full_name] = $it.default_branch }
    }
    Write-Host "[search] ok total=$($r.total_count) got=$($r.items.Count)"
  } catch {
    Write-Host "[search] FAILED: $($_.Exception.Message.Split([char]10)[0])"
  }
  Start-Sleep -Seconds 2
}

Write-Host "[repos] unique=$($repos.Count)"
foreach ($name in $repos.Keys) { Write-Host "  repo: $name ($($repos[$name]))" }

$n = 0
foreach ($name in $repos.Keys) {
  $branch = $repos[$name]
  $treeUrl = "https://api.github.com/repos/$name/git/trees/$branch`?recursive=1"
  try { $tree = Invoke-RestMethod -Uri $treeUrl -Headers $ghHeaders -TimeoutSec 30 }
  catch { Write-Host "[tree] $name FAILED"; continue }

  $cands = @($tree.tree | Where-Object {
      $_.type -eq 'blob' -and $_.path -match '\.json$' -and
      $_.size -gt 800 -and $_.size -lt 4000000 -and
      $_.path -match 'source|Source|book|Book|json'
    })
  Write-Host "[tree] $name all=$(@($tree.tree).Count) cand=$($cands.Count)"
  foreach ($c in ($cands | Select-Object -First 8)) {
    $safe = ($name -replace '[/\\]', '_') + '__' + (($c.path -replace '[/\\]', '_'))
    $dest = Join-Path $outDir $safe
    if (Test-Path $dest) { continue }
    $rawUrl = "https://raw.githubusercontent.com/$name/$branch/$($c.path)"
    try {
      Invoke-WebRequest -Uri $rawUrl -OutFile $dest -Headers @{ 'User-Agent' = 'Mozilla/5.0' } -TimeoutSec 40
      Write-Host "  [get] $($c.path) $((Get-Item $dest).Length) B"
      $n++
    } catch {
      Write-Host "  [get] $($c.path) FAILED: $($_.Exception.Message.Split([char]10)[0])"
      if (Test-Path $dest) { Remove-Item $dest -Force }
    }
  }
  Start-Sleep -Seconds 1
}

Write-Host "[done] downloaded=$n files"

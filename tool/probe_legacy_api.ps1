$ErrorActionPreference = 'Continue'
$ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
$urls = @(
  "https://www.baozimh.com/api/v2/chapter/getinfo?m=133&c=1643598",
  "https://tw.baozimh.com/api/v2/chapter/getinfo?m=133&c=1643598",
  "https://cn.baozimh.com/api/v2/chapter/getinfo?m=133&c=1643598",
  "https://v2.apikk.top/api/v2/chapter/getinfo?m=133&c=1643598&plain=1",
  "https://api.apikk.top/api/v2/chapter/getinfo?m=133&c=1643598",
  "https://v2.apikk.top/api/v1/chapter/getinfo?m=133&c=1643598"
)
foreach ($u in $urls) {
  $out = "tool\_probe_" + ([guid]::NewGuid().ToString('N').Substring(0,6)) + ".txt"
  $code = curl.exe -sS -L --max-time 20 -A $ua -o $out -w "%{http_code}" $u 2>&1
  $len = if (Test-Path $out) { (Get-Item $out).Length } else { 0 }
  $head = if ($len -gt 0) { (Get-Content $out -Raw -Encoding UTF8).Substring(0, [Math]::Min(120, $len)) } else { '' }
  "$u`n  -> $code len=$len head=$head"
}

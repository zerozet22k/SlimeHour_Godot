# Boss benchmark: one headless Godot process per boss (Normal and Hard), all in
# parallel, then a summary table. Results: tools/benchmarks/
#   powershell -ExecutionPolicy Bypass -File tools/run_boss_benchmark.ps1 [-Trials 4] [-Mode both|normal|hard]
param([int]$Trials = 4, [string]$Mode = "both")
$root = Split-Path -Parent $PSScriptRoot
$godot = if ($env:GODOT) { $env:GODOT } else { Join-Path $root "Godot_v4.7.2-stable_win64_console.exe" }
if (-not (Test-Path $godot)) { Write-Host "Godot not found at $godot (set GODOT=path)"; exit 1 }
$outDir = Join-Path $root "tools/benchmarks"
New-Item -ItemType Directory -Force $outDir | Out-Null
$stamp = Get-Date -Format "yyyyMMdd-HHmm"
$bosses = "heli","chonkzilla","necro","kingblob","coilqueen","glassoracle","voidweaver","dreadengine","stormtitan","hiveempress"
$modes = switch ($Mode) { "normal" { @("0") } "hard" { @("1") } default { @("0","1") } }
$procs = @()
$parts = @()
foreach ($m in $modes) {
  foreach ($b in $bosses) {
    $part = Join-Path $outDir "part-$b-$m.csv"
    Remove-Item $part -ErrorAction SilentlyContinue
    $parts += $part
    $env:BENCH_BOSSES = $b; $env:BENCH_TRIALS = "$Trials"; $env:BENCH_HARD = $m; $env:BENCH_OUT = $part
    $procs += Start-Process -FilePath $godot -ArgumentList "--headless","--path",$root,"--script","res://tools/boss_benchmark.gd" -NoNewWindow -PassThru -RedirectStandardOutput (Join-Path $outDir "log-$b-$m.txt")
  }
}
Write-Host "Running $($procs.Count) benchmark bots ($Trials trials each)..."
# Live scoreboard while the bots fight: one line per boss and mode.
$names = @{heli="Sky Reaper";chonkzilla="Chonkzilla";necro="Grave Lord";kingblob="King Blob";coilqueen="Coil Queen";glassoracle="Glass Oracle";voidweaver="Void Weaver";dreadengine="Dread Engine";stormtitan="Storm Titan";hiveempress="Hive Empress"}
$start = Get-Date
while (($procs | Where-Object { -not $_.HasExited }).Count -gt 0) {
  Clear-Host
  $secs = [int]((Get-Date) - $start).TotalSeconds
  Write-Host ("  BOSS BENCHMARK   {0} bots fighting   {1}s" -f ($procs | Where-Object { -not $_.HasExited }).Count, $secs) -ForegroundColor Cyan
  Write-Host ""
  foreach ($m in $modes) {
    Write-Host ("  " + $(if ($m -eq "1") { "HARD" } else { "NORMAL" })) -ForegroundColor $(if ($m -eq "1") { "Red" } else { "Green" })
    foreach ($b in $bosses) {
      $part = Join-Path $outDir "part-$b-$m.csv"
      $done = @(); if (Test-Path $part) { $done = @(Import-Csv $part) }
      $line = "    {0,-13}" -f $names[$b]
      Write-Host -NoNewline $line
      foreach ($r in $done) {
        $extra = if ($r.hits) { " {0}h/{1}d" -f $r.hits, $r.dodges } else { "" }
        if ($r.killed -eq "1") { Write-Host -NoNewline (" WON {0,4}s{1} " -f [int][double]$r.seconds, $extra) -ForegroundColor Black -BackgroundColor Green }
        elseif ($r.died -eq "1") { Write-Host -NoNewline (" DIED {0,3}s{1} " -f [int][double]$r.seconds, $extra) -ForegroundColor White -BackgroundColor DarkRed }
        else { Write-Host -NoNewline " TIMEOUT " -ForegroundColor Black -BackgroundColor Yellow }
        Write-Host -NoNewline " "
      }
      for ($k = $done.Count; $k -lt $Trials; $k++) { Write-Host -NoNewline $(if ($k -eq $done.Count) { " fighting... " } else { " .......... " }) -ForegroundColor DarkGray; Write-Host -NoNewline " " }
      Write-Host ""
    }
    Write-Host ""
  }
  Start-Sleep -Seconds 2
}
$rows = @()
foreach ($p in $parts) { if (Test-Path $p) { $rows += Import-Csv $p } }
$all = Join-Path $outDir "boss_ttk-$stamp.csv"
$rows | Export-Csv -NoTypeInformation $all
$summary = $rows | Group-Object mode, boss | ForEach-Object {
  $g = $_.Group
  $secs = @($g | Where-Object { $_.killed -eq "1" } | ForEach-Object { [double]$_.seconds } | Sort-Object)
  $median = if ($secs.Count) { $secs[[int][math]::Floor($secs.Count / 2)] } else { "-" }
  [pscustomobject]@{
    Mode = $g[0].mode; Boss = $g[0].boss; Sector = [int]$g[0].sector
    "Kill s (median)" = $median
    "Kill s (min-max)" = if ($secs.Count) { "{0}-{1}" -f $secs[0], $secs[-1] } else { "-" }
    "Bots killed it" = "{0}/{1}" -f @($g | Where-Object { $_.killed -eq "1" }).Count, @($g).Count
    "Bots died" = "{0}/{1}" -f @($g | Where-Object { $_.died -eq "1" }).Count, @($g).Count
    "Avg HP lost %" = [math]::Round((($g | ForEach-Object { [double]$_.hp_lost_pct }) | Measure-Object -Average).Average)
    "Peak bullets" = (($g | ForEach-Object { [int]$_.peak_bullets }) | Measure-Object -Maximum).Maximum
    "Hits" = [math]::Round((($g | ForEach-Object { [double]$_.hits }) | Measure-Object -Average).Average)
    # Damage-free difficulty: how often the boss lands a hit. Many small hits = hard to dodge.
    "Hits/min" = [math]::Round((($g | ForEach-Object { [double]$_.hits / [math]::Max(1.0, [double]$_.seconds / 60.0) }) | Measure-Object -Average).Average, 1)
    "HP per hit %" = [math]::Round((($g | ForEach-Object { [double]$_.avg_hit_pct }) | Measure-Object -Average).Average, 1)
    "Dodges" = [math]::Round((($g | ForEach-Object { [double]$_.dodges }) | Measure-Object -Average).Average)
    "Dodge rate %" = [math]::Round((($g | ForEach-Object { [double]$_.dodge_rate }) | Measure-Object -Average).Average)
  }
} | Sort-Object Mode, Sector
# Hits/min next to Chonkzilla's, per mode: the dodge difficulty compared with the reference boss.
foreach ($row in $summary) {
  $ref = $summary | Where-Object { $_.Mode -eq $row.Mode -and $_.Boss -eq "chonkzilla" } | Select-Object -First 1
  $row | Add-Member -NotePropertyName "vs Chonkzilla" -NotePropertyValue $(if ($ref -and $ref."Hits/min" -gt 0) { "{0:N1}x" -f ($row."Hits/min" / $ref."Hits/min") } else { "-" })
}
$table = $summary | Format-Table -AutoSize | Out-String -Width 200
$table | Set-Content (Join-Path $outDir "summary-$stamp.txt")
Write-Host $table
Write-Host "Rows: $all"
Remove-Item $parts -ErrorAction SilentlyContinue

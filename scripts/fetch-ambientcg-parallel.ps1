# Parallel ambientCG mass fetch (resume-safe). Default 8 concurrent.
param(
  [int]$Count = 600,
  [int]$Parallel = 8,
  [string]$Repo = '$PSScriptRoot\..',
  [string]$Resolution = '1K-JPG'
)

$ErrorActionPreference = 'Continue'
$uaHeaders = @{ 'User-Agent' = 'Mozilla/5.0 JimmyTheHat-asset-lib/1.0 (CC0 parallel mirror)' }
$destRoot = Join-Path $Repo 'vendor\ambientcg'
$dl = 'C:\Users\hrmread\work\_asset-dl-ambientcg'
New-Item -ItemType Directory -Force -Path $destRoot, $dl | Out-Null

$have = [System.Collections.Concurrent.ConcurrentDictionary[string,byte]]::new()
Get-ChildItem $destRoot -Directory -EA SilentlyContinue | ForEach-Object { [void]$have.TryAdd($_.Name, 1) }
Write-Host "Already: $($have.Count) / target $Count parallel=$Parallel"

# Build work queue from popular API pages
$queue = New-Object System.Collections.Concurrent.ConcurrentQueue[object]
$offset = 0
while ($have.Count + $queue.Count -lt ($Count - $have.Count + 50) -or $queue.Count -lt [Math]::Max(0, $Count - $have.Count)) {
  if ($have.Count -ge $Count) { break }
  $api = "https://ambientCG.com/api/v3/assets?type=material&sort=popular&limit=100&offset=$offset&include=downloads,title"
  try { $page = Invoke-RestMethod -Uri $api -Headers $uaHeaders } catch { Start-Sleep 3; continue }
  if (-not $page.assets) { break }
  foreach ($a in $page.assets) {
    if ($have.ContainsKey($a.id)) { continue }
    $queue.Enqueue($a)
  }
  $offset += $page.assets.Count
  Write-Host "Queued $($queue.Count) (api offset=$offset have=$($have.Count))"
  if ($queue.Count -ge ($Count - $have.Count + 20)) { break }
  if ($page.assets.Count -lt 100) { break }
}

$need = $Count - $have.Count
Write-Host "Will attempt up to $need downloads from queue of $($queue.Count)"

$ok = [ref]0; $fail = [ref]0
$script:destRoot = $destRoot
$script:dl = $dl
$script:Resolution = $Resolution
$script:uaHeaders = $uaHeaders
$script:have = $have
$script:ok = $ok
$script:fail = $fail
$script:Count = $Count

$workers = 1..$Parallel | ForEach-Object {
  Start-Job -ScriptBlock {
    param($destRoot, $dl, $Resolution, $uaHeaders)
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $okLocal = 0; $failLocal = 0
    while ($true) {
      # queue drained via files? use shared queue file list
      break
    }
  } -ArgumentList $destRoot, $dl, $Resolution, $uaHeaders
}
# Job approach with ConcurrentQueue doesn't cross runspaces easily â€” use ForEach-Object -Parallel if PS7, else runspace pool

$issystem = $PSVersionTable.PSVersion.Major
Write-Host "PS major $issystem"

if ($issystem -ge 7) {
  $items = [System.Collections.Generic.List[object]]::new()
  $tmp = $null
  while ($queue.TryDequeue([ref]$tmp)) { $items.Add($tmp) }
  $items = $items | Select-Object -First $need
  $items | ForEach-Object -Parallel {
    $asset = $_
    $id = $asset.id
    $destRoot = $using:destRoot
    $dl = $using:dl
    $Resolution = $using:Resolution
    $folder = Join-Path $destRoot $id
    if ((Test-Path $folder) -and (Get-ChildItem $folder -Recurse -File -EA SilentlyContinue).Count -gt 0) { return }
    try {
      Add-Type -AssemblyName System.IO.Compression.FileSystem
      $dlInfo = $asset.downloads | Where-Object { $_.attributes -eq $Resolution } | Select-Object -First 1
      if (-not $dlInfo) { $dlInfo = $asset.downloads | Where-Object { $_.attributes -like '1K*' } | Select-Object -First 1 }
      if (-not $dlInfo) { throw 'no 1K' }
      $zip = Join-Path $dl "$id.zip"
      Invoke-WebRequest -Uri $dlInfo.url -OutFile $zip -UseBasicParsing -Headers @{ 'User-Agent' = 'Mozilla/5.0 asset-lib-parallel' }
      if (Test-Path $folder) { Remove-Item -Recurse -Force $folder }
      New-Item -ItemType Directory -Force -Path $folder | Out-Null
      [System.IO.Compression.ZipFile]::ExtractToDirectory($zip, $folder)
      Write-Output "OK $id"
    } catch {
      Write-Output "FAIL $id $($_.Exception.Message)"
    }
  } -ThrottleLimit $Parallel
} else {
  # Windows PowerShell 5.1 â€” runspace pool
  $pool = [runspacefactory]::CreateRunspacePool(1, $Parallel)
  $pool.Open()
  $runspaces = @()
  $downloaded = 0
  while ($downloaded -lt $need) {
    $asset = $null
    if (-not $queue.TryDequeue([ref]$asset)) { break }
    if ($have.ContainsKey($asset.id)) { continue }
    while (($runspaces | Where-Object { $_.Handle.IsCompleted -eq $false }).Count -ge $Parallel) {
      Start-Sleep -Milliseconds 200
      foreach ($rs in @($runspaces)) {
        if ($rs.Handle.IsCompleted) {
          $out = $rs.Pipe.EndInvoke($rs.Handle)
          $out | ForEach-Object { Write-Host $_ }
          if ($out -match '^OK ') { $ok.Value++; [void]$have.TryAdd(($out -replace '^OK ',''),1) }
          if ($out -match '^FAIL ') { $fail.Value++ }
          $rs.Pipe.Dispose()
          $runspaces = $runspaces | Where-Object { $_ -ne $rs }
        }
      }
    }
    $ps = [powershell]::Create().AddScript({
      param($asset, $destRoot, $dl, $Resolution)
      $id = $asset.id
      $folder = Join-Path $destRoot $id
      try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        if ((Test-Path $folder) -and (Get-ChildItem $folder -Recurse -File -EA SilentlyContinue).Count -gt 0) { return "OK $id" }
        $dlInfo = $asset.downloads | Where-Object { $_.attributes -eq $Resolution } | Select-Object -First 1
        if (-not $dlInfo) { $dlInfo = $asset.downloads | Where-Object { $_.attributes -like '1K*' } | Select-Object -First 1 }
        if (-not $dlInfo) { throw 'no 1K' }
        $zip = Join-Path $dl "$id.zip"
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add('User-Agent', 'Mozilla/5.0 asset-lib-parallel')
        $wc.DownloadFile($dlInfo.url, $zip)
        if (Test-Path $folder) { Remove-Item -Recurse -Force $folder }
        New-Item -ItemType Directory -Force -Path $folder | Out-Null
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zip, $folder)
        return "OK $id"
      } catch {
        return "FAIL $id $($_.Exception.Message)"
      }
    }).AddArgument($asset).AddArgument($destRoot).AddArgument($dl).AddArgument($Resolution)
    $ps.RunspacePool = $pool
    $runspaces += [pscustomobject]@{ Pipe = $ps; Handle = $ps.BeginInvoke() }
    $downloaded++
    if (($downloaded % 25) -eq 0) { Write-Host "Dispatched $downloaded / $need (active runspaces=$($runspaces.Count))" }
  }
  while ($runspaces.Count -gt 0) {
    Start-Sleep -Milliseconds 300
    foreach ($rs in @($runspaces)) {
      if ($rs.Handle.IsCompleted) {
        $out = $rs.Pipe.EndInvoke($rs.Handle)
        $out | ForEach-Object { Write-Host $_ }
        if ("$out" -match '^OK ') { $ok.Value++ }
        if ("$out" -match '^FAIL ') { $fail.Value++ }
        $rs.Pipe.Dispose()
        $runspaces = @($runspaces | Where-Object { $_ -ne $rs })
      }
    }
  }
  $pool.Close()
  Write-Host "DONE ok=$($ok.Value) fail=$($fail.Value) totalNow=$((Get-ChildItem $destRoot -Directory).Count)"
}


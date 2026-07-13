# Parallel Poly Haven full texture haul (1k), resume-safe.
param(
  [int]$Count = 9999,
  [int]$Parallel = 10,
  [string]$Repo = 'C:\Users\hrmread\work\game-visual-assets'
)

$ErrorActionPreference = 'Continue'
$ua = @{ 'User-Agent' = 'Mozilla/5.0 JimmyTheHat-asset-lib/1.0' }
$root = Join-Path $Repo 'vendor\polyhaven'
New-Item -ItemType Directory -Force -Path $root | Out-Null

$assets = Invoke-RestMethod -Uri 'https://api.polyhaven.com/assets?t=textures' -Headers $ua
$ranked = @($assets.PSObject.Properties | ForEach-Object {
  [pscustomobject]@{ Id = $_.Name; Downloads = [int]($_.Value.download_count) }
} | Sort-Object Downloads -Descending)
if ($Count -lt $ranked.Count) { $ranked = $ranked | Select-Object -First $Count }

$todo = @()
foreach ($row in $ranked) {
  $folder = Join-Path $root $row.Id
  $n = @(Get-ChildItem $folder -File -EA SilentlyContinue).Count
  if ($n -ge 2) { continue }
  $todo += $row.Id
}
Write-Host "Poly Haven remaining: $($todo.Count) / listed $($ranked.Count) parallel=$Parallel"

$mapKinds = @('Diffuse','nor_gl','Rough','AO')
$pool = [runspacefactory]::CreateRunspacePool(1, $Parallel)
$pool.Open()
$runspaces = @()
$ok = 0; $fail = 0; $i = 0

foreach ($id in $todo) {
  $i++
  while ((@($runspaces | Where-Object { -not $_.Handle.IsCompleted })).Count -ge $Parallel) {
    Start-Sleep -Milliseconds 150
    foreach ($rs in @($runspaces)) {
      if ($rs.Handle.IsCompleted) {
        $o = $rs.Pipe.EndInvoke($rs.Handle)
        Write-Host $o
        if ("$o" -match '^OK') { $ok++ } else { $fail++ }
        $rs.Pipe.Dispose()
        $runspaces = @($runspaces | Where-Object { $_ -ne $rs })
      }
    }
  }
  $ps = [powershell]::Create().AddScript({
    param($id, $root, $mapKinds)
    $folder = Join-Path $root $id
    try {
      New-Item -ItemType Directory -Force -Path $folder | Out-Null
      $wc = New-Object System.Net.WebClient
      $wc.Headers.Add('User-Agent', 'Mozilla/5.0 asset-lib-parallel')
      $json = $wc.DownloadString("https://api.polyhaven.com/files/$id")
      $files = $json | ConvertFrom-Json
      $got = 0
      foreach ($kind in $mapKinds) {
        $node = $files.$kind
        if (-not $node) { continue }
        $url = $null
        if ($node.'1k' -and $node.'1k'.jpg) { $url = $node.'1k'.jpg.url }
        elseif ($node.'1k' -and $node.'1k'.png) { $url = $node.'1k'.png.url }
        if (-not $url) { continue }
        $ext = [IO.Path]::GetExtension(([Uri]$url).AbsolutePath)
        $out = Join-Path $folder ("{0}_{1}_1k{2}" -f $id, $kind.ToLower(), $ext)
        if (-not (Test-Path $out)) { $wc.DownloadFile($url, $out) }
        $got++
      }
      if ($got -eq 0) { throw 'no maps' }
      return "OK $id maps=$got"
    } catch {
      return "FAIL $id $($_.Exception.Message)"
    }
  }).AddArgument($id).AddArgument($root).AddArgument($mapKinds)
  $ps.RunspacePool = $pool
  $runspaces += [pscustomobject]@{ Pipe = $ps; Handle = $ps.BeginInvoke() }
  if (($i % 40) -eq 0) { Write-Host "Dispatched $i/$($todo.Count) ok=$ok fail=$fail" }
}

while ($runspaces.Count -gt 0) {
  Start-Sleep -Milliseconds 200
  foreach ($rs in @($runspaces)) {
    if ($rs.Handle.IsCompleted) {
      $o = $rs.Pipe.EndInvoke($rs.Handle)
      Write-Host $o
      if ("$o" -match '^OK') { $ok++ } else { $fail++ }
      $rs.Pipe.Dispose()
      $runspaces = @($runspaces | Where-Object { $_ -ne $rs })
    }
  }
}
$pool.Close()
Write-Host "DONE ok=$ok fail=$fail totalDirs=$((Get-ChildItem $root -Directory).Count)"

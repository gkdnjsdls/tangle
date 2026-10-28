# Minimal static server for the docs/ folder, so the build can be opened over
# http://localhost — which counts as a secure context, so the service worker
# and "add to home screen" actually run. No node or python needed.

param([int]$Port = 8765)

$root = Join-Path $PSScriptRoot "docs"
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()
Write-Host "serving $root on http://localhost:$Port/"

$mime = @{
  ".html"        = "text/html; charset=utf-8"
  ".js"          = "text/javascript; charset=utf-8"
  ".css"         = "text/css; charset=utf-8"
  ".json"        = "application/json; charset=utf-8"
  ".webmanifest" = "application/manifest+json; charset=utf-8"
  ".png"         = "image/png"
}

while ($listener.IsListening) {
  $ctx = $listener.GetContext()
  try {
    $path = $ctx.Request.Url.LocalPath
    if ($path -eq "/") { $path = "/index.html" }
    $file = Join-Path $root ($path.TrimStart("/") -replace "/", "\")
    if (Test-Path -LiteralPath $file -PathType Leaf) {
      $bytes = [System.IO.File]::ReadAllBytes($file)
      $ext = [System.IO.Path]::GetExtension($file).ToLower()
      $ctx.Response.ContentType = $(if ($mime.ContainsKey($ext)) { $mime[$ext] } else { "application/octet-stream" })
      # the worker must never be served stale while iterating
      $ctx.Response.Headers.Add("Cache-Control", "no-store")
      $ctx.Response.ContentLength64 = $bytes.Length
      $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
      Write-Host ("200 " + $path)
    } else {
      $ctx.Response.StatusCode = 404
      Write-Host ("404 " + $path)
    }
  } catch {
    Write-Host ("ERR " + $_.Exception.Message)
  }
  $ctx.Response.Close()
}

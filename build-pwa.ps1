# Builds docs/index.html from fidget.html.
#
# The output lives in docs/ because GitHub Pages can serve a repository's /docs
# folder directly, which keeps the source and the deployed site in one repo.
#
# tangle.html is written for the Artifact platform, which wraps it in a document
# skeleton at publish time. A standalone host does not, so this adds the parts
# that skeleton supplied (doctype, head, charset/viewport, the small reset) plus
# the PWA bits, and drops the one meta that only means something to Artifacts.
#
# Run after any change to tangle.html:  .\build-pwa.ps1

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
# -Encoding UTF8 is not optional: Windows PowerShell otherwise reads the file in
# the system codepage and mangles every non-ASCII character, including the ones
# inside JS string literals, which turns into a syntax error at runtime.
$src = Get-Content -Raw -Encoding UTF8 (Join-Path $root "fidget.html")

# fidget.html is: <title>/<meta>/<link>/<script src>/<style> ... then markup.
$cut = $src.IndexOf("</style>")
if ($cut -lt 0) { throw "could not find </style> in fidget.html" }
$head = $src.Substring(0, $cut + 8)
$body = $src.Substring($cut + 8)

# Artifact-only hint; harmless but meaningless off-platform.
$head = $head -replace '(?m)^\s*<meta name="claude:viewport-fit-sides"[^>]*>\s*\r?\n', ''

$doc = @"
<!doctype html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover, user-scalable=no">
<meta name="theme-color" media="(prefers-color-scheme: light)" content="#e8e6e1">
<meta name="theme-color" media="(prefers-color-scheme: dark)" content="#16181d">
<meta name="mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
<meta name="apple-mobile-web-app-title" content="피젯">
<link rel="manifest" href="manifest.webmanifest">
<link rel="apple-touch-icon" href="icon-192.png">
<link rel="icon" type="image/png" sizes="512x512" href="icon-512.png">
<style>
  /* the reset the Artifact skeleton normally supplies */
  :root {
    color-scheme: light;
    padding-top: env(safe-area-inset-top, 0px);
    padding-bottom: env(safe-area-inset-bottom, 0px);
  }
  body { margin: 0; font: 14px system-ui, -apple-system, "Segoe UI", sans-serif; }
  img { max-width: 100%; }
  [hidden] { display: none !important; }
</style>
$head
</head>
<body>
$body

<script>
  // Installed copies run from the cache, so a reload alone will not pick up a
  // new build; the worker takes over as soon as it activates.
  if ("serviceWorker" in navigator) {
    window.addEventListener("load", function () {
      navigator.serviceWorker.register("sw.js").catch(function () {
        // no HTTPS, or the host forbids workers: the toy still runs online
      });
    });
  }
</script>
</body>
</html>
"@

$outDir = Join-Path $root "docs"
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
$outFile = Join-Path $outDir "index.html"

# UTF-8 without BOM: a BOM before <!doctype> drops some browsers into quirks mode
[System.IO.File]::WriteAllText($outFile, $doc, (New-Object System.Text.UTF8Encoding $false))

"built {0} ({1:N0} bytes)" -f $outFile, (Get-Item $outFile).Length

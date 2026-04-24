$content = Get-Content 'c:/Zhiyaun/TempRelease/r/Zhiyuan-build/ZhiyuanLauncherSettings.ini' -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
if (-not $content) {
    Write-Host "File not found, trying from 7z..."
    # Extract from 7z first
    & "C:/Program Files/7-Zip/7z.exe" e -o"c:/Zhiyaun/tmp_test" c:/Zhiyaun/releases/Zhiyuan-v1.0.0.7z "r/Zhiyuan-build/ZhiyuanLauncherSettings.ini" -y | Out-Null
    $content = Get-Content 'c:/Zhiyaun/tmp_test/ZhiyuanLauncherSettings.ini' -Raw -Encoding UTF8
}

$key = 'SLICER_HOME=C:/Zhiyaun/r/Zhiyuan-build'
$escaped = [regex]::Escape($key)
Write-Host "Key: $key"
Write-Host "Escaped: $escaped"

if ($content -match $escaped) {
    Write-Host "MATCHED"
    $result = $content -replace $escaped, 'SLICER_HOME=<APPLAUNCHER_SETTINGS_DIR>'
    if ($result -match 'SLICER_HOME=<APPLAUNCHER_SETTINGS_DIR>') {
        Write-Host "REPLACE WORKS"
    }
} else {
    Write-Host "NOT MATCHED"
    # Show nearby lines
    $lines = $content -split "`r?`n"
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match 'SLICER_HOME') {
            Write-Host "Line $($i+1): [$($lines[$i])]"
        }
    }
}

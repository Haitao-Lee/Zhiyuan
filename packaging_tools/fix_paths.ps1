$iniFiles = Get-ChildItem -Path 'c:/Zhiyaun/TempRelease/r/Zhiyuan-build' -Recurse -Filter '*LauncherSettings*.ini' -File
foreach ($file in $iniFiles) {
    $content = Get-Content $file.FullName -Raw -Encoding UTF8
    $orig = $content
    $content = $content -replace [regex]::Escape('C:/Zhiyaun/r/CTK-build/CTK-build/bin'), '<APPLAUNCHER_SETTINGS_DIR>/bin/Release'
    $content = $content -replace [regex]::Escape('C:/LHT_workspace/code/Qt5.15/5.15.2/msvc2019_64/plugins'), '<APPLAUNCHER_SETTINGS_DIR>/lib/QtPlugins'
    $content = $content -replace [regex]::Escape('C:/Zhiyaun/r/VTK-build/lib/site-packages'), '<APPLAUNCHER_SETTINGS_DIR>/lib/Python/Lib/site-packages'
    $content = $content -replace [regex]::Escape('C:/Zhiyaun/r/CTK-build/CTK-build/bin/Python'), '<APPLAUNCHER_SETTINGS_DIR>/lib/Python/Lib'
    $content = $content -replace [regex]::Escape('SLICER_HOME=C:/Zhiyaun/r/Zhiyuan-build'), 'SLICER_HOME=<APPLAUNCHER_SETTINGS_DIR>'
    if ($content -ne $orig) {
        Set-Content -Path $file.FullName -Value $content -Encoding UTF8
        Write-Host ('Patched: ' + $file.FullName)
    }
}

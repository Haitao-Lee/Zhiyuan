$InnoSetupPath = "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
$issFile = "c:\Zhiyaun\packaging_tools\Zhiyuan_Setup.iss"
$ReleaseDir = "c:\Zhiyaun\releases"
$Version = "1.0.4"

$tempIss = Join-Path "c:\Zhiyaun" "Zhiyuan_Setup_temp.iss"
$issContent = Get-Content $issFile -Raw -Encoding UTF8

# Replace placeholder with actual total size (optional)
$issContent = $issContent.Replace("0000000000", "3800000000")

Set-Content -Path $tempIss -Value $issContent -Encoding UTF8

Write-Host "Compiling Inno Setup script..."
$argList = "`"$tempIss`" /O`"$ReleaseDir`" /DMyAppVersion=`"$Version`""
Write-Host "Arguments: $argList"

$process = Start-Process -FilePath $InnoSetupPath `
    -ArgumentList $argList `
    -WorkingDirectory "c:\Zhiyaun\packaging_tools" `
    -PassThru -NoNewWindow -Wait

Remove-Item $tempIss -Force -ErrorAction SilentlyContinue

if ($process.ExitCode -ne 0) {
    Write-Error "Inno Setup compilation failed (exit code: $($process.ExitCode))"
    exit 1
}

Write-Host "Installer compiled successfully"

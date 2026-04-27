# This reads in the input file then creates a self extracting powerhsell file with the file encoded into it in base64. This can be pushed out with intune

# Input file to encode
param (
    [string]$InputFile = "Path to input file here"
)

if (-not (Test-Path $InputFile)) {
    Write-Host "Error: File '$InputFile' does not exist!" -ForegroundColor Red
    exit 1
}

# Determine the output script name based on the input file
$outputScript = "{0}.ps1" -f ([System.IO.Path]::GetFileNameWithoutExtension($InputFile))

# Read the file and encode it to Base64
$fileContent = [System.IO.File]::ReadAllBytes($InputFile)
$base64Encoded = [Convert]::ToBase64String($fileContent)

$extractionScript = @"

# Extraction Script
param (
    # Set the extraction path here, the home variable in powershell is the users profile path
    [string]`$OutputPath = `$home + "\subdirectory\of\choice"
)
`n
"@

#Insert the filename variable
$extractionScript += "`$OriginalName = `"" + ([System.IO.Path]::GetFileName($InputFile)) + "`"`n`n"

# Create the extraction script and put base64 at start
$extractionScript += "`$base64Content = `"" + $base64Encoded + "`"" + "`n"

# Append the rest of the script
$extractionScript += @"

if (-not `$OutputPath) {
    Write-Host "No path provided. Extracting to current directory..." -ForegroundColor Yellow
    `$OutputPath = ".\" + `$OriginalName
} else {
    `$OutputPath = `$OutputPath + "\" + `$OriginalName
}

# Decode and write the file
try {
    Write-Host "Writing file to `$OutputPath ..." -ForegroundColor Green
    `$fileBytes = [Convert]::FromBase64String(`$base64Content)
    [System.IO.File]::WriteAllBytes(`$OutputPath, `$fileBytes)
    Write-Host "File successfully extracted to `$OutputPath" -ForegroundColor Cyan
} catch {
    Write-Host "Error: Failed to write file to `$OutputPath. `$_" -ForegroundColor Red
}
`n
"@

# Write the extraction script to the output file
Set-Content -Path $outputScript -Value $extractionScript -Encoding UTF8

Write-Host "Extraction script created successfully: $outputScript" -ForegroundColor Green

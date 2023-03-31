
$BackupPath = ""
$Timestamp = Get-Date -Format "dd-MM-yyyy"
$BackupFolder=Join-Path $BackupPath "\$timestamp"

if(!(Test-Path $BackupFolder -ErrorAction SilentlyContinue))
{
    # Create backup directory if it doesn't exist
    New-Item -ItemType Directory -Force -Path $BackupFolder
}
else 
{
    "Directory $backupfolder already exists."
}

#Use this variable to filter the task sequence based on name.
$namefilter='Prod - '

# List all task sequences
if($filter -ne "")
{
    $AllTaskSequences=Get-CMTaskSequence -Fast | Where-Object { $_.name -match $namefilter} | Select-Object name,packageid
}
else 
{
    $AllTaskSequences=Get-CMTaskSequence -Fast | Select-Object name,packageid
}

# Export the task sequences to location mentioned
$AllTaskSequences | ForEach-Object { 
    "Exporting Task Sequence $($_.name)-$($_.packageid)"
    Export-CMTaskSequence -TaskSequencePackageId $_.packageid -ExportFilePath "$BackupFolder\$($_.name).zip" -WithContent $false -WithDependence $false
}

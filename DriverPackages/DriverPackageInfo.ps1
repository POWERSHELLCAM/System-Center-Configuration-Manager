function InitializeSCCM 
{ 
$ProcessMessage="`n Please wait.Initializing SCCM ......" 
 
# Site configuration 
write-host "`n Enter Site Code : " -foregroundcolor $inputcolor -nonewline 
$SiteCode = read-host 
write-host "`n Enter SMS Provider Server Name : " -foregroundcolor $inputcolor -nonewline 
$ProviderMachineName = read-host  
iex $ProcessColor 
sleep 2 
# Customizations 
$initParams = @{} 
 
# Import the ConfigurationManager.psd1 module  
if((Get-Module ConfigurationManager) -eq $null) { 
    Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" @initParams  
} 
 
# Connect to the site's drive if it is not already present 
if((Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -eq $null) { 
    New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $ProviderMachineName @initParams 
} 
 
# Set the current location to be the site code. 
Set-Location "$($SiteCode):\" @initParams 
} 
 
function deinitializeSCCM 
{ 
$ProcessMessage="`n Please wait.De-Initializing SCCM ......" 
iex $ProcessColor 
Start-Sleep 2 
set-location $location 
} 

#--Variable declaration
 clear
 $location=get-location 
 $InputColor="magenta" 
 $FileName
 $ProcessColor="write-host `$ProcessMessage -ForegroundColor gray -BackgroundColor darkgreen" 
 $invalidChars = [IO.Path]::GetInvalidFileNameChars() -join ''
 $re = "[{0}]" -f [RegEx]::Escape($invalidChars)
#--CSS formatting
$test=@'
<style type="text/css">
 h1, h5,h2, th { text-align: left; font-family: Segoe UI;font-size: 13px;}
table { margin: left; font-family: Segoe UI; box-shadow: 10px 10px 5px #888; border: thin ridge grey; }
th { background: #0046c3; color: #fff; max-width: 400px; padding: 5px 10px; font-size: 12px;}
td { font-size: 11px; padding: 5px 20px; color: #000; }
tr { background: #b8d1f3; }
tr:nth-child(even) { background: #dae5f4; }
tr:nth-child(odd) { background: #b8d1f3; }
</style>
'@

 InitializeSCCM 

 #Get the information about the driver packages.
 $DrivePKGList= Get-CMDriverPackage -fast | Select-Object Name,PackageId,PkgSourcePath,Description,DriverManufacturer,DriverModel,DriverOSVersion,DriverPkgVersion,LastRefreshTime,Manufacturer,ObjectPath,SourceDate
 write-host "`n Enter DrivePackage export path: " -foregroundcolor $inputcolor -nonewline 
 $driverPackageInfoExportPath=read-host
 $REPORT_TITLE="SCCM Driver Package Information"
 $REPORT_PATH=$driverPackageInfoExportPath+"\$REPORT_TITLE.html"

 #Get the Driver information from each driver package and export in .txt file
 ConvertTo-Html -Head $test -Title $REPORT_TITLE -Body "<h1>$REPORT_TITLE</h1>" >  "$REPORT_PATH"
 foreach($x in $DrivePKGList)
    {
        write-host "Exporting driver pack $($x.name) having packageid as $($x.packageid)"
        $FileName=[string]$x.packageid+" - "+ [string]$x.name 
        $filename = $FileName -replace $re
		$path=([string]$driverPackageInfoExportPath+"\"+[string]$FileName+[string]".txt")
		Get-CMDriver -DriverPackageId $($x.packageid) -fast | Select-Object CI_ID,DriverDate,DriverINFFile,DriverVersion,LocalizedDisplayName | Format-Table -AutoSize -Wrap | Out-File -FilePath $path
    }

#De-initializing SCCM 
deinitializeSCCM 

$DrivePKGList | ConvertTo-Html -head $test | Out-File $REPORT_PATH
 
#Launching HTML generated report 
write-host "`n Opening $REPORT_PATH report. `n"  -nonewline 
Invoke-Item $REPORT_PATH
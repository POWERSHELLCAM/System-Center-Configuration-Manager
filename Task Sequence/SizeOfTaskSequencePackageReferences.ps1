#Created by SHISHIR KUSHAWAHA [srktcet@gmail.com] 
 
function InitializeSCCM  
{  
$ProcessMessage="`n Please wait.Initializing SCCM ......"  
  
# Site configuration  
write-host "`n Enter Site Code : " -foregroundcolor $inputcolor -nonewline  
$SiteCode = read-host  
write-host "`n Enter SMS Provider Server Name : " -foregroundcolor $inputcolor -nonewline  
$ProviderMachineName = read-host   
Invoke-Expression $ProcessColor  
Start-Sleep 2  
# Customizations  
$initParams = @{}  
  
# Import the ConfigurationManager.psd1 module   
if($null -eq (Get-Module ConfigurationManager)) {  
    Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" @initParams   
}  
  
# Connect to the site's drive if it is not already present  
if($null -eq (Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue)) {  
    New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $ProviderMachineName @initParams  
}  
  
# Set the current location to be the site code.  
Set-Location "$($SiteCode):\" @initParams  
}  
  
function deinitializeSCCM  
{  
$ProcessMessage="`n Please wait.De-Initializing SCCM ......"  
Invoke-Expression $ProcessColor  
Start-Sleep 2  
set-location $location  
}  
function updateHTML 
{ 
 
param ($strPath) 
IF(Test-Path $strPath) 
  {  
   Remove-Item $strPath 
    
  } 
 
 } 
  
#--CSS formatting 
$test=@' 
<mce:style type="text/css"><!-- 
 h1, h5,h2, th { text-align: left; font-family: Segoe UI;font-size: 13px;} 
table { margin: left; font-family: Segoe UI; box-shadow: 10px 10px 5px #888; border: thin ridge grey; } 
th { background: #0046c3; color: #fff; max-width: 400px; padding: 5px 10px; font-size: 12px;} 
td { font-size: 11px; padding: 5px 20px; color: #000; } 
tr { background: #b8d1f3; } 
tr:nth-child(even) { background: #dae5f4; } 
tr:nth-child(odd) { background: #b8d1f3; } 
--></mce:style><style type="text/css" _mce_bogus="1"><!-- 
 h1, h5,h2, th { text-align: left; font-family: Segoe UI;font-size: 13px;} 
table { margin: left; font-family: Segoe UI; box-shadow: 10px 10px 5px #888; border: thin ridge grey; } 
th { background: #0046c3; color: #fff; max-width: 400px; padding: 5px 10px; font-size: 12px;} 
td { font-size: 11px; padding: 5px 20px; color: #000; } 
tr { background: #b8d1f3; } 
tr:nth-child(even) { background: #dae5f4; } 
tr:nth-child(odd) { background: #b8d1f3; } 
--></style> 
'@ 
 
 
 #variable declaration  
$location=get-location  
$InputColor="magenta"  
$ProcessColor="write-host `$ProcessMessage -ForegroundColor gray -BackgroundColor darkgreen"  
$ReportTitle="Task Sequence Packages and total Size"  
$strPath = "$location\$ReportTitle.html"  
$totalSize=$null 
$packageSum=0 
$applicationSum=0 
$driverSum=0 
$osSum=0 
 
updateHTML $strPath 
InitializeSCCM  
write-host "`n Enter task sequence packageID : " -foregroundcolor $inputcolor -nonewline  
$taskSequencePackageID=read-host  
 
write-host "`n Processing all packages which are integrated in $taskSequencePackageID.Please wait for 2-3 min" -ForegroundColor gray -BackgroundColor darkgreen  
 
#Task Sequence Information 
$taskSequenceResult=Get-CMTaskSequence -TaskSequencePackageId $taskSequencePackageID 
ConvertTo-Html -Head $test -Title $ReportTitle -Body "<h1> Windows 10 $ReportTitle </h1>" >  "$strPath"  
$taskSequenceResult |Select-Object Name,BootImageID,Description,PackageId,LastRefreshTime,Sourcedate| ConvertTo-html  -Head $test -Body "<h2>Task Sequence $taskSequencePackageID Information</h2>" >> "$strPath" 
 
 
 
#Calculating size of BootImage  
$bootImagePackageID=$taskSequenceResult.bootimageid 
$bootImageResult=Get-CMBootImage -id $bootImagePackageID 
$bootImageResult|Select-Object Name,PackageId,PackageSize| ConvertTo-html  -Head $test -Body "<h2>Boot Image $bootImagePackageID Information</h2>" >> "$strPath" 
$bootImageSize=$bootImageResult.packagesize 
$totalSize=$totalsize+$bootImageSize 
 
 
 
#Array declaration for Package,Application,OS and driver packages 
$taskSequencePackages=$taskSequenceResult.references.package 
$taskSequencePackageResult=New-Object System.Collections.ArrayList 
$taskSequenceApplicationResult=New-Object System.Collections.ArrayList 
$taskSequenceOSResult=New-Object System.Collections.ArrayList 
$taskSequenceDriverPackageResult=New-Object System.Collections.ArrayList 
 
#Calculating the size of each package 
foreach($tPid in $taskSequencePackages) 
    { 
        $packageResult=Get-CMPackage -id  $tPid -fast| Select-Object Name , PackageID,PackageSize 
        $packageSum=$packageSum+($packageResult.packagesize) 
        $pkgref=Get-CMApplication -modelname  $tPid | Select-Object LocalizedDisplayName , PackageID,PackageSize 
        $apppkgid=$pkgref.packageid 
        $ApplicationResult=Get-WmiObject -ComputerName $ProviderMachineName -namespace root\sms\site_$SiteCode -Query "SELECT * from sms_contentpackage where packageid = '$apppkgid'" | Select-Object Name,PackageID,PackageSize 
        $applicationSum=$applicationSum+($ApplicationResult.packagesize) 
        $OSResult=Get-cmoperatingsystemimage -id $tPid | Select-Object Name,PackageID,PackageSize 
        $osSum=$osSum+($OSResult.packagesize) 
        $DriverPackageResult=Get-cmdriverpackage -id $tPid -fast | Select-Object Name,PackageID,PackageSize 
        $driverSum=$driverSum+($DriverPackageResult.packagesize) 
        [void]$taskSequencePackageResult.add($packageResult) 
        [void]$taskSequenceApplicationResult.add($applicationResult) 
        [void]$taskSequenceOSResult.add($OSResult) 
        [void]$taskSequenceDriverPackageResult.add($DriverPackageResult) 
    } 
 
#Calculating total size 
$totalSize=$bootImageSize+$packageSum+$applicationSum+$driverSum+$osSum 
$totalSizeResult = @{'OSImage' = "$osSum"; 'Package' = "$packageSum"; 'Application' = "$applicationSum"; 'Driver Package' = "$driverSum"; 'Boot Image'="$bootImageSize"; 'Total Size'="$totalSize"} 
 
#Exporting result to HTML page 
$taskSequencePackageResult | ConvertTo-html  -Head $test -Body "<h2>Integrated Packages </h2>" >> "$strPath" 
$taskSequenceApplicationResult | ConvertTo-html  -Head $test -Body "<h2>Integrated Applications </h2>" >> "$strPath" 
$taskSequenceOSResult | ConvertTo-html  -Head $test -Body "<h2>Integrated Operating System </h2>" >> "$strPath" 
$taskSequenceDriverPackageresult | ConvertTo-html  -Head $test -Body "<h2>Integrated Driver Packages </h2>" >> "$strPath" 
$totalSizeResult.GetEnumerator()| ConvertTo-html  -Head $test -Body "<h2>Size Summary </h2>" >> "$strPath" 
if ($totalsize -le 1000) 
            { 
                ConvertTo-html  -Head $test -Body "<h2> Total Size: $(($totalsize).ToString(".00")) KB </h2>" >> "$strPath" 
                 
            } 
        elseif ($totalsize -gt 1000 -and $totalsize -le 1000000) 
            { 
                ConvertTo-html  -Head $test -Body "<h2>Total Size: $(($totalsize / 1KB).ToString(".00")) MB </h2>" >> "$strPath" 
                 
            } 
        else 
            { 
                ConvertTo-html  -Head $test -Body "<h2>Total Size: $(($totalsize / 1MB).ToString(".00")) GB </h2>" >> "$strPath" 
            } 
     
 
#De-initializing SCCM  
deinitializeSCCM  
  
#Launching HTML generated report  
write-host "`n Openning $strpath report : " -foregroundcolor $inputcolor -nonewline  
Invoke-Item $strPath 

function InitializeSCCM 
{ 
    $ProcessMessage="`n Please wait.Initializing SCCM ........." 
    
    # Site configuration
    do
    { 
        write-host "`n Enter Site Code : " -foregroundcolor $inputcolor -nonewline 
        $SiteCode = read-host 
        $siteResult=($siteCode -match '\b^[a-zA-Z0-9]{3}\b')
        if(!$siteResult)
        {
        write-host " Site code can have only [3] alphanumeric characters. Please re-enter site code" -foregroundcolor RED
        }
    }while(!$siteResult)

    do
    {
        write-host "`n Enter SMS Provider Server Name : " -foregroundcolor $inputcolor -nonewline 
        $ProviderMachineName = read-host 
        $nameResult=($ProviderMachineName -match '\b^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])$\b')
        if(!$nameResult)
        {
        write-host " Entered SMS provider name is not valid as per naming conventions. Please re-enter provider name" -foregroundcolor RED
        }
    }while(!$nameResult)

    Invoke-Expression $ProcessColor 
    Start-Sleep 2 
    # Customizations 
    $initParams = @{} 
    
    # Import the ConfigurationManager.psd1 module  
    if($null -eq (Get-Module ConfigurationManager)) 
    { 
        Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" @initParams  
    } 
    
    # Connect to the site's drive if it is not already present 
    if($null -eq (Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue)) 
    { 
        New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $ProviderMachineName @initParams 
    } 
    
    # Set the current location to be the site code. 
    Set-Location "$($SiteCode):\" @initParams 
} 
 
function deinitializeSCCM 
{
    #De-initialize SCCM
	$ProcessMessage="`n Please wait.De-Initializing SCCM ......" 
	Invoke-Expression $ProcessColor 
	Start-Sleep 2 
	set-location $location 
} 
function updateHTML
{
    param ($strPath)
    if(Test-Path $strPath)
    { 
        #Delete .HTML file if already exists
        Remove-Item $strPath
    }
}
 
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

#--Variable declaration
Clear-Host
$location=get-location 
$InputColor="yellow" 
$unusedDrivers=$null
$usedDrivers=@()
$unusedDrivers=@()
$ProcessColor="write-host `$ProcessMessage -ForegroundColor gray -BackgroundColor darkgreen" 
$ReportTitle="MECM UNUSED DRIVERS"
$strPath = "$location\$ReportTitle.html" 
updateHTML $strPath

ConvertTo-Html -Head $test -Title $ReportTitle -Body "<h1> MECM UNUSED DRIVERS </h1>" >  "$strPath"
InitializeSCCM 
write-host "Getting all drivers Information" -foregroundcolor $inputcolor
#list of all drivers
$drivers= get-cmdriver -fast | Select-Object ci_id,LocalizedDisplayName, ContentSourcePath

$driverIDs= $drivers.ci_id

#list of driver packages
write-host "Getting driver package Information" -foregroundcolor $inputcolor
$driverpackageid=Get-CMDriverPackage -Fast | Select-Object packageid

write-host "Getting list of boot image drivers information" -foregroundcolor $inputcolor
#list of drivers integrated in boot image
$bootimageDriversIDs=(Get-CMBootImage | Select-Object -ExpandProperty ReferencedDrivers).id

write-host "Getting list of driver package drivers information" -foregroundcolor $inputcolor
#list drivers from all driver packages
foreach($pkgid in $driverpackageid)
{
    write-host "Checking driver package $($pkgid.packageid)."
    $usedDrivers+=(Get-CMDriver -Fast -DriverPackageId $($pkgid.packageid)).ci_id
}

write-host "Processing to get the list of unused drivers." -foregroundcolor $inputcolor
#Add boot image drivers in driver packages drivers
$usedDrivers+=$bootimageDriversIDs

#Remove duplicate drivers from the list
$usedDrivers=$usedDrivers | Select-Object -Unique

#Subtract used drivers from all drivers to get the list if unused drivers
$drivers | ForEach-Object {if($_.ci_id -notin $usedDrivers){$unusedDrivers+=$_}}

# Delete drivers. Comment below line if you wish to delete later
$unusedDrivers | ForEach-Object { "deleting $($_.ci_id), $($_.contentsourcepath)" ; remove-cmdriver -id $_.ci_id -Force}

#De-initializing SCCM 
deinitializeSCCM 
ConvertTo-Html -Head $test -Title $ReportTitle -Body "<h2> Total drivers in entire site : $($drivers.count) <br> Total unused drivers : $($unusedDrivers.count)</h2>" >  "$strPath"
$unusedDrivers | ConvertTo-html  -Head $test -Body "<h2>Driver Details</h2>" >> "$strPath"
#Launching HTML generated report 
write-host "`n Opening $strpath report. `n" -foregroundcolor $inputcolor -nonewline 
Invoke-Item $strPath

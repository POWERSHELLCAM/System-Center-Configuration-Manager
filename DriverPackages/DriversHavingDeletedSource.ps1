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
 $ProcessColor="write-host `$ProcessMessage -ForegroundColor gray -BackgroundColor darkgreen" 
 $ReportTitle="DRIVERS WITH NO DATA SOURCE"
 $strPath = "$location\$ReportTitle.html" 
 
 updateHTML $strPath


ConvertTo-Html -Head $test -Title $ReportTitle -Body "<h1> DRIVER WITH NO DATA SOURCE </h1>" >  "$strPath"
InitializeSCCM 
write-host "Getting Driver Information" -foregroundcolor $inputcolor
$driverInfo=Get-CMDriver -fast | Select-Object CI_ID,LocalizedDisplayName,CONTENTSOURCEPATH
#De-initializing SCCM 
deinitializeSCCM 
write-host "Processing data to get drivers with no data source" -foregroundcolor $inputcolor
$result = @()
$i=0
foreach($c in $driverInfo)
{
    $r=$true
    $e=$null
    $($c.CONTENTSOURCEPATH)
    $r=Test-Path -LiteralPath "$($c.CONTENTSOURCEPATH)" -ErrorVariable e
    if($e.count -eq 0)
    {
        $m="Path does not exist"
    }
    else
    {
        $m=$($e -split '`n')
    }
    if($r -eq $false)
    {
        $property=$null
        $property=$c |Select-Object ci_id,LocalizedDisplayName,CONTENTSOURCEPATH
        $newProperty = [ordered]@{}
        $newProperty."SrNo" = $i+1
        $newProperty."CI_ID" = $property.ci_id
        $newProperty."Name" = $property.LocalizedDisplayName
        $newProperty."SourcePath" = $property.CONTENTSOURCEPATH
        $newProperty."Result" = $m
        $Objectname = New-Object PSobject -Property $newProperty
        $result += $Objectname
        $i++
    }
}
$count=$driverInfo.count
ConvertTo-Html -Head $test -Title $ReportTitle -Body "<h2> Total drivers in entire site : $count </h2>" >  "$strPath"
ConvertTo-Html -Head $test -Title $ReportTitle -Body "<h2> Total drivers having no data source in entire site : $i </h2>" >  "$strPath"
$result | ConvertTo-html  -Head $test -Body "<h2>Driver Details</h2>" >> "$strPath"
#Launching HTML generated report 
write-host "`n Opening $strpath report. `n" -foregroundcolor $inputcolor -nonewline 
Invoke-Item $strPath

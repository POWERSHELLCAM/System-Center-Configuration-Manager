# ######################################################################
#
# 	Program         :   TASK_SEQUENCE_DETAILS.ps1
# 	Version         :   1.1
# 	Purpose         :   List of packages distributed to n amount of Distribution Point
# 	Author          :	Shishir Kushawaha
#	Mail Id         :   srktcet@gmail.com
#   Created         :   05-10-2018 - Script creation.
# 	Modified        :	
# ######################################################################

<# Objective:
	The purpose of this script is to list out the packages which are distributed to 'n' no of distribution point.
#>

<# How to execute:
	Ensure you have SCCM management point reachable and have access. 
	Directly run the script with Administrative previlage.
#>

<# Execution:
	Provide the site code and management point information. 
	Next it will ask for no of distribution point.
	Once done, it will connect to SCCM and list all packages which are distributed to no of distribution point or less than of that.

	There is a variable which is to specify the .HTML store location as $Location. It can be modified as per the requirement.
#>
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
sleep 2
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
#variable declaration
$location=get-location
$InputColor="magenta"
$ProcessColor="write-host `$ProcessMessage -ForegroundColor gray -BackgroundColor darkgreen"
$ReportTitle="Package and Their Distribution Status of all packages"
$strPath = "$location\$ReportTitle.html"

#Initialize SCCM and input information
updateHTML $strPath
InitializeSCCM
write-host "`n Enter no of Distribution Point : " -foregroundcolor $inputcolor -nonewline
$noOfDP=read-host


write-host "`n Processing all packages which are distributed to less than equal to $noOfDP distribution points. Please wait for 2-3 min" -ForegroundColor gray -BackgroundColor darkgreen


ConvertTo-Html -Head $test -Title $ReportTitle -Body "<h1>  $ReportTitle </h1>" >  "$strPath" 
Get-CMDistributionStatus | ? { ($_.objecttype -eq 0) -and ($_.targeted -le $noOfDP)} | Select PackageID,SoftwareName,SourceSize,DateCreated,LastUpdateDate,Targeted | ConvertTo-html  -Head $test -Body "<h2>Packages distributed to less than or equal to $noOfDP Distribution Points</h2>" >> "$strPath"
Get-CMDistributionStatus | ? { ($_.objecttype -eq 3) -and ($_.targeted -le $noOfDP)} | Select PackageID,SoftwareName,SourceSize,DateCreated,LastUpdateDate ,Targeted| ConvertTo-html  -Head $test -Body "<h2>Driver Packages distributed to less than or equal to $noOfDP Distribution Points</h2>" >> "$strPath"
Get-CMDistributionStatus | ? { ($_.objecttype -eq 257) -and ($_.targeted -le $noOfDP)} | Select PackageID,SoftwareName,SourceSize,DateCreated,LastUpdateDate,Targeted | ConvertTo-html  -Head $test -Body "<h2>Operating System Images distributed to less than or equal to $noOfDP Distribution Points</h2>" >> "$strPath"
Get-CMDistributionStatus | ? { ($_.objecttype -eq 258) -and ($_.targeted -le $noOfDP)} | Select PackageID,SoftwareName,SourceSize,DateCreated,LastUpdateDate ,Targeted| ConvertTo-html  -Head $test -Body "<h2>Boot Images distributed to less than or equal to $noOfDP Distribution Points</h2>" >> "$strPath"
Get-CMDistributionStatus | ? { ($_.objecttype -eq 512) -and ($_.targeted -le $noOfDP)} | Select PackageID,SoftwareName,SourceSize,DateCreated,LastUpdateDate,Targeted | ConvertTo-html  -Head $test -Body "<h2>Applications distributed to less than or equal to $noOfDP Distribution Points</h2>" >> "$strPath"
Get-CMDistributionStatus | ? { ($_.objecttype -eq 5) -and ($_.targeted -le $noOfDP)} | Select PackageID,SoftwareName,SourceSize,DateCreated,LastUpdateDate,Targeted | ConvertTo-html  -Head $test -Body "<h2>Software Update Packages distributed to less than or equal to $noOfDP Distribution Points</h2>" >> "$strPath"
deinitializeSCCM
write-host "`n Openning $strpath report : " -foregroundcolor $inputcolor -nonewline
Invoke-Item $strPath

 

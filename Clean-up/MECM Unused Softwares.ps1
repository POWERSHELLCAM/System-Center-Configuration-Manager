# ######################################################################
#
# 	Program         :   MECM Unused Softwares.ps1
# 	Version         :   1.0
# 	Purpose         :   Get the list of unused applications 
# 	Author          :	Shishir Kushawaha
#	Mail Id         :   srktcet@gmail.com
#   Created         :   30/03/2023 - Script creation.
# 	Modified        :	
# ######################################################################

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
$starttime=Get-Date
Clear-Host
$location=get-location 
$InputColor="yellow" 
$ProcessColor="write-host `$ProcessMessage -ForegroundColor gray -BackgroundColor darkgreen" 
$ReportTitle="MECM Orphan Softwares"
$strPath = "$location\$ReportTitle.html" 
updateHTML $strPath

ConvertTo-Html -Head $test -Title $ReportTitle -Body "<h1> Orphan MECM Softwares </h1>" >  "$strPath"
InitializeSCCM 

$PackageReport = @() 
"$(get-date) > Gathering all packages."
$Packages = Get-CMPackage -fast | Select-Object Name, PackageID, SourceDate, ObjectPath
"$(get-date) > Gathering all applications."
$Applications = Get-CMApplication | Select-Object LocalizedDisplayName, NumberOfDependentTS,PackageID,IsDeployed, IsExpired, IsEnabled,CreatedBy, ModelName, DateCreated | Where-Object {$_.IsDeployed -eq $false -or $_.IsExpired -eq $true -or $_.IsEnabled -eq $false} 
"$(get-date) > Gathering all task sequences."
$TaskSequences = Get-CMTaskSequence | Select-Object Name, PackageID, References | Where-Object { $null -ne $_.References } 
"$(get-date) > Gathering all deployments."
$Deployments = Get-CMDeployment | Select-Object softwarename,packageid,deploymentid,collectionid
"$(get-date) > All information gathered."

"$(get-date) > Processing Applications...."
$count=0
foreach ($Application in $Applications)
{
    if($Application.NumberOfDependentTS -eq 0 )
    {
        $dpcount=0
        $pkgStatus=$null
        if(($($Application.PackageID) -ne ""))
        {
            $($Application.PackageID)
            $pkgStatus=Get-CMDistributionStatus -Id $($Application.PackageID)
            $dpcount=$($pkgStatus.NumberErrors+$pkgStatus.NumberInProgress+$pkgStatus.NumberSuccess+$pkgStatus.NumberUnknown+0)
        }
        else 
        {
            $dpcount='Unknown'
        }
        $TaskSequenceMatch = [PSCustomObject]@{
            'Sr No'=$($count++)
            'Software Name' = $($Application.LocalizedDisplayName)
            'Type'="Application Model"
            'Package ID'= $($Application.PackageID)
            'Owner'= $($Application.CreatedBy)
            'Date Created'=$($Application.DateCreated)
            'DP Count'=$dpcount
        }
        $PackageReport += $TaskSequenceMatch   
    }
} 

"$(get-date) > Processing Applications completed."

"$(get-date) > Processing Packages...."
# Run package report 
Foreach ($Package in $Packages) 
{ 
    $TaskSequenceCount = $DeploymentCount=0
    $DeploymentCount = ($Deployments | Where-Object { $_.PackageID -match $Package.PackageID }).count 
    if(($DeploymentCount -eq 0) -or ($null -eq $DeploymentCount ))
    {
        foreach ($TaskSequence in $TaskSequences) 
        { 
            if ($null -ne ($TaskSequence | Select-Object -ExpandProperty References | Where-Object { $_.Package -contains $Package.PackageID })) 
            {
                $TaskSequenceCount++
                break
            }
        } 
        if(($TaskSequenceCount -eq 0))
        {
            $pkgStatus=$null
            $pkgStatus=Get-CMDistributionStatus -Id $($Package.PackageID)
            $TaskSequenceMatch = [PSCustomObject]@{
                'Sr No'=$($count++)
                'Software Name' = $($Package.Name)
                'Type'="Package Model"
                'Package ID'= $($Package.PackageID )
                'Owner'= "NA"
                'Date Created'= $($Package.SourceDate)
                'DP Count'=$($pkgStatus.NumberErrors+$pkgStatus.NumberInProgress+$pkgStatus.NumberSuccess+$pkgStatus.NumberUnknown+0)
            }
            $PackageReport += $TaskSequenceMatch 
        }
    }
}

"$(get-date) > Processing Packages completed"
$endtime=Get-Date
$totaltime= New-TimeSpan -Start $starttime -End $endtime
"$(get-date) > Total time of executio $totaltime"
#De-initializing SCCM 
deinitializeSCCM 

ConvertTo-Html -Head $test -Title $ReportTitle -Body "<h2> Total Packages : $($Packages.count) <br>Total Applications : $($Applications.count)<br> Total Deployments : $($Deployments.count) <br> Total Tasksequences : $($TaskSequences.count) <br> Total Orphan Softwares : $($PackageReport.count)</h2>" >  "$strPath"
$PackageReport | Sort-Object -Property 'DP Count' | ConvertTo-html  -Head $test -Body "<h2>Software Details</h2>" >> "$strPath"
#Launching HTML generated report 
write-host "`n Opening $strpath report. `n" -foregroundcolor $inputcolor -nonewline 
Invoke-Item $strPath


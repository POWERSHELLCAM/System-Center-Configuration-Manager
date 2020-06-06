
# ######################################################################
#
# 	Program         :   GET_CLIENT_COLLECTION_MEMBERSHIP.ps1
# 	Version         :   1.1
# 	Purpose         :   Get the list of collection device is part of.
# 	Author          :	Shishir Kushawaha
#	Mail Id         :   srktcet@gmail.com
#   Created         :   06/11/2019 - Script creation.
# 	Modified        :	
#						
# ######################################################################

<#

Objective:

To list set of collections where a client is part of those.Script is also helpful to get below information.

Name,
CollectionID
MemberCount
LastMemberChangeTime

Things to NOTE:
Script may take some time to list depends on the count of membership.

How it Process:
Take client name as a input.
Query collections membership to check if the it is part of that
List those where it is a member
 

Output:

Output will be in .HTML page.

#>

 #--CSS formatting
$test=@'
<style type="text/css">
 h5,h2, th { text-align: left; font-family: Segoe UI;font-size: 13px;}
 h1{ text-align: left; font-family: Segoe UI;font-size: 20px;color:magenta;}
table { margin: left; font-family: Segoe UI; box-shadow: 10px 10px 5px #888; border: thin ridge grey;}
th { background: #4CAF50; color: #fff; max-width: 400px; padding: 5px 10px; font-size: 12px;}
td { font-size: 11px; padding: 5px 20px; color: #000; }
tr { background: #b8d1f3; }
tr:nth-child(even) { background: #f2f2f2; }
tr:nth-child(odd) { background: #ddd; }
</style>
'@

#--Variable declaration
	 clear
	 $location=get-location 
	 $InputColor="yellow" 
	 $ProcessColor="write-host `$ProcessMessage -ForegroundColor gray -BackgroundColor darkgreen" 
	 $ReportTitle="SCCM Client Collection Membership"
	 $strPath = "$location\$ReportTitle.html" 
	 $report=0

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
		$connTest=Test-Connection -ComputerName $ProviderMachineName -Count 1 -ErrorAction SilentlyContinue
		if($connTest -eq $null)
		{
			write-host " Entered SMS provider is invalid or not responding. Please re-enter provider name" -foregroundcolor RED
		}
	}while((!$nameResult) -or ($connTest -eq $null))

if($true)
{
#collection membership Information
do{
	clear
	$report++
		
			$result =@()
			write-host "`n Enter computer name : " -foregroundcolor $inputcolor -nonewline
			$id=read-host
			$ResID =$null
			[string]$systemName=$id.tostring().toupper()
			$name_space="root\sms\site_$($SiteCode)"
			$server_name="$($ProviderMachineName)"
			
			#Gathering ResourceID information of a device
			$ResID = (Get-WmiObject -Namespace $Name_space -ComputerName $Server_name -Query "Select * from SMS_R_System where Name = '$($systemname)'").resourceid
			
			if($ResID)
			{
				write-host "System $is have resource ID as $resID"
				$strPath = "$location\$systemName $ReportTitle$report.html" 
				if(test-path $strpath -ea silentlycontinue){remove-item $strpath -force}
				$collections=$null
				
				#Gathering list of collections device is part of.
				$Collections = (Get-WmiObject -Class sms_fullcollectionmembership -Namespace $name_space -ComputerName $server_name -filter "resourceid = $resid").CollectionID
				if($null -ne $collections)
				{
					#Gathering collections informations
					foreach ($Collection in $Collections)
					{
						$temp_output=Get-WmiObject -Namespace $name_space -Query "select CollectionID,Name,ObjectPath,LimitToCollectionID,LimitToCollectionName,MemberCount from SMS_Collection Where SMS_Collection.CollectionID='$($collection)'" -computername $server_name
					
						$temp_result=[pscustomobject]@{
						'Collection ID'=$($temp_output.collectionID)
						'Collection Name' =$($temp_output.Name)
						'Object Path'=$($temp_output.ObjectPath)
						'Limit To Collection ID'=$($temp_output.LimitToCollectionID)
						'Limit To Collection Name'=$($temp_output.LimitToCollectionName)
						'Member Count'=$($temp_output.MemberCount)
						}
						$result+=$temp_result
						$temp_result=$temp_output=$null
					}
				
					if($result -ne $null)
					{
						$collections=$resid=$null
						ConvertTo-Html -Head $test -Title $ReportTitle -Body "<h1>  $ReportTitle </h1>" >>  "$strPath"
						ConvertTo-Html -Head $test -Title $ReportTitle -Body "<h1>  $systemName Collection membership</h1>" >>  "$strPath"
						$result| ConvertTo-html  -Head $test -Body "" >> "$strPath"
						write-host "`n Opening $strpath report. `n" -foregroundcolor $inputcolor -nonewline 
						Invoke-Item $strPath
						$result=$null
					}
				}
				else
				{
					write-host "Issue with getting collection information."
				}
			}
			else
			{
			
				write-host "`n System name entered is invalid."
			}
			
			do
			{
				$quit=read-host "`n Do you want to exit?[Type Yes or No]"
				$validyesno=($quit -match '^(?:Yes|No)$')
				if(!$validyesno)
				{
					write-host "`n Acceptable input [yes | no] only. Case insensitive." -foregroundcolor RED
				}
			}while(!$validyesno)
}while($quit -eq "No")
}
else
{
write-host "Management point server is not responding or some error occurred during connection.Exiting......... " -foregroundcolor RED
}
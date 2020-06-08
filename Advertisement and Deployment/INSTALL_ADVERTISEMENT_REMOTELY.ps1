
# ######################################################################
#
# 	Program         :   INSTALL_ADVERTISEMENT_REMOTELY.ps1
# 	Version         :   1.1
# 	Purpose         :   Run advertisement remotely
# 	Author          :	Shishir Kushawaha
#	Mail Id         :   srktcet@gmail.com
#   Created         :   08/06/2020 - Script creation.
# 	Modified        :	
# ######################################################################

<# Objective:
	Trigger advertisment installation on remote device
#>

<# How to execute:
	Provide the info of single device or list of devices where you want to run the script in C:\Temp\PC_list.txt. 
	Provide the name or package id of advertisment.
#>

<# Execution:
	Script will check the online status of a device. If it is online , it will check for available advertisment and trigger it.
#>

$script_block={
param($package)	
	
	if($package)
	{
		$Package_result=get-wmiobject  -query "SELECT * FROM CCM_SoftwareDistribution" -namespace "root\ccm\policy\machine\actualconfig"|Where-Object {$_.pkg_packageid -eq $package}

		if($null -eq $Package_result)
		{
			$Package_result=get-wmiobject -query "SELECT * FROM CCM_SoftwareDistribution" -namespace "root\ccm\policy\machine\actualconfig"|Where-Object {$_.pkg_name -eq $package}
		}
		
		if(($Package_result.pkg_packageid).count -gt 1)
			{
				$Package_result=$Package_result[0]
			}
		
		if($Package_result)
		{
				write-host "$env:computername" -foregroundcolor cyan
				write-host "Package Name : $($Package_result.pkg_name)" -foregroundcolor cyan
				write-host "Package ID : $($Package_result.pkg_packageid)" -foregroundcolor cyan
				$sid=([xml]($Package_result.PRG_Requirements)).SWDReserved.ScheduledMessageID
				if($sid)
				{
					if($Package_result.ADV_MandatoryAssignments -eq $false)
					{
						write-host "The Assignment is not mandatory. Making it." -foregroundcolor yellow
						$Package_result.ADV_MandatoryAssignments=$true
						$Package_result.put() | out-null
						Start-Sleep 5
					}
					else
					{
						write-host "The Assignment is mandatory." -foregroundcolor yellow
					}
					write-host "Started executing the assignment $($Package_result.pkg_name) on $($env:computername)." -foregroundcolor green
					$Package_result.ADV_RepeatRunBehavior='RerunAlways'
					$Package_result.put() | out-null
					Start-Sleep 5
					([wmiclass]'ROOT\ccm:SMS_Client').TriggerSchedule($sid) | out-null
				}
				else 
				{
					Write-Host "Issue with executing scheduled assignment" -ForegroundColor red
				}     
			
		}
		else 
		{
			Write-Host "No such scheduled assignment exist for $env:computername." -ForegroundColor yellow   
		}
	}
	else
	{
		Write-Host "No advertisement name defined." -ForegroundColor red
	}
}
clear-host

Write-host "Verifying that the script is running elevated" -foregroundcolor yellow
if (-Not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) 
{
	 if ([int](Get-CimInstance -Class Win32_OperatingSystem | Select-Object -ExpandProperty BuildNumber) -ge 6000) 
	 {
		  Write-host "Script is not running elevated. Please provide the admin credential" -foregroundcolor red
		  $Cx = "-File `"" + $MyInvocation.MyCommand.Path + "`" " + $MyInvocation.UnboundArguments
		  Start-Process -FilePath PowerShell.exe -Verb Runas -ArgumentList "-noexit",$Cx
		  Exit
	 }
}
else
{
	Write-host "Script is running with elevated admin credential." -foregroundcolor green
}


#Single computer. Put/remove # before '<' character to uncomment or comment.
#<#
$computer=''

#Enter PackageID or name of the Advertisement
$package=''

if($computer)
{
	if(test-connection $computer -count 1 -ErrorAction SilentlyContinue)
	{
		Invoke-Command -ScriptBlock $script_block -computername $computer -argumentlist $package
	}
	else
	{
		write-host "$computer is OFFLINE." -ForegroundColor red
	}
}
else
{
	write-host "No Device name defined." -ForegroundColor red
}
#>

#Multiple computer. Put/remove # before '<' character to uncomment or comment.
<#
$pclist=gc C:\Temp\PC_list.txt
if($null -ne $pclist)
{
	foreach($computer in $pclist)
	{
		if(test-connection $computer -count 1 -ErrorAction SilentlyContinue)
		{
			write-host ""
			Invoke-Command -ScriptBlock $script_block -computername $computer -argumentlist $package
		}
		else
		{
			write-host "$computer is OFFLINE." -ForegroundColor red
		}
	}
}
else
{
	write-host "No Device list defined." -ForegroundColor red
}#>

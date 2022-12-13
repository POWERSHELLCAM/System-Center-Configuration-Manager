
# Function to check with the computer account is disabled
function Get-IsComputerAccountDisabled
{
  param($Computername)
  $root = [ADSI]''
  $searcher = New-Object -TypeName System.DirectoryServices.DirectorySearcher -ArgumentList ($root)
  $searcher.filter = "(&(objectClass=Computer)(Name=$Computername))"
  $Result = $searcher.findall()
  If ($Result.Count -ne 0)
  {
    $Result | ForEach-Object {
        $Computer = $_.GetDirectoryEntry()
        [pscustomobject]@{
            ComputerName = $Computername
            IsDisabled = $Computer.PsBase.InvokeGet("AccountDisabled")
        }
    }
  }
  Else
  {
      [pscustomobject]@{
      ComputerName = $Computername
      IsDisabled = "Not found in AD"
      }
  }
}

# Function to remove the device record from SCCM via WMI
function Remove-CMRecord($Computername)
{
    $ErrorAction = 'Stop'
    # Check if the system exists in SCCM
    Try
    {
        $devicerecords=Get-WmiObject -ComputerName $SiteServer -Namespace "root\sms\site_$SiteCode" -Class sms_r_system -Filter "Name = `'$Computername`'" -ErrorAction Stop
        foreach($d in $devicerecords)
        {
            $resourceid=$Computer=$null
            $resourceid=$($d.resourceid)
            $Computer = [wmi]($d).__PATH
            if($Computer)
            {
                $Computer.psbase.delete()
                $Computer = Get-WmiObject -ComputerName $SiteServer -Namespace "root\sms\site_$SiteCode" -Class sms_r_system -Filter "ResourceID = `'$resourceid`'" -ErrorAction Silentlycontinue
                If ($Computer.PSComputerName)
                {
                    $Result = "Tried to delete but record still exists"
                }
                Else
                {
                    $Result = "Successfully deleted"
                }
            }
            else 
            {
                $Result = "Not found in SCCM"
            }
            [pscustomobject]@{
                DeviceName = $Computername
                IsDisabled = $DeviceStatus
                Result = $Result
                }
        }
    }
    Catch
    {
        $error[0]
    }
}

$global:SiteCode = ""
$global:SiteServer = ""
$EmailRecipient = ""
$EmailSender = "" 
$SMTPServer = ""
$date1=  $(get-date -Format 'yyyy-MMM-dd')
$file1="D:\MECM Tools\CM_Cleanup1_"+$date1+".log"
$style = @"
<style>
body {
    color:#333333;
    font-family: ""Trebuchet MS"", Arial, Helvetica, sans-serif;}
}
h1 {
    text-align:center;
}
table {
    border-collapse: collapse;
    font-family: ""Trebuchet MS"", Arial, Helvetica, sans-serif;
}
th {
    font-size: 10pt;
    text-align: left;
    padding-top: 5px;
    padding-bottom: 4px;
    background-color: #1FE093;
    color: #ffffff;
}
td {
    font-size: 8pt;
    border: 1px solid #1FE093;
    padding: 3px 7px 2px 7px;
}
</style>
"@
# Let's get the list of inactive systems, or systems with no SCCM client, from WMI
try
{
    $DevicesToCheck=$null
    "Checking list of inactive systems, or systems with no SCCM client." | out-file -Append $file1
    $DevicesToCheck = Get-WmiObject -ComputerName $SiteServer -Namespace root\SMS\Site_$SiteCode -Query "SELECT SMS_R_System.Name FROM SMS_R_System left join SMS_G_System_CH_ClientSummary on SMS_G_System_CH_ClientSummary.ResourceID = SMS_R_System.ResourceID where (SMS_G_System_CH_ClientSummary.ClientActiveStatus = 0 or SMS_R_System.Active = 0 or SMS_R_System.Active is null) and SMS_R_System.ResourceDomainORWorkgroup = 'CORP'" -ErrorAction Stop |  Select-Object -ExpandProperty Name|        Sort-Object
    if($DevicesToCheck)
    {
        "Inactive systems, or systems with no SCCM client found." | out-file -Append $file1
        $date1=  $(get-date -Format 'yyyy-MMM-dd hh:mm')
        $date1 +", Devices to check:"+$DevicesToCheck.Count 
        $date1 +", Devices to check:"+$DevicesToCheck.Count | out-file -Append $file1
        # Now let's filter those systems whose AD account is disabled or not present
        "Filtering those systems whose AD account is disabled or not present." | out-file -Append $file1
        $NotEnabledDevices=$null
        $NotEnabledDevices = ($DevicesToCheck | ForEach-Object {Get-IsComputerAccountDisabled  -Computername $_}) | Where-Object {$_.IsDisabled -ne $False}
        if ($null -ne $NotEnabledDevices)
        {
            $date1=  $(get-date -Format 'yyyy-MMM-dd hh:mm')
            $date1 +", Devices to Not enabled:"+$NotEnabledDevices.count| out-file -Append $file1
            try 
            {
                # Then we will delete each record from SCCM using WMI
                "Delete each record from SCCM" | out-file -Append $file1
                $DeletedRecords = New-Object System.Collections.ArrayList
                foreach($device in $NotEnabledDevices)
                {
                    $Output=$devicestatus=$null
                    $devicestatus=$($device.IsDisabled)
                    "Deleting $($device.computername)" | out-file -Append $file1
                    $Output=Remove-CMRecord $($device.computername)
                    $DeletedRecords+=$Output
                }
                "Completed deletion process" | out-file -Append $file1
                $DeletedRecords = $DeletedRecords | Group-Object -Property Result
                $totaldeleted=$($DeletedRecords.group.result -match 'Successfully deleted').Count
                $($DeletedRecords.group)| out-file -Append $file1
                # Finally we will send the list of affected systems to the administrator
                If ($DeletedRecords.Count -ne 0)
                {
                    $Body = $($DeletedRecords.group) | ConvertTo-Html -Head $style -Body "<h2>The following systems are either disabled or not present in active directory and to be deleted from SCCM</h2> <br>Total MECM Devices : $($DevicesToCheck.count)<br>Total Devices disabled/notpresent : $($NotEnabledDevices.count) <br>Total Devices deleted : $totaldeleted <br><br>Total Duplicate devices : $($($NotEnabledDevices.count)-$totaldeleted) <br><br>" | Out-String
                    Send-MailMessage -To $EmailRecipient -From $EmailSender  -Subject "Disabled Computer Accounts Deleted from SCCM ($(Get-Date -format 'yyyy-MMM-dd'))" -SmtpServer $SMTPServer -Body $body -BodyAsHtml
                }
            }
            catch 
            {
                $_ | out-file -Append $file1
                $error[0] | out-file -Append $file1
            }
        }
        else 
        {
            "Nothing to delete."| out-file -Append $file1
        }
    }
    else 
    {
        "No inactive systems, or systems with no SCCM client found." | out-file -Append $file1
    }
}
Catch
{
    $_ | out-file -Append $file1
}


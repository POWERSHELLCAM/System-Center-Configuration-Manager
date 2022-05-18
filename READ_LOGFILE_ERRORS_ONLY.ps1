# ######################################################################
#
# 	Program         :   READ_LOGFILE_ERRORS_ONLY.ps1
# 	Version         :   1.0
# 	Purpose         :   Convert lengthy log file to short version
# 	Author          :	Shishir Kushawaha
#   Technet Link    :   https://gallery.technet.microsoft.com/site/search?f%5B0%5D.Type=User&f%5B0%5D.Value=SHISHIR%20KUSHAWAHA&pageIndex=3 
#	Mail Id         :   srktcet@gmail.com
#   Created         :   23/08/2018 - Script creation.
# 	Modified        :	29/10/2019 - Improved the logging 
# ######################################################################

<# Objective:
	This  script will read the log file and create a new log file with lines having only error , failed statement. This will make easy to read log file as this will not have normal execution statement. 
	Script will only extract the statement which will have exception type=3 or failed statement.
#>

<# How to execute:
	Read entire log file from the path provided.
	Extract all lines having error or failed statement
	Copy those statement and save to new log file
	Launch the log file with CMTrace or notepad.
#>

<# Execution:
	Run the script.
#>

<#
	Output will be in .log file.
#>

#******************Start of Function Section*************************


#write message to log file and display on form
function messageLabel($DISPLAY_MSG,$COMPONENT)
{
	$LOG_LEVEL=3
	#Adding lines to log file
    $LOG_TIME = "$(Get-Date -Format HH:mm:ss).$((Get-Date).Millisecond)+000"
    $LOG_LINE = '<![LOG[{0}]LOG]!><time="{1}" date="{2}" component="{3}" context="" type="{4}" thread="" file="">'
    $LOG_LINE_FORMAT = $DISPLAY_MSG, $LOG_TIME, (Get-Date -Format MM-dd-yyyy), $COMPONENT, $LOG_LEVEL
    $LOG_LINE = $LOG_LINE -f $LOG_LINE_FORMAT
	Add-Content -Value $LOG_LINE -Path $COMPACT_LOG_FILENAME_PATH
}

do
{
	$LOG_FILE_NAME=read-host "Enter complete path of log file"
	if(!((Test-Path $LOG_FILE_NAME) -and (Test-Path $LOG_FILE_NAME -PathType Leaf)))
	{
		write-host "Entered file name path is invalid or not available or does not contain file name in its path. Please try again." -foregroundcolor red -backgroundcolor black
	}
	else
	{
		$LOG_CONTENT=get-content $LOG_FILE_NAME
		$PARENT_PATH=Split-Path $LOG_FILE_NAME -Parent
		$FILE_NAME=Split-Path $LOG_FILE_NAME -leaf
		$COMPACT_LOG_FILENAME=$FILE_NAME.Split(".")
		$COMPACT_LOG_FILENAME=$COMPACT_LOG_FILENAME[0]+"_compact_"+"$((get-date).ticks)"+".log"
		$COMPACT_LOG_FILENAME_PATH="$PARENT_PATH\$COMPACT_LOG_FILENAME"
		$COMPACT_LOG_FILENAME_PATH
		if(Test-Path $COMPACT_LOG_FILENAME_PATH)
		{ 
			write-host "Old $COMPACT_LOG_FILENAME_PATH exist. Deleting it ... " -foregroundcolor green
			Remove-Item $COMPACT_LOG_FILENAME_PATH
		}
		$LOG_CONTENT | ForEach-Object{if(($_ -match 'type="3"') -or ($_ -match "failed")){messageLabel $_.split('[')[2].split(']')[0] $_.split('[')[2].split('=')[3].split('"')[1]}} 
		if(Test-Path $COMPACT_LOG_FILENAME_PATH)
		{ 
			Write-Host "Compact log file stored at $COMPACT_LOG_FILENAME_PATH . Use CMTRACE or Trace32 to view the log file."
		}
		else
		{
			write-host "$FILE_NAME does not contains any error." -foregroundcolor green
		}
	}
}while(!((Test-Path $LOG_FILE_NAME) -and (Test-Path $LOG_FILE_NAME -PathType Leaf)))

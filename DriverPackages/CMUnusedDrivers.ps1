

$drivers= get-cmdriver -fast
$driverIDs= $drivers.ci_id

#list of driver packages
$driverpackageid=Get-CMDriverPackage -Fast | Select-Object packageid

#list of drivers integrated in boot image
$bootimageDriversIDs=(Get-CMBootImage | Select-Object -ExpandProperty ReferencedDrivers).id

$unusedDrivers=$null
$usedDrivers=@()

#list drivers from all driver packages
foreach($pkgid in $driverpackageid)
{
    write-host "Checking driver package $pkgid."
    $usedDrivers+=(Get-CMDriver -Fast -DriverPackageId $pkgid).ci_id
}
#Add boot image drivers in driver packages drivers
$usedDrivers+=$bootimageDriversIDs

#Remove duplicate drivers
$usedDrivers=$usedDrivers | Select-Object -Unique

#Subtract used drivers from all drivers to get the list if unused drivers
$unusedDrivers =  Compare-Object -ReferenceObject $usedDrivers -DifferenceObject $driverIDs -PassThru


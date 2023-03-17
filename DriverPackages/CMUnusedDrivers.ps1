

$drivers= (get-cmdriver -fast).ci_id
$driverpackageid=Get-CMDriverPackage -Fast | Select-Object packageid

$unusedDrivers=@()
$usedDrivers=@()
foreach($pkgid in $driverpackageid)
{
    write-host ""
    write-host "Checking driver package $pkgid."
    $usedDrivers+=(Get-CMDriver -Fast -DriverPackageId $pkgid).ci_id
    $usedDrivers+=(Get-CMBootImage | Select-Object -ExpandProperty ReferencedDrivers).id
}

$usedDrivers=$usedDrivers | Select-Object -Unique

$unusedDrivers =  Compare-Object -ReferenceObject $usedDrivers -DifferenceObject $drivers -PassThru


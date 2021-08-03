Param(
    [Parameter(Mandatory = $true)]
    [String]$SharedImageGalleryResourceGroup,
    [Parameter(Mandatory = $true)]
    [String]$SharedImageGalleryName,
    [Parameter(Mandatory = $true)]
    [String]$SharedImageGalleryDefinitionName
)

$sigversions = Get-AzGalleryImageVersion -ResourceGroupName $SharedImageGalleryResourceGroup -GalleryName $SharedImageGalleryName -GalleryImageDefinitionName $SharedImageGalleryDefinitionName
$latestversion = $sigversions[$sigversions.count - 1].Name

#Create new patch version number:  major.month.patch
$month = get-date -format MM
$major = $latestversion.split(".")[0]
$minor = $latestversion.split(".")[1]
$patch = [int]$latestversion.split(".")[2]

#Increment Patch version if already patched this month.
if ($minor -eq $month) {
    $patch ++
}

$newVersion = "$($major).$($month).$($patch)"

#Check for existing image and remove if required
$image = Get-AzImage -Name "WVDGolden"
if ($image.count -gt 0) {
    Write-Host "Existing Managed Image found. Removing. . . "
    Remove-AzImage -Name $image.Name -ResourceGroupName $image.ResourceGroupName -Force | Out-Null
}

#Import the Windows-Update plugin into Packer
$download = 'https://github.com/rgl/packer-provisioner-windows-update/releases/download/v0.10.1/packer-provisioner-windows-update_0.10.1_windows_amd64.zip'
(New-Object System.Net.WebClient).DownloadFile($download, 'D:\packerwu.zip')
Expand-Archive -Path D:\packerwu.zip -DestinationPath $env:APPDATA\packer.d\plugins

Write-Host "##vso[task.setvariable variable=oldVersion;isOutput=true;]$latestversion"
Write-Host "##vso[task.setvariable variable=newVersion;isOutput=true;]$newVersion"

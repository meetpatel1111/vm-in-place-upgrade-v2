param (
    [Parameter(Mandatory = $true)]
    [string] $ResourceGroup,

    [Parameter(Mandatory = $true)]
    [string] $Location,

    [Parameter(Mandatory = $true)]
    [string] $DiskName,

    [Parameter(Mandatory = $true)]
    [ValidateSet(
        "server2025Upgrade",
        "server2022Upgrade",
        "server2019Upgrade",
        "server2016Upgrade",
        "server2012Upgrade"
    )]
    [string] $Sku,

    [string] $Zone = "",

    [string] $ManagedDiskSku = "Standard_LRS"
)

# -------------------------------
# Marketplace constants
# -------------------------------
$publisher = "MicrosoftWindowsServer"
$offer     = "WindowsServerUpgrade"

Write-Host "Resolving latest hidden upgrade image..."
Write-Host "Publisher : $publisher"
Write-Host "Offer     : $offer"
Write-Host "SKU       : $Sku"
Write-Host "Location  : $Location"

# -------------------------------
# Get latest image version
# -------------------------------
$versions = Get-AzVMImage `
    -PublisherName $publisher `
    -Location $Location `
    -Offer $offer `
    -Skus $Sku |
    Sort-Object -Descending { [version] $_.Version }

if (-not $versions) {
    throw "No upgrade image found for SKU '$Sku' in $Location"
}

$latestVersion = $versions[0].Version
Write-Host "Latest version: $latestVersion"

# -------------------------------
# Get image object
# -------------------------------
$image = Get-AzVMImage `
    -Location $Location `
    -PublisherName $publisher `
    -Offer $offer `
    -Skus $Sku `
    -Version $latestVersion

# -------------------------------
# Ensure resource group exists
# -------------------------------
if (-not (Get-AzResourceGroup -Name $ResourceGroup -ErrorAction SilentlyContinue)) {
    Write-Host "Creating resource group $ResourceGroup"
    New-AzResourceGroup -Name $ResourceGroup -Location $Location | Out-Null
}

# -------------------------------
# Create disk config (FromImage)
# -------------------------------
if ($Zone) {
    $diskConfig = New-AzDiskConfig `
        -SkuName $ManagedDiskSku `
        -CreateOption FromImage `
        -Zone $Zone `
        -Location $Location
}
else {
    $diskConfig = New-AzDiskConfig `
        -SkuName $ManagedDiskSku `
        -CreateOption FromImage `
        -Location $Location
}

# Explicitly bind image + LUN 0 (critical)
Set-AzDiskImageReference `
    -Disk $diskConfig `
    -Id $image.Id `
    -Lun 0

# -------------------------------
# Create managed disk
# -------------------------------
New-AzDisk `
    -ResourceGroupName $ResourceGroup `
    -DiskName $DiskName `
    -Disk $diskConfig

Write-Host "SUCCESS: Upgrade media disk created"
Write-Host "Disk Name      : $DiskName"
Write-Host "Resource Group : $ResourceGroup"
Write-Host "SKU            : $Sku"

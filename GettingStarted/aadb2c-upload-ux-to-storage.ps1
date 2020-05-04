param (
    [Parameter(Mandatory=$true)][Alias('p')][string]$Path = "",
    [Parameter(Mandatory=$false)][Alias('s')][string]$StorageAccountConnectString = "DefaultEndpointsProtocol=https;AccountName=...;AccountKey=...;EndpointSuffix=core.windows.net",
    [Parameter(Mandatory=$false)][Alias('c')][string]$ContainerPath = ""
    )

$stgCtx = New-AzStorageContext -ConnectionString $StorageAccountConnectString

$containerName = $ContainerPath.Split("/")[0]
$location = $ContainerPath.Substring($containerName.Length+1)

$files = get-childitem -path $path -name | Where-Object {! $_.PSIsContainer }
foreach( $file in $files ) {
    write-output "Uploading to $($stgCtx.BlobEndPoint)$ContainerPath/$file"
    $res = Set-AzStorageBlobContent -File "$Path\$file" -Container $containerName -Blob "$location/$file" -Context $stgCtx -Force
}

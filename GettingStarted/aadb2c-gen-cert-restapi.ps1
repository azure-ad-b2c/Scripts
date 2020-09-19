param (
    [Parameter(Mandatory=$false)][Alias('s')][string]$Subject = "",       # CN=apiname.yourtenant.onmicrosoft.com
    [Parameter(Mandatory=$false)][Alias('y')][int]$YearsValid = 1,
    [Parameter(Mandatory=$false)][Alias('l')][string]$CertStoreLocation = "Cert:\CurrentUser\My",       
    [Parameter(Mandatory=$false)][Alias('f')][string]$Path = (Get-Location).Path,       
    [Parameter(Mandatory=$true)][Alias('p')][System.Security.SecureString]$Password     # ConvertTo-SecureString -String $pwd -Force -AsPlainText
    )

if ( "" -eq $Subject ) {
    $tenant = Get-AzureADTenantDetail
    $tenantName = $tenant.VerifiedDomains[0].Name
    $Subject = "CN=restapi.$tenantName"
}
#$certCN = "CN=restapi.cljunglabb2c.onmicrosoft.com"

write-host "Generating certificate $Subject in $CertStoreLocation"
$cert = New-SelfSignedCertificate -KeyExportPolicy Exportable -KeyAlgorithm RSA -KeyLength 2048 -KeyUsage DigitalSignature `
                                -NotAfter (Get-Date).AddYears($YearsValid) -Subject $Subject -CertStoreLocation $CertStoreLocation

write-host $cert.Thumbprint

$certfile = "$Path\$($Subject.Substring(3))_$(Get-Date -format("yyyMMdd")).pfx"
write-host "Exporting to $certFile"
Export-PfxCertificate -cert "$CertStoreLocation\$($cert.Thumbprint)" -FilePath $certfile -Password $Password
                                
# $certContent = New-Object System.Security.Cryptography.X509Certificates.X509Certificate($certfile, $pwd)
# $certRaw = [System.Convert]::ToBase64String($certContent.GetRawCertData())


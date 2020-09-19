param (
    [Parameter(Mandatory=$false)][Alias('p')][string]$PolicyPath = "",
    [Parameter(Mandatory=$false)][Alias('b')][string]$PolicyType = "SocialAndLocalAccounts"
    )

[Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"

$urlStarterPackBase = "https://raw.githubusercontent.com/Azure-Samples/active-directory-b2c-custom-policy-starterpack/master" #/SocialAndLocalAccounts/TrustFrameworkBase.xml

function DownloadFile ( $Url, $LocalPath ) {
    $p = $Url -split("/")
    $filename = $p[$p.Length-1]
    $LocalFile = "$LocalPath/$filename"
    Write-Host "Downloading $Url to $LocalFile"
    $webclient = New-Object System.Net.WebClient
    $webclient.DownloadFile($Url,$LocalFile)
}

if ( "" -eq $PolicyPath ) {
    $PolicyPath = (get-location).Path
}
DownloadFile "$urlStarterPackBase/$PolicyType/TrustFrameworkBase.xml" $PolicyPath
DownloadFile "$urlStarterPackBase/$PolicyType/TrustFrameworkExtensions.xml" $PolicyPath
DownloadFile "$urlStarterPackBase/$PolicyType/SignUpOrSignin.xml" $PolicyPath
DownloadFile "$urlStarterPackBase/$PolicyType/PasswordReset.xml" $PolicyPath
DownloadFile "$urlStarterPackBase/$PolicyType/ProfileEdit.xml" $PolicyPath

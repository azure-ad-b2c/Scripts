function Upload-IEFPolicies {
    [CmdletBinding()]
    param(
        #[Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$sourceDirectory = '.\',

        [ValidateNotNullOrEmpty()]
        [string]$configurationFilePath = '.\conf.json',

        [ValidateNotNullOrEmpty()]
        [string]$updatedSourceDirectory = '.\debug\',

        [ValidateNotNullOrEmpty()]
        [string]$prefix,

        [ValidateNotNullOrEmpty()]
        [switch]$generateOnly

    )

    $m = Get-Module -ListAvailable -Name AzureADPreview
    if ($m -eq $null) {
        "Please install-module AzureADPreview before running this command"
        return
    }
    if ($sourceDirectory.EndsWith('\')) {
        $sourceDirectory = $sourceDirectory + '*' 
    } else {
        if (-Not $sourceDirectory.EndsWith('\*')) { 
            $sourceDirectory = $sourceDirectory + '\*' 
        }
    }

    # upload policies whose base id is given
    function Upload-Children($baseId) {
        foreach($p in $policyList) {
            if ($p.BaseId -eq $baseId) {
                # Skip unchanged files
                #outFile = ""
                if (-not ([string]::IsNullOrEmpty($updatedSourceDirectory))) {
                    if(!(Test-Path -Path $updatedSourceDirectory )){
                        New-Item -ItemType directory -Path $updatedSourceDirectory
                        Write-Host "Updated source folder created"
                    }
                    if (-not $updatedSourceDirectory.EndsWith("\")) {
                        $updatedSourceDirectory = $updatedSourceDirectory + "\"
                    }
                    $envUpdatedDir = '{0}{1}' -f $updatedSourceDirectory, $b2c.TenantDomain
                    if(!(Test-Path -Path $envUpdatedDir)){
                        New-Item -ItemType directory -Path $envUpdatedDir
                        Write-Host "  Updated source folder created for " + $b2c.TenantDomain
                    }
                    $outFile = '{0}\{1}' -f $envUpdatedDir, $p.Source
                    if (Test-Path $outFile) {
                        if ($p.LastWrite.Ticks -le (Get-Item $outFile).LastWriteTime.Ticks) {
                            "{0}: is up to date" -f $p.Id
                            Upload-Children $p.Id
                            continue;
                        }
                    }
                }
                $msg = "{0}: uploading" -f $p.Id
                Write-Host $msg  -ForegroundColor Green 
                $policy = $p.Body -replace "yourtenant.onmicrosoft.com", $b2c.TenantDomain
                $policy = $policy -replace "ProxyIdentityExperienceFrameworkAppId", $iefProxy.AppId
                $policy = $policy -replace "IdentityExperienceFrameworkAppId", $iefRes.AppId
                $policy = $policy.Replace('PolicyId="B2C_1A_', 'PolicyId="B2C_1A_{0}' -f $prefix)
                $policy = $policy.Replace('/B2C_1A_', '/B2C_1A_{0}' -f $prefix)
                $policy = $policy.Replace('<PolicyId>B2C_1A_', '<PolicyId>B2C_1A_{0}' -f $prefix)

                # replace other placeholders, e.g. {MyRest} with http://restfunc.com. Note replacement string must be in {}
                if ($conf -ne $null) {
                    $special = @('IdentityExperienceFrameworkAppId', 'ProxyIdentityExperienceFrameworkAppId', 'PolicyPrefix')
                    foreach($memb in Get-Member -InputObject $conf -MemberType NoteProperty) {
                        if ($memb.MemberType -eq 'NoteProperty') {
                            if ($special.Contains($memb.Name)) { continue }
                            $repl = "{{{0}}}" -f $memb.Name
                            $policy = $policy.Replace($repl, $memb.Definition.Split('=')[1])
                        }
                    }
                }

                $policyId = $p.Id.Replace('_1A_', '_1A_{0}' -f $prefix)
                $isOK = $true
                if (-not $generateOnly) {
                    try {
                        Set-AzureADMSTrustFrameworkPolicy -Content ($policy | Out-String) -Id $policyId -ErrorAction Stop | Out-Null
                    } catch {
                        $isOk = $false
                        $_
                    }
                }

                if ($isOK) {
                    out-file -FilePath $outFile -inputobject $policy
                }
                Upload-Children $p.Id
            }
        }
    }

    # get current tenant data
    $b2c = Get-AzureADCurrentSessionInfo -ErrorAction stop
    
    $iefRes = Get-AzureADApplication -Filter "DisplayName eq 'IdentityExperienceFramework'"
    $iefProxy = Get-AzureADApplication -Filter "DisplayName eq 'ProxyIdentityExperienceFramework'"

    # load originals
    $files = Get-Childitem -Path $sourceDirectory -Include *.xml
    $policyList = @()
    foreach($policyFile in $files) {
        $policy = Get-Content $policyFile
        $xml = [xml] $policy
        $policyList= $policyList + @(@{ Id = $xml.TrustFrameworkPolicy.PolicyId; BaseId = $xml.TrustFrameworkPolicy.BasePolicy.PolicyId; Body = $policy; Source= $policyFile.Name; LastWrite = $policyFile.LastWriteTime })
    }
    "Source policies:"
    foreach($p in $policyList) {
        "Id: {0}; Base:{1}" -f $p.Id, $p.BaseId
    }

    if (-not ([string]::IsNullOrEmpty($configurationFilePath))) {
        $conf = Get-Content -Path $configurationFilePath -ErrorAction Continue | Out-String | ConvertFrom-Json
        if ([string]::IsNullOrEmpty($prefix)){ $prefix = $conf.Prefix }
    } else {
        $conf = $null
    }

    # now start the upload process making sure you start with the base (base id == null)
    Upload-Children($null)
}

# Creates a json object with typical settings needed by
# the Upload-IEFPolicies function.
function Get-IEFSettings {
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string]$policyPrefix
    )

    $iefAppName = "IdentityExperienceFramework"
    if(!($iefApp = Get-AzureADApplication -Filter "DisplayName eq '$($iefAppName)'"  -ErrorAction SilentlyContinue))
    {
        throw "Not found " + $iefAppName
    } else {
        if ($iefApp.PublicClient) {
            Write-Error "IdentityExperienceFramework must be defined as a confidential client (web app)"
        }
    }

    $iefProxyAppName = "ProxyIdentityExperienceFramework"
    if(!($iefProxyApp = Get-AzureADApplication -Filter "DisplayName eq '$($iefProxyAppName)'"  -ErrorAction SilentlyContinue))
    {
        throw "Not found " + $iefProxyAppName
    } else {
        if (-not $iefProxyApp.PublicClient) {
            Write-Error "ProxyIdentityExperienceFramework must be defined as a public client"
        }
        $iefOK = $signInOk = $False
        foreach($r in $iefProxyApp.RequiredResourceAccess) {
            if ($r.ResourceAppId -eq $iefApp.AppId) { $iefOk = $true }
            if ($r.ResourceAppId -eq '00000002-0000-0000-c000-000000000000') { $signInOk = $true }
        }
        if ((-not $iefOK) -or (-not $signInOk)) {
            Write-Error 'ProxyIdentityExperienceFramework is not permissioned to use the IdentityExperienceFramework app (it must be consented as well)'
        } 
    }

    $envs = @()
    $envs += @{ 
        IdentityExperienceFrameworkAppId = $iefApp.AppId;
        ProxyIdentityExperienceFrameworkAppId = $iefProxyApp.AppId;
        PolicyPrefix = $policyPrefix  }
    $envs | ConvertTo-Json

    <#
     # 
    $iefAppName = "IdentityExperienceFramework"
    if(!($iefApp = Get-AzureADApplication -Filter "DisplayName eq '$($iefAppName)'"  -ErrorAction SilentlyContinue))
    {
        Write-Host "Creating " $iefAppName
        $myApp = New-AzureADApplication -DisplayName $iefAppName   
    }
    $iefProxyAppName = "ProxyIdentityExperienceFramework"
    if(!($iefProxyApp = Get-AzureADApplication -Filter "DisplayName eq '$($iefProxyAppName)'"  -ErrorAction SilentlyContinue))
    {
        Write-Host "Creating " $iefAppName
        $myApp = New-AzureADApplication -DisplayName $iefAppName   
    }
    #>
}

function Download-IEFPolicies {
    [CmdletBinding()]
    param(
        #[Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$tenantName,

        #[Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$destinationPath
    )
    if ([string]::IsNullOrEmpty($desinationPath)) {
        $destinationPath = ".\"
    }
    $m = Get-Module -ListAvailable -Name AzureADPreview
    if ($m -eq $null) {
        "Please install-module AzureADPreview before running this command"
        return
    }
    $b2c = Get-AzureADCurrentSessionInfo -ErrorAction Stop

    if (-Not $destinationPath.EndsWith('\')) {
        $destinationPath = $destinationPath + '\' 
    }

    foreach($policy in Get-AzureADMSTrustFrameworkPolicy) {
        $fileName = "{0}\{1}.xml" -f $destinationPath, $policy.Id
        Get-AzureADMSTrustFrameworkPolicy -Id $policy.Id >> $fileName
    }
}
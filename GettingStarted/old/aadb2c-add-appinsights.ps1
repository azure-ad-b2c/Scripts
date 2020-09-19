param (
    [Parameter(Mandatory=$false)][Alias('p')][string]$PolicyPath = "",              # either a path and all xml files will be processed
    [Parameter(Mandatory=$false)][Alias('f')][string]$PolicyFile = "",              # or a single file
    [Parameter(Mandatory=$false)][Alias('k')][string]$InstrumentationKey = ""       # AppInsighs key
    )

if ( "" -eq $InstrumentationKey) { $InstrumentationKey = $global:InstrumentationKey }

$JourneyInsights = @"
<JourneyInsights TelemetryEngine="ApplicationInsights" InstrumentationKey="{InstrumentationKey}" 
DeveloperMode="true" ClientEnabled="true" ServerEnabled="true" TelemetryVersion="1.0.0" />
"@

# enumerate all XML files in the specified folders and create a array of objects with info we need
Function EnumPoliciesFromPath( [string]$PolicyPath ) {
    $files = get-childitem -path $policypath -name -include *.xml | Where-Object {! $_.PSIsContainer }
    foreach( $file in $files ) {
        #write-output "Reading Policy XML file $file..."
        $File = (Join-Path -Path $PolicyPath -ChildPath $file)
        ProcessPolicyFile $File
    }
}

Function ProcessPolicyFile( $File ) {
    $PolicyData = Get-Content $File
    [xml]$xml = $PolicyData
    if ( $null -ne $xml.TrustFrameworkPolicy.RelyingParty ) {
        AddAppInsightToPolicy $File $xml
    }
}
# process each Policy object in the array. For each that has a BasePolicyId, follow that dependency link
# first call has to be with BasePolicyId null (base/root policy) for this to work
Function AddAppInsightToPolicy( $PolicyFile, $xml ) {
    $changed = $false
    foreach( $rp in $xml.TrustFrameworkPolicy.RelyingParty ) {
        # already have AppInsight - just upd key
        if ( $null -ne $rp.UserJourneyBehaviors -and $null -ne $rp.UserJourneyBehaviors.JourneyInsights ) {
            $rp.UserJourneyBehaviors.JourneyInsights.InstrumentationKey = $InstrumentationKey
            $changed = $true
        }
        # might have UserJourneyBehaviors for javascript - add JourneyInsights
        if ( $null -ne $rp.UserJourneyBehaviors -and $null -eq $rp.UserJourneyBehaviors.JourneyInsights ) {
            $rp.InnerXml = $rp.InnerXml.Replace("</UserJourneyBehaviors>", "$JourneyInsights</UserJourneyBehaviors>")
            $changed = $true
        }
        # don't have UserJourneyBehaviors - add it directly after DefaultUserJourney element
        if ( $null -eq $rp.UserJourneyBehaviors ) {
            $idx = $rp.InnerXml.IndexOf("/>")
            $rp.InnerXml = $rp.InnerXml.Substring(0,$idx+2) + "<UserJourneyBehaviors>$JourneyInsights</UserJourneyBehaviors>" + $rp.InnerXml.Substring($idx+2)
            $changed = $true
        }
    }
    if ( $null -eq $xml.TrustFrameworkPolicy.UserJourneyRecorderEndpoint ) {
        $idx = $xml.InnerXml.IndexOf(">")
        $idx += $xml.InnerXml.Substring($idx+1).IndexOf(">")
        $xml.InnerXml = $xml.InnerXml.Substring(0,$idx+1) + " DeploymentMode=`"Development`" UserJourneyRecorderEndpoint=`"urn:journeyrecorder:applicationinsights`"" + $xml.InnerXml.Substring($idx+1)
        $changed = $true
    }
    if ( $changed ) {
        $xml.TrustFrameworkPolicy.InnerXml = $xml.TrustFrameworkPolicy.InnerXml.Replace( "xmlns=`"http://schemas.microsoft.com/online/cpim/schemas/2013/06`"", "") 
        write-output "Adding AppInsights InstrumentationKey $InstrumentationKey to $($xml.TrustFrameworkPolicy.PolicyId)"
        $xml.Save($File)        
    }
}

$JourneyInsights = $JourneyInsights.Replace("{InstrumentationKey}", $InstrumentationKey)
<##>
if ( "" -eq $PolicyPath ) {
    $PolicyPath = (get-location).Path
}

if ( "" -ne $PolicyFile ) {
    # process a single file
    ProcessPolicyFile (Resolve-Path $PolicyFile).Path
} else {
    # process all policies that has a RelyingParty
    EnumPoliciesFromPath $PolicyPath
}


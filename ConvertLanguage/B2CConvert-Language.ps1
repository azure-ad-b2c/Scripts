# Translate B2C Language Customisation using the cognitive API
# Ensure you change the laguage settings below
$global:lan = "mi"
$global:APIKey = "<ENTER YOUR KEY HERE>"
$jsonlangfilePath = "C:\Tools\b2c\Language\"
##

function Translate
{
  Param($string, $language, $at) 
  try{
    $body = "[{`"Text`":`"$string`"}]"
    $url = "https://api.cognitive.microsofttranslator.com/translate?api-version=3.0&from=en&to=" + $language
    $resp = Invoke-WebRequest -Uri $url -Headers @{"Ocp-Apim-Subscription-Key"="$global:APIKey"; "Authorization"="Bearer $at"; "Content-Type"="application/json"} -Method POST -Body $body
    $respjson = $resp.Content |ConvertFrom-Json
    $respjson.translations.text
  }
  catch {
    Write-Warning "Error translating string ($string) : $_"
    return $string
  }
}

$atresp = Invoke-WebRequest -Uri https://api.cognitive.microsoft.com/sts/v1.0/issueToken -Headers @{"Ocp-Apim-Subscription-Key"="$APIKey"} -Method POST
$at = [System.Text.Encoding]::ASCII.GetString($atresp.Content)

$files = Get-ChildItem -Filter "*.json" -Path $jsonlangfilePath

foreach($infile in $files)
{
  $customlang = Get-Content -Path $infile -raw | ConvertFrom-Json
  foreach ($str in $customlang.LocalizedStrings)
  { 
    $str.Override = "True"
    $str.Value = Translate $str.Value $lan $at
  }

  $file = Get-Item $infile
  $outfile = $file.Directory.FullName + "\" + $file.BaseName + "_" + $lan +".json"
  $customlang | ConvertTo-Json -depth 100 | Out-File $outfile
}

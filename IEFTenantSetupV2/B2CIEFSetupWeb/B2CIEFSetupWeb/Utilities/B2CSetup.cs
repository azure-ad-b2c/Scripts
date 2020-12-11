using B2CIEFSetupWeb.Models;
using Microsoft.Extensions.Logging;
using Microsoft.Identity.Web;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Text;
using System.Threading.Tasks;
using System.Xml;
using System.Xml.Linq;

namespace B2CIEFSetupWeb.Utilities
{
    public interface IB2CSetup
    {
        Task<List<IEFObject>> SetupAsync(string domainId, bool readOnly, string dirDomainName);
    }
    public class B2CSetup : IB2CSetup
    {
        private readonly ITokenAcquisition _tokenAcquisition;
        private readonly ILogger<B2CSetup> _logger;
        private HttpClient _http;
        public B2CSetup(ILogger<B2CSetup> logger, ITokenAcquisition tokenAcquisition)
        {
            _logger = logger;
            _tokenAcquisition = tokenAcquisition;
        }
        public string DomainName { get; private set; }
        private bool _readOnly = false;
        private bool _removeFb = false;

        public async Task<List<IEFObject>> SetupAsync(string domainId, bool removeFb, string dirDomainName)
        {
            using (_logger.BeginScope("SetupAsync: {0} - Read only: {1}", domainId, removeFb))
            {
                _removeFb = removeFb;
                try
                {
                    var token = await _tokenAcquisition.GetAccessTokenOnBehalfOfUserAsync(
                        Constants.ReadWriteScopes,
                        domainId);
                    _http = new HttpClient();
                    _http.DefaultRequestHeaders.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", token);

                    _actions = new List<IEFObject>();
                    await SetupIEFAppsAsync(domainId);
                    await SetupKeysAsync();
                    var extAppId = await GetAppIdAsync("b2c-extensions-app");
                    _actions.Add(new IEFObject()
                    {
                        Name = "Extensions app: appId",
                        Id = extAppId,
                        Status = String.IsNullOrEmpty(extAppId) ? IEFObject.S.NotFound : IEFObject.S.Existing
                    });
                    extAppId = await GetAppIdAsync("b2c-extensions-app", true);
                    _actions.Add(new IEFObject()
                    {
                        Name = "Extensions app: objectId",
                        Id = extAppId,
                        Status = String.IsNullOrEmpty(extAppId) ? IEFObject.S.NotFound : IEFObject.S.Existing
                    });
                } catch(Exception ex)
                {
                    _logger.LogError(ex, "SetupAsync failed");
                }



                //ief app 0
                //proxyief app 1
                //extension appid 4
                //extension objectId 5


                //download localAndSocialStarterPack
                //base: https://raw.githubusercontent.com/Azure-Samples/active-directory-b2c-custom-policy-starterpack/master/LocalAccounts/TrustFrameworkBase.xml
                //extensions: https://raw.githubusercontent.com/Azure-Samples/active-directory-b2c-custom-policy-starterpack/master/LocalAccounts/TrustFrameworkExtensions.xml
                //signinup: https://raw.githubusercontent.com/Azure-Samples/active-directory-b2c-custom-policy-starterpack/master/LocalAccounts/SignUpOrSignin.xml


                string baseFile = new WebClient().DownloadString("https://raw.githubusercontent.com/Azure-Samples/active-directory-b2c-custom-policy-starterpack/master/SocialAndLocalAccountsWithMfa/TrustFrameworkBase.xml");
                string extFile = new WebClient().DownloadString("https://raw.githubusercontent.com/Azure-Samples/active-directory-b2c-custom-policy-starterpack/master/SocialAndLocalAccountsWithMfa/TrustFrameworkExtensions.xml");
                string susiFile = new WebClient().DownloadString("https://raw.githubusercontent.com/Azure-Samples/active-directory-b2c-custom-policy-starterpack/master/SocialAndLocalAccountsWithMfa/SignUpOrSignin.xml");
                string pwdResetFile = new WebClient().DownloadString("https://raw.githubusercontent.com/Azure-Samples/active-directory-b2c-custom-policy-starterpack/master/SocialAndLocalAccountsWithMfa/PasswordReset.xml");
                string profileEditFile = new WebClient().DownloadString("https://raw.githubusercontent.com/Azure-Samples/active-directory-b2c-custom-policy-starterpack/master/SocialAndLocalAccountsWithMfa/ProfileEdit.xml");

                string baseFileLocal = new WebClient().DownloadString("https://raw.githubusercontent.com/Azure-Samples/active-directory-b2c-custom-policy-starterpack/master/LocalAccounts/TrustFrameworkBase.xml");

                if (removeFb)
                {
                    extFile = new WebClient().DownloadString("https://raw.githubusercontent.com/Azure-Samples/active-directory-b2c-custom-policy-starterpack/master/LocalAccounts/TrustFrameworkExtensions.xml");
                }

                baseFile = baseFile.Replace("yourtenant.onmicrosoft.com", dirDomainName + ".onmicrosoft.com");
                extFile = extFile.Replace("yourtenant.onmicrosoft.com", dirDomainName + ".onmicrosoft.com");
                susiFile = susiFile.Replace("yourtenant.onmicrosoft.com", dirDomainName + ".onmicrosoft.com");
                pwdResetFile = pwdResetFile.Replace("yourtenant.onmicrosoft.com", dirDomainName + ".onmicrosoft.com");
                profileEditFile = profileEditFile.Replace("yourtenant.onmicrosoft.com", dirDomainName + ".onmicrosoft.com");

                if (removeFb)
                {
                    // Remove default social and local and mfa user journeys
                    XmlDocument socialAndLocalBase = new XmlDocument();
                    socialAndLocalBase.LoadXml(baseFile);
                    var nsmgr = new XmlNamespaceManager(socialAndLocalBase.NameTable);
                    nsmgr.AddNamespace("xsl", "http://schemas.microsoft.com/online/cpim/schemas/2013/06");

                    XmlNode socialAndMFAJourneys = socialAndLocalBase.SelectSingleNode("/xsl:TrustFrameworkPolicy/xsl:UserJourneys", nsmgr);
                    socialAndMFAJourneys.RemoveAll();
                    XmlNode parentSocialAndMFAJourneys = socialAndMFAJourneys.ParentNode;
                    parentSocialAndMFAJourneys.RemoveChild(socialAndMFAJourneys);

                    XmlNode facebookTP = socialAndLocalBase.SelectSingleNode("/xsl:TrustFrameworkPolicy/xsl:ClaimsProviders/xsl:ClaimsProvider[1]", nsmgr);
                    facebookTP.RemoveAll();
                    XmlNode parentfacebookTP = facebookTP.ParentNode;
                    parentfacebookTP.RemoveChild(facebookTP);

                    using (var stringWriter = new StringWriter())
                    using (var xmlTextWriter = XmlWriter.Create(stringWriter))
                    {
                        socialAndLocalBase.WriteTo(xmlTextWriter);
                        xmlTextWriter.Flush();
                        baseFile = stringWriter.GetStringBuilder().ToString();
                    }

                    // Insert user journeys from LocalAccounts base file into Ext file.
                    XmlDocument localBase = new XmlDocument();
                    localBase.LoadXml(baseFileLocal);
                    XmlNode localBaseJourneys = localBase.SelectSingleNode("/xsl:TrustFrameworkPolicy/xsl:UserJourneys", nsmgr);

                    using (var stringWriter = new StringWriter())
                    using (var xmlTextWriter = XmlWriter.Create(stringWriter))
                    {
                        string localJourneysString = localBaseJourneys.OuterXml;
                        extFile = extFile.Replace("</TrustFrameworkPolicy>", localJourneysString + "</TrustFrameworkPolicy>");
                    }

                }



                extFile = extFile.Replace("ProxyIdentityExperienceFrameworkAppId", _actions[1].Id);
                extFile = extFile.Replace("IdentityExperienceFrameworkAppId", _actions[0].Id);

                string aadCommon = @"    
                            <ClaimsProviders>
                             <ClaimsProvider>
                              <DisplayName>Azure Active Directory</DisplayName>
                              <TechnicalProfiles>
                                <TechnicalProfile Id=""AAD-Common"">
                                  <DisplayName>Azure Active Directory</DisplayName>
                                  <Metadata>
                                    <Item Key=""ApplicationObjectId"">ExtAppObjectId</Item>
                                    <Item Key=""ClientId"">ExtAppId</Item>
                                  </Metadata>
                                </TechnicalProfile>
                              </TechnicalProfiles>
                            </ClaimsProvider>";

                aadCommon = aadCommon.Replace("ExtAppObjectId", _actions[5].Id);
                aadCommon = aadCommon.Replace("ExtAppId", _actions[4].Id);

                extFile = extFile.Replace("<ClaimsProviders>", aadCommon);


                //upload facebook secret
                if (!removeFb)
                {
                    if (!_keys.Contains($"B2C_1A_FacebookSecret"))
                    {
                        var fbKeySetResp = await _http.PostAsync("https://graph.microsoft.com/beta/trustFramework/keySets",
                        new StringContent(JsonConvert.SerializeObject(new { id = "FacebookSecret" }), Encoding.UTF8, "application/json"));


                        var fbKeyGenerateResp = await _http.PostAsync("https://graph.microsoft.com/beta/trustFramework/keySets/B2C_1A_FacebookSecret/uploadSecret",
                        new StringContent(JsonConvert.SerializeObject(new { use = "sig", k = "secret", nbf = 1607626546, exp = 4132148146 }), Encoding.UTF8, "application/json"));

                        if (fbKeyGenerateResp.IsSuccessStatusCode)
                        {
                            _actions.Add(new IEFObject()
                            {
                                Name = "Facebook secret",
                                Id = "B2C_FacebookSecret",
                                Status = IEFObject.S.Uploaded
                            });

                        }
                    }
                }
                else {
                    _actions.Add(new IEFObject()
                    {
                        Name = "Facebook secret",
                        Id = "B2C_FacebookSecret",
                        Status = IEFObject.S.Skipped
                    });
                }

                if (_keys.Contains($"B2C_1A_FacebookSecret") & (!removeFb))
                {
                    _actions.Add(new IEFObject()
                    {
                        Name = "Facebook secret",
                        Id = "B2C_FacebookSecret",
                        Status = IEFObject.S.Existing
                    });

                }


                //upload all files

                XDocument basePolicyFile = XDocument.Parse(baseFile);
                string basePolicyFileId = basePolicyFile.Root.Attribute("PolicyId").Value;
                var baseResp = await _http.PutAsync($"https://graph.microsoft.com/beta/trustFramework/policies/" + basePolicyFileId + "/$value",
                new StringContent(baseFile, Encoding.UTF8, "application/xml"));
                if (baseResp.IsSuccessStatusCode)
                {
                    _actions.Add(new IEFObject()
                    {
                        Name = "TrustframeworkBase",
                        Id = basePolicyFileId,
                        Status = IEFObject.S.Uploaded
                    });

                }
                XDocument extPolicyFile = XDocument.Parse(extFile);
                string extPolicyFileId = extPolicyFile.Root.Attribute("PolicyId").Value;
                var extResp = await _http.PutAsync($"https://graph.microsoft.com/beta/trustFramework/policies/" + extPolicyFileId + "/$value",
                new StringContent(extFile, Encoding.UTF8, "application/xml"));
                if (extResp.IsSuccessStatusCode)
                {
                    _actions.Add(new IEFObject()
                    {
                        Name = "TrustframeworkExtensions",
                        Id = extPolicyFileId,
                        Status = IEFObject.S.Uploaded
                    });

                }
                XDocument susiPolicyFile = XDocument.Parse(susiFile);
                string susiPolicyFileId = susiPolicyFile.Root.Attribute("PolicyId").Value;
                var susiResp = await _http.PutAsync($"https://graph.microsoft.com/beta/trustFramework/policies/" + susiPolicyFileId + "/$value",
                new StringContent(susiFile, Encoding.UTF8, "application/xml"));
                if (susiResp.IsSuccessStatusCode)
                {
                    _actions.Add(new IEFObject()
                    {
                        Name = "SignUpSignIn",
                        Id = susiPolicyFileId,
                        Status = IEFObject.S.Uploaded
                    });

                }
                XDocument pwdResetPolicyFile = XDocument.Parse(pwdResetFile);
                string pwdResetPolicyFileId = pwdResetPolicyFile.Root.Attribute("PolicyId").Value;
                var pwdResetResp = await _http.PutAsync($"https://graph.microsoft.com/beta/trustFramework/policies/" + pwdResetPolicyFileId + "/$value",
                new StringContent(pwdResetFile, Encoding.UTF8, "application/xml"));
                if (pwdResetResp.IsSuccessStatusCode)
                {
                    _actions.Add(new IEFObject()
                    {
                        Name = "PasswordReset",
                        Id = pwdResetPolicyFileId,
                        Status = IEFObject.S.Uploaded
                    });

                }
                XDocument profileEditPolicyFile = XDocument.Parse(profileEditFile);
                string profileEditPolicyFileId = profileEditPolicyFile.Root.Attribute("PolicyId").Value;
                var profileEditResp = await _http.PutAsync($"https://graph.microsoft.com/beta/trustFramework/policies/" + profileEditPolicyFileId + "/$value",
                new StringContent(profileEditFile, Encoding.UTF8, "application/xml"));
                if (profileEditResp.IsSuccessStatusCode)
                {
                    _actions.Add(new IEFObject()
                    {
                        Name = "ProfileEdit",
                        Id = profileEditPolicyFileId,
                        Status = IEFObject.S.Uploaded
                    });

                }



                //CREATE TEST APP

                var iefTestApp = new
                {
                    isFallbackPublicClient = false,
                    identifierUris = new List<string>() { $"https://{DomainName}/IEFTestApp"},
                    displayName = "IEF Test App",
                    signInAudience = "AzureADandPersonalMicrosoftAccount",
                    publicClient = new { redirectUris = new List<string>() { $"https://jwt.ms" } },
                    parentalControlSettings = new { legalAgeGroupRule = "Allow" },
                    requiredResourceAccess = new List<object>() {
                new {
                    resourceAppId = "00000003-0000-0000-c000-000000000000",
                    resourceAccess = new List<object>()
                    {
                        new {
                                id = "37f7f235-527c-4136-accd-4a02d197296e",
                                type = "Scope"
                            },
                        new {
                                id = "7427e0e9-2fba-42fe-b0c0-848c9e6a8182",
                                type = "Scope"
                            }
                    }
                }
            },
                    web = new
                    {
                        implicitGrantSettings = new
                        {
                            enableIdTokenIssuance = true,
                            enableAccessTokenIssuance = true
                        }
                    }
                };

                var json = JsonConvert.SerializeObject(iefTestApp);
                var resp = await _http.PostAsync($"https://graph.microsoft.com/beta/applications",
                    new StringContent(json, Encoding.UTF8, "application/json"));

                if (!resp.IsSuccessStatusCode)
                {
                    _actions.Add(new IEFObject()
                    {
                        Name = "IEF Test App Registration",
                        Id = "-",
                        Status = IEFObject.S.Existing
                    });
                }


                    if (resp.IsSuccessStatusCode)
                {
                    _logger.LogTrace("{0} app created", "iefTestApp");

                    var body = await resp.Content.ReadAsStringAsync();
                    var appJSON = JObject.Parse(body);
                    var id = (string)appJSON["appId"];

                    _actions.Add(new IEFObject()
                    {
                        Name = "IEF Test App Registration",
                        Id = id,
                        Status = IEFObject.S.New
                    });



                    var sp = new
                    {
                        accountEnabled = true,
                        appId = _actions[12].Id,
                        appRoleAssignmentRequired = false,
                        displayName = "IEF Test App",
                    };
                    resp = await _http.PostAsync($"https://graph.microsoft.com/beta/servicePrincipals",
                        new StringContent(JsonConvert.SerializeObject(sp), Encoding.UTF8, "application/json"));
                    if (!resp.IsSuccessStatusCode) throw new Exception(resp.ReasonPhrase);
                    //AdminConsentUrl = new Uri($"https://login.microsoftonline.com/{tokens.TenantId}/oauth2/authorize?client_id={appIds.ProxyAppId}&prompt=admin_consent&response_type=code&nonce=defaultNonce");
                    _logger.LogTrace("{0} SP created", "IEF Test App");
                }


            }
            return _actions;
        }
        public List<IEFObject> _actions;
        public SetupState _state;

        private async Task SetupIEFAppsAsync(string domainId)
        {
            var AppName = "IdentityExperienceFramework";
            var ProxyAppName = "ProxyIdentityExperienceFramework";

            var json = await _http.GetStringAsync("https://graph.microsoft.com/beta/domains");
            var value = (JArray)JObject.Parse(json)["value"];
            DomainName = ((JObject)value.First())["id"].Value<string>();
            _logger.LogTrace("Domain: {0}", DomainName);
            //TODO: needs refactoring

            _actions.Add(new IEFObject()
            {
                Name = AppName,
                Status = IEFObject.S.NotFound
            });
            _actions[0].Id = await GetAppIdAsync(_actions[0].Name);
            if (!String.IsNullOrEmpty(_actions[0].Id)) _actions[0].Status = IEFObject.S.Existing;
            _actions.Add(new IEFObject()
            {
                Name = ProxyAppName,
                Status = IEFObject.S.NotFound
            });
            _actions[1].Id = await GetAppIdAsync(_actions[1].Name);
            if (!String.IsNullOrEmpty(_actions[1].Id)) _actions[1].Status = IEFObject.S.Existing;

            if (!String.IsNullOrEmpty(_actions[0].Id) && !String.IsNullOrEmpty(_actions[1].Id)) return; // Sorry! What if only one exists?
            //TODO: should verify whether the two apps are setup correctly
            if (_readOnly) return;

            var requiredAADAccess = new
            {
                resourceAppId = "00000002-0000-0000-c000-000000000000",
                resourceAccess = new List<object>()
            {
                new {
                    id = "311a71cc-e848-46a1-bdf8-97ff7156d8e6",
                    type = "Scope"
                }
            }
            };
            var iefApiPermission = new
            {
                adminConsentDescription = $"Allow the application to access {AppName} on behalf of the signed-in user.",
                adminConsentDisplayName = $"Access {AppName}",
                id = Guid.NewGuid().ToString("D"),
                isEnabled = true,
                type = "User",
                userConsentDescription = $"Allow the application to access {AppName} on your behalf.",
                userConsentDisplayName = $"Access {AppName}",
                value = "user_impersonation"
            };

            var app = new
            {
                isFallbackPublicClient = false,
                displayName = AppName,
                identifierUris = new List<string>() { $"https://{DomainName}/{AppName}" },
                signInAudience = "AzureADMyOrg",
                api = new { oauth2PermissionScopes = new List<object> { iefApiPermission } },
                web = new
                {
                    redirectUris = new List<string>() { $"https://login.microsoftonline.com/{DomainName}" },
                    homePageUrl = $"https://login.microsoftonline.com/{DomainName}",
                    implicitGrantSettings = new
                    {
                        enableIdTokenIssuance = true,
                        enableAccessTokenIssuance = false
                    }
                }
            };

            json = JsonConvert.SerializeObject(app);
            var resp = await _http.PostAsync($"https://graph.microsoft.com/beta/applications",
                new StringContent(json, Encoding.UTF8, "application/json"));
            if (resp.IsSuccessStatusCode)
            {
                _logger.LogTrace("{0} application created", AppName);
                var body = await resp.Content.ReadAsStringAsync();
                var appJSON = JObject.Parse(body);
                _actions[0].Id = (string)appJSON["appId"];
                _actions[0].Status = IEFObject.S.New;
                var spId = Guid.NewGuid().ToString("D");
                var sp = new
                {
                    accountEnabled = true,
                    appId = _actions[0].Id,
                    appRoleAssignmentRequired = false,
                    displayName = AppName,
                    homepage = $"https://login.microsoftonline.com/{DomainName}",
                    replyUrls = new List<string>() { $"https://login.microsoftonline.com/{DomainName}" },
                    servicePrincipalNames = new List<string>() {
                    app.identifierUris[0],
                    _actions[0].Id
                },
                    tags = new string[] { "WindowsAzureActiveDirectoryIntegratedApp" },
                };
                resp = await _http.PostAsync($"https://graph.microsoft.com/beta/servicePrincipals",
                    new StringContent(JsonConvert.SerializeObject(sp), Encoding.UTF8, "application/json"));
                if (!resp.IsSuccessStatusCode) throw new Exception(resp.ReasonPhrase);
                _logger.LogTrace("{0} SP created", AppName);
            }

            var proxyApp = new
            {
                isFallbackPublicClient = true,
                displayName = ProxyAppName,
                signInAudience = "AzureADMyOrg",
                publicClient = new { redirectUris = new List<string>() { $"https://login.microsoftonline.com/{DomainName}" } },
                parentalControlSettings = new { legalAgeGroupRule = "Allow" },
                requiredResourceAccess = new List<object>() {
                new {
                    resourceAppId = _actions[0].Id,
                    resourceAccess = new List<object>()
                    {
                        new {
                            id = iefApiPermission.id,
                            type = "Scope"
                        }
                    }
                },
                new {
                    resourceAppId = "00000002-0000-0000-c000-000000000000",
                    resourceAccess = new List<object>()
                    {
                        new
                        {
                            id = "311a71cc-e848-46a1-bdf8-97ff7156d8e6",
                            type = "Scope"
                        }
                    }
                }
            },
                web = new
                {
                    implicitGrantSettings = new
                    {
                        enableIdTokenIssuance = true,
                        enableAccessTokenIssuance = false
                    }
                }
            };

            json = JsonConvert.SerializeObject(proxyApp);
            resp = await _http.PostAsync($"https://graph.microsoft.com/beta/applications",
                new StringContent(json, Encoding.UTF8, "application/json"));
            if (resp.IsSuccessStatusCode)
            {
                _logger.LogTrace("{0} app created", ProxyAppName);
                var body = await resp.Content.ReadAsStringAsync();
                var appJSON = JObject.Parse(body);
                _actions[1].Id = (string)appJSON["appId"];
                _actions[1].Status = IEFObject.S.New;
                var sp = new
                {
                    accountEnabled = true,
                    appId = _actions[1].Id,
                    appRoleAssignmentRequired = false,
                    displayName = ProxyAppName,
                    //homepage = $"https://login.microsoftonline.com/{DomainName}",
                    //publisherName = DomainNamePrefix,
                    replyUrls = new List<string>() { $"https://login.microsoftonline.com/{DomainName}" },
                    servicePrincipalNames = new List<string>() {
                    _actions[1].Id
                },
                    tags = new string[] { "WindowsAzureActiveDirectoryIntegratedApp" },
                };
                resp = await _http.PostAsync($"https://graph.microsoft.com/beta/servicePrincipals",
                    new StringContent(JsonConvert.SerializeObject(sp), Encoding.UTF8, "application/json"));
                if (!resp.IsSuccessStatusCode) throw new Exception(resp.ReasonPhrase);
                //AdminConsentUrl = new Uri($"https://login.microsoftonline.com/{tokens.TenantId}/oauth2/authorize?client_id={appIds.ProxyAppId}&prompt=admin_consent&response_type=code&nonce=defaultNonce");
                _logger.LogTrace("{0} SP created", AppName);
            }

            return;
        }
        private List<string> _keys;
        private async Task SetupKeysAsync()
        {
            await CreateKeyIfNotExistsAsync("TokenSigningKeyContainer", "sig");
            await CreateKeyIfNotExistsAsync("TokenEncryptionKeyContainer", "enc");
        }
        private async Task CreateKeyIfNotExistsAsync(string name, string use)
        {
            var keySetupState = new IEFObject() { Name = name, Status = IEFObject.S.NotFound };
            _actions.Add(keySetupState);
            if (_keys == null)
            {
                var resp = await _http.GetStringAsync("https://graph.microsoft.com/beta/trustFramework/keySets");
                var keys = (JArray)JObject.Parse(resp)["value"];
                _keys = keys.Select(k => k["id"].Value<string>()).ToList();
            }
            var kName = $"B2C_1A_{name}";
            if (_keys.Contains($"B2C_1A_{name}"))
            {
                keySetupState.Status = IEFObject.S.Existing;
                if (_readOnly) return;
            } else {
                if (_readOnly) return;
                var httpResp = await _http.PostAsync("https://graph.microsoft.com/beta/trustFramework/keySets",
                    new StringContent(JsonConvert.SerializeObject(new { id = name }), Encoding.UTF8, "application/json"));
                if (httpResp.IsSuccessStatusCode)
                {
                    var keyset = await httpResp.Content.ReadAsStringAsync();
                    var id = JObject.Parse(keyset)["id"].Value<string>();
                    var key = new
                    {
                        use,
                        kty = "RSA"
                    };
                    httpResp = await _http.PostAsync($"https://graph.microsoft.com/beta/trustFramework/keySets/{id}/generateKey",
                        new StringContent(JsonConvert.SerializeObject(key), Encoding.UTF8, "application/json"));
                    if (!httpResp.IsSuccessStatusCode)
                    {
                        await _http.DeleteAsync($"https://graph.microsoft.com/beta/trustFramework/keySets/{id}");
                        throw new Exception(httpResp.ReasonPhrase);
                    }
                    keySetupState.Status = IEFObject.S.New;
                }
                else
                    throw new Exception(httpResp.ReasonPhrase);
            }





        }
        private async Task<string> GetAppIdAsync(string name, bool getObjectId = false)
        {
            var json = await _http.GetStringAsync($"https://graph.microsoft.com/beta/applications?$filter=startsWith(displayName,\'{name}\')");
            var value = (JArray)JObject.Parse(json)["value"];
            //TODO: what if someone created several apps?
            if (value.Count > 0)
            {
                if (getObjectId)
                    return ((JObject)value.First())["id"].Value<string>();
                else
                    return ((JObject)value.First())["appId"].Value<string>();
            }
            return String.Empty;
        }
    }

    public class IEFObject
    {
        public enum S { New, Existing, NotFound, Uploaded, Skipped }
        public string Name;
        public string Id;
        public S Status;
    }
}

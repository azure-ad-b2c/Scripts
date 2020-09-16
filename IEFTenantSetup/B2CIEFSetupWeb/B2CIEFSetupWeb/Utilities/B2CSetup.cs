using B2CIEFSetupWeb.Models;
using Microsoft.Extensions.Logging;
using Microsoft.Identity.Web;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.Http;
using System.Text;
using System.Threading.Tasks;

namespace B2CIEFSetupWeb.Utilities
{
    public interface IB2CSetup
    {
        Task<List<IEFObject>> SetupAsync(string domainId, bool readOnly);
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
        public async Task<List<IEFObject>> SetupAsync(string domainId, bool readOnly)
        {
            using (_logger.BeginScope("SetupAsync: {0} - Read only: {1}", domainId, readOnly))
            {
                _readOnly = readOnly;
                try
                {
                    var token = await _tokenAcquisition.GetAccessTokenOnBehalfOfUserAsync(
                        readOnly ? Constants.ReadOnlyScopes : Constants.ReadWriteScopes,
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
        public enum S { New, Existing, NotFound }
        public string Name;
        public string Id;
        public S Status;
    }
}

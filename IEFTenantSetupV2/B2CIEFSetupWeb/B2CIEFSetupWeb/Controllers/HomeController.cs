using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using B2CIEFSetupWeb.Models;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.OpenIdConnect;
using Microsoft.Identity.Web;
using B2CIEFSetupWeb.Utilities;
using Microsoft.ApplicationInsights;
using System.Net.Http;
using Newtonsoft.Json.Linq;

namespace B2CIEFSetupWeb.Controllers
{
    public class HomeController : Controller
    {
        private readonly ILogger<HomeController> _logger;
        private readonly IAuthenticationService _authenticator;
        private TelemetryClient telemetry = new TelemetryClient();
        public HomeController(
            ILogger<HomeController> logger, 
            IAuthenticationService authenticator
            )
        {
            _logger = logger;
            _authenticator = authenticator;
        }

        public IActionResult Index()
        {
            //log user landed on ieftool
            var startProperties = new Dictionary<string, string>
                        {{"Result", "Success"}};
            telemetry.InstrumentationKey = "a1dfc418-6ff5-4662-a7a1-f2faa979e74f";
            telemetry.Context.Operation.Name = "Landed on IEF Setup App";
            telemetry.TrackEvent("Landed on IEF Setup App", startProperties);
            return View(new SetupRequest());
        }
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<ActionResult> Index(SetupRequest req)
        {
            //TODO: allow user to requets read scopes only (no app creation)
            await _authenticator.ChallengeAsync(
                Request.HttpContext,
                "AzureADOpenID",
                new AuthenticationProperties(
                    new Dictionary<string, string>()
                    {
                        { ".redirect", "/home/setup?fb=" + req.RemoveFacebookReferences.ToString() + "&domainName=" + req.DomainName.ToString() + "&deployPhoneSignInJourneys=" + req.InitialisePhoneSignInJourneys.ToString()+ "&enableJs=" + req.EnableJavaScript.ToString()}
                    },
                    new Dictionary<string, object>()
                    {
                        {"tenant", req.DomainName },
                        {"domainHint", req.DomainName +".onmicrosoft.com" }
                    }));
            return View();
        }

        public IActionResult Privacy()
        {
            return View();
        }
        public IActionResult Experimental([FromQuery(Name = "sampleFolderName")] string sampleFolderName)
        {
            if (sampleFolderName != null)
            {
                sampleFolderBootstrap sampleBootstrap = new sampleFolderBootstrap();
                sampleBootstrap.sampleFolderName = sampleFolderName;
                //var queryObj = new Dictionary<string, string>();
                //queryObj.Add("sampleFolderName", sampleFolderName);
                ViewData["Message"] = sampleBootstrap;
            }
            if (sampleFolderName == null)
            {
                sampleFolderBootstrap sampleBootstrap = new sampleFolderBootstrap();
                sampleBootstrap.sampleFolderName = "";
                //var queryObj = new Dictionary<string, string>();
                //queryObj.Add("sampleFolderName", sampleFolderName);
                ViewData["Message"] = sampleBootstrap;
            }

            return View(new SetupRequestPolicySample());
        }
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<ActionResult> Experimental(SetupRequestPolicySample req)
        {
            await _authenticator.ChallengeAsync(
                Request.HttpContext,
                "AzureADOpenID",
                new AuthenticationProperties(
                    new Dictionary<string, string>()
                    {
                        { ".redirect", "/home/ExperimentalSetup?sampleName=" + req.SampleName.ToString() + "&domainName=" + req.DomainName.ToString() +"&fb=null&deployPhoneSignInJourneys=null"}
                    },
                    new Dictionary<string, object>()
                    {
                        {"tenant", req.DomainName },
                        {"domainHint", req.DomainName +".onmicrosoft.com" }
                    }));
            sampleFolderBootstrap sampleBootstrap = new sampleFolderBootstrap();
            sampleBootstrap.sampleFolderName = req.SampleName;
            ViewData["Message"] = sampleBootstrap;
            return View(new SetupRequestPolicySample());
        }

        public IActionResult Support()
        {
            return View();
        }


        [Authorize]
        public async Task<IActionResult> ExperimentalSetup([FromServices] Utilities.B2CSetup setup, [FromServices] ITokenAcquisition tokenAcquisition)
        {
            var samplePolicyStr = Request.Query["sampleName"].First();
            var dirDomainName = Request.Query["domainName"].First();
            var InitialisePhoneSignInJourneysStr = Request.Query["deployPhoneSignInJourneys"].First();
            var tenantId = User.Claims.First(c => c.Type == "http://schemas.microsoft.com/identity/claims/tenantid").Value;
            //var token = await tokenAcquisition.GetAccessTokenOnBehalfOfUserAsync(Constants.Scopes, tenantId);
            bool removeFb = false;
            bool initialisePhoneSignInJourneys = false;
            var res = await setup.SetupAsync(tenantId, removeFb, dirDomainName, initialisePhoneSignInJourneys, samplePolicyStr, false);
            var model = new SetupState();
            foreach (var item in res)
            {
                model.Items.Add(new ItemSetupState()
                {
                    Name = item.Name,
                    Id = (String.IsNullOrEmpty(item.Id) ? "-" : item.Id),
                    Status = item.Status == IEFObject.S.Exists ? "Exists" : item.Status == IEFObject.S.New ? "New" : item.Status == IEFObject.S.Uploaded ? "Uploaded" : item.Status == IEFObject.S.Failed ? "Failed" : item.Status == IEFObject.S.Skipped ? "Skipped" : "Not found",
                    Reason = (String.IsNullOrEmpty(item.Reason) ? "-" : item.Reason)
                });
            }

            //string testAppConsentAppId = res.First(kvp => kvp.Name == "IEF Test App Registration").Id;

            return View(model);
        }


        [Authorize]
        public async Task<IActionResult> Setup([FromServices] Utilities.B2CSetup setup, [FromServices] ITokenAcquisition tokenAcquisition)
        {
            var removeFbStr = Request.Query["fb"].First();
            var enableJSStr = Request.Query["enableJs"].First();
            var dirDomainName = Request.Query["domainName"].First();
            var InitialisePhoneSignInJourneysStr = Request.Query["deployPhoneSignInJourneys"].First();
            bool removeFb = false;
            bool enableJS = false;
            bool initialisePhoneSignInJourneys = false;
            bool.TryParse(removeFbStr, out removeFb);
            bool.TryParse(InitialisePhoneSignInJourneysStr, out initialisePhoneSignInJourneys);
            bool.TryParse(enableJSStr, out enableJS);
            var tenantId = User.Claims.First(c => c.Type == "http://schemas.microsoft.com/identity/claims/tenantid").Value;
            var upn = User.Claims.First(c => c.Type == "preferred_username").Value;
            //var token = await tokenAcquisition.GetAccessTokenOnBehalfOfUserAsync(Constants.Scopes, tenantId);

            var res = await setup.SetupAsync(tenantId, removeFb, dirDomainName, initialisePhoneSignInJourneys, "null", enableJS);
            var model = new SetupState();
            foreach(var item in res)
            {
                model.Items.Add(new ItemSetupState()
                {
                    Name = item.Name,
                    Id = (String.IsNullOrEmpty(item.Id)? "-": item.Id),
                    Status = item.Status == IEFObject.S.Exists? "Exists": item.Status == IEFObject.S.New ? "New" : item.Status == IEFObject.S.Uploaded ? "Uploaded" : item.Status == IEFObject.S.Failed ? "Failed" : item.Status == IEFObject.S.Skipped ? "Skipped" : "Not found",
                    Reason = (String.IsNullOrEmpty(item.Reason) ? "-" : item.Reason)
                });
            }

            string testAppConsentAppId = res.First(kvp => kvp.Name == "IEF Test App Registration").Id;

            model.ConsentUrl = $"https://login.microsoftonline.com/{tenantId}/oauth2/authorize?client_id={res[1].Id}&prompt=admin_consent&response_type=code&nonce=defaultNonce&domain_hint={dirDomainName}.onmicrosoft.com";
            model.AppConsentUrl = $"https://login.microsoftonline.com/{tenantId}/oauth2/authorize?client_id={testAppConsentAppId}&prompt=admin_consent&response_type=code&nonce=defaultNonce&domain_hint={dirDomainName}.onmicrosoft.com";
            model.LaunchUrl = $"https://portal.azure.com/#blade/Microsoft_AAD_B2CAdmin/CustomPoliciesMenuBlade/overview/tenantId/{dirDomainName}.onmicrosoft.com";
            return View(model);
        }

        [AllowAnonymous]
        [ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
        public IActionResult Error()
        {
            return View(new ErrorViewModel { RequestId = Activity.Current?.Id ?? HttpContext.TraceIdentifier });
        }
    }
}

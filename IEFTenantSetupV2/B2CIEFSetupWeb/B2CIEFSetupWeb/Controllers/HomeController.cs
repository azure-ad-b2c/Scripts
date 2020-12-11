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

namespace B2CIEFSetupWeb.Controllers
{
    public class HomeController : Controller
    {
        private readonly ILogger<HomeController> _logger;
        private readonly IAuthenticationService _authenticator;

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
                        { ".redirect", "/home/setup?fb=" + req.RemoveFacebookReferences.ToString() + "&domainName=" + req.DomainName.ToString() }
                    },
                    new Dictionary<string, object>()
                    {
                        {"tenant", req.DomainName },
                        {"RemoveFacebook", req.RemoveFacebookReferences }
                        //{"admin_consent", true }
                    }));
            return View();
        }

        public IActionResult Privacy()
        {
            return View();
        }
        [Authorize]
        public async Task<IActionResult> Setup([FromServices] Utilities.B2CSetup setup, [FromServices] ITokenAcquisition tokenAcquisition)
        {
            var removeFbStr = Request.Query["fb"].First();
            var dirDomainName = Request.Query["domainName"].First();
            bool removeFb = false;
            bool.TryParse(removeFbStr, out removeFb);
            var tenantId = User.Claims.First(c => c.Type == "http://schemas.microsoft.com/identity/claims/tenantid").Value;
            //var token = await tokenAcquisition.GetAccessTokenOnBehalfOfUserAsync(Constants.Scopes, tenantId);

            var res = await setup.SetupAsync(tenantId, removeFb, dirDomainName);
            var model = new SetupState();
            foreach(var item in res)
            {
                model.Items.Add(new ItemSetupState()
                {
                    Name = item.Name,
                    Id = (String.IsNullOrEmpty(item.Id)? "-": item.Id),
                    Status = item.Status == IEFObject.S.Existing? "Existing": item.Status == IEFObject.S.New ? "New" : item.Status == IEFObject.S.Uploaded ? "Uploaded"  : item.Status == IEFObject.S.Skipped ? "Skipped" : "Not found"
                });
            }
            model.ConsentUrl = $"https://login.microsoftonline.com/{tenantId}/oauth2/authorize?client_id={res[1].Id}&prompt=admin_consent&response_type=code&nonce=defaultNonce";
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

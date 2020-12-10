using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.AzureAD.UI;
using Microsoft.AspNetCore.Authentication.OpenIdConnect;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.HttpsPolicy;
using Microsoft.AspNetCore.Mvc.Authorization;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.IdentityModel.Tokens;
using Microsoft.Identity.Web;
using Microsoft.AspNetCore.Http;
using Microsoft.Identity.Web.TokenCacheProviders.Session;
using Microsoft.Identity.Web.TokenCacheProviders.Distributed;
using Microsoft.Identity.Web.TokenCacheProviders.InMemory;

namespace B2CIEFSetupWeb
{
    public class Startup
    {
        public Startup(IConfiguration configuration)
        {
            Configuration = configuration;
        }

        public IConfiguration Configuration { get; }

        // This method gets called by the runtime. Use this method to add services to the container.
        public void ConfigureServices(IServiceCollection services)
        {
            /*services
                .AddDistributedMemoryCache()
                .AddSession(options =>
                {
                    // Set a short timeout for easy testing.
                    //options.IdleTimeout = TimeSpan.FromSeconds(10);
                    options.Cookie.HttpOnly = true;
                    // Make the session cookie essential
                    options.Cookie.IsEssential = true;
                });*/

            services.Configure<CookiePolicyOptions>(options =>
            {
                // This lambda determines whether user consent for non-essential cookies is needed for a given request.
                options.CheckConsentNeeded = context => true;
                options.MinimumSameSitePolicy = SameSiteMode.None; // Unspecified;
                // Handling SameSite cookie according to https://docs.microsoft.com/en-us/aspnet/core/security/samesite?view=aspnetcore-3.1
                options.HandleSameSiteCookieCompatibility();
            });
            services.AddOptions();

            // Sign-in users with the Microsoft identity platform
            services.AddMicrosoftIdentityPlatformAuthentication(Configuration)
               .AddMsal(Configuration, Constants.ReadWriteScopes)
               .AddInMemoryTokenCaches();
            //.AddDistributedTokenCaches()
            //.AddDistributedMemoryCache();
            //.AddSessionPerUserTokenCache();

            services.Configure(AzureADDefaults.OpenIdScheme, (Action<OpenIdConnectOptions>)(options =>
            {
                options.TokenValidationParameters = new TokenValidationParameters
                {
                    // Instead of using the default validation (validating against a single issuer value, as we do in
                    // line of business apps), we inject our own multitenant validation logic
                    ValidateIssuer = false,

                    // If the app is meant to be accessed by entire organizations, add your issuer validation logic here.
                    //IssuerValidator = (issuer, securityToken, validationParameters) => {
                    //    if (myIssuerValidationLogic(issuer)) return issuer;
                    //}
                };
                // Do not override: OnRedirectToIdentityProviderForSignOut or OnAuthorizationCodeReceived - handled in middleware
                options.Events.OnRedirectToIdentityProvider = context =>
                {
                    var tenant = context.Properties.GetParameter<string>("tenant");
                    var readOnly = context.Properties.GetParameter<bool>("readOnly");
                    //var consent = context.Properties.GetParameter<bool>("admin_consent");
                    //if (consent)
                    //    context.ProtocolMessage.IssuerAddress = $"https://login.microsoftonline.com/{tenant}.onmicrosoft.com/v2.0/adminconsent";
                    //else
                        context.ProtocolMessage.IssuerAddress = $"https://login.microsoftonline.com/{tenant}.onmicrosoft.com/oauth2/v2.0/authorize";
                    //context.ProtocolMessage.Parameters.Add("scopes", "test");
                    context.ProtocolMessage.Scope = context.ProtocolMessage.Scope.Replace("offline_access", ""); // not needed
                    //TODO: use StringBuilder
                    if (readOnly)
                    {
                        foreach (var s in Constants.ReadWriteScopes)
                            context.ProtocolMessage.Scope = context.ProtocolMessage.Scope.Replace(s, "");
                        context.ProtocolMessage.Scope += (" " + string.Join(" ", Constants.ReadOnlyScopes));
                    } else
                    {
                        foreach (var s in Constants.ReadOnlyScopes)
                            context.ProtocolMessage.Scope = context.ProtocolMessage.Scope.Replace(s, "");
                        context.ProtocolMessage.Scope += (" " + string.Join(" ", Constants.ReadWriteScopes));
                    }
                    context.ProtocolMessage.State = readOnly.ToString();
                    return Task.CompletedTask;
                };
                options.Events.OnMessageReceived = context =>
                {
                    var readOnly = false;
                    var readOnlyStr = context.ProtocolMessage.State;
                    bool.TryParse(readOnlyStr, out readOnly);
                    UpdateScopes(options.Scope, readOnly);
                    return Task.CompletedTask;
                };
                options.Events.OnTicketReceived = context =>
                {
                    // If your authentication logic is based on users then add your logic here
                    return Task.CompletedTask;
                };
                options.Events.OnAuthenticationFailed = context =>
                {
                    context.Response.Redirect($"/Error?msg={Base64UrlEncoder.Encode(context.Exception.Message)}");
                    context.HandleResponse(); // Suppress the exception
                    return Task.CompletedTask;
                };
                // If your application needs to authenticate single users, add your user validation below.
                options.Events.OnTokenValidated = context =>
                {
                    var id = context.ProtocolMessage.IdToken;
                    return Task.CompletedTask;
                };
            }));

            services.AddTransient<Utilities.B2CSetup>();
            services.AddControllersWithViews(options =>
            {
/*                var policy = new AuthorizationPolicyBuilder()
                    .RequireAuthenticatedUser()
                    .Build();
                options.Filters.Add(new AuthorizeFilter(policy));*/
            });
            services.AddRazorPages();
            services.AddApplicationInsightsTelemetry();
        }

        private static void UpdateScopes(ICollection<string> currScopes, bool readOnly)
        {
            var scopes = currScopes.ToList();
            foreach (var s in scopes)
            {
                if (readOnly)
                {
                    if (Constants.ReadWriteScopes.Contains(s)) currScopes.Remove(s);
                }
                else
                {
                    if (Constants.ReadOnlyScopes.Contains(s)) currScopes.Remove(s);
                }
            }
            foreach (var s in readOnly ? Constants.ReadOnlyScopes : Constants.ReadWriteScopes)
            {
                currScopes.Add(s);
            }
        }

        // This method gets called by the runtime. Use this method to configure the HTTP request pipeline.
        public void Configure(IApplicationBuilder app, IWebHostEnvironment env)
        {
            if (env.IsDevelopment())
            {
                app.UseDeveloperExceptionPage();
            }
            else
            {
                app.UseExceptionHandler("/Home/Error");
                // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
                app.UseHsts();
            }
            app.UseHttpsRedirection();
            app.UseStaticFiles();

            app.UseRouting();

            app.UseAuthentication();
            app.UseAuthorization();

            app.UseEndpoints(endpoints =>
            {
                endpoints.MapControllerRoute(
                    name: "default",
                    pattern: "{controller=Home}/{action=Index}/{id?}");
                endpoints.MapRazorPages();
            });
        }
    }
}

using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace GitRepoManager.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class FetchRepoController : ControllerBase
    {
        // GET: api/FetchRepo
        [HttpGet]
        public async Task<List<String>> GetAsync(string policyName)
        {
            var httpClient = new HttpClient();
            httpClient.DefaultRequestHeaders.UserAgent.Add(
                new ProductInfoHeaderValue("MyApplication", "1"));
            httpClient.DefaultRequestHeaders.Authorization
                        = new AuthenticationHeaderValue("Bearer", " ");
            var repo = "azure-ad-b2c/samples";
            var contentsUrl = $"https://api.github.com/repos/{repo}/contents";
            var resp = await httpClient.GetStringAsync(contentsUrl);
            List < RepoRoot> repoRoot = JsonConvert.DeserializeObject<List<RepoRoot>>(resp);
            RepoRoot policyObject = repoRoot.First(kvp => kvp.Name == "policies");

            // fetch policy folder json
            contentsUrl = policyObject.Url.ToString();
            resp = await httpClient.GetStringAsync(contentsUrl);
            List<Policies> policiesList = JsonConvert.DeserializeObject<List<Policies>>(resp);

            //get specific policy url
            //string policyName = new string("banned-password-list-no-API");
            Policies policies = policiesList.First(kvp => kvp.Name == policyName);

            //fetch specific policy root dir
            contentsUrl = policies.Url.ToString();
            resp = await httpClient.GetStringAsync(contentsUrl);
            List<PolicyRoot> policiesRootList = JsonConvert.DeserializeObject<List<PolicyRoot>>(resp);

            //fetch policy folder inside policy root
            PolicyRoot policyFolder = policiesRootList.First(kvp => kvp.Name == "policy");
            contentsUrl = policyFolder.Url.ToString();
            resp = await httpClient.GetStringAsync(contentsUrl);

            List<PolicyFiles> policiesFilesList = JsonConvert.DeserializeObject<List<PolicyFiles>>(resp);

            // make list of xml download links
            List<string> policyFileLinks = new List<string>();
            foreach (PolicyFiles policy in policiesFilesList)
            {
                policyFileLinks.Add(policy.DownloadUrl.ToString());
            }

            return policyFileLinks;
        }

        // GET: api/FetchRepo/all
        [HttpGet("{id}", Name = "Get")]
        public async Task<List<String>> GetAsync()
        {
            var httpClient = new HttpClient();
            httpClient.DefaultRequestHeaders.UserAgent.Add(
                new ProductInfoHeaderValue("MyApplication", "1"));

            httpClient.DefaultRequestHeaders.Authorization
                         = new AuthenticationHeaderValue("Bearer", " ");
            var repo = "azure-ad-b2c/samples";
            var contentsUrl = $"https://api.github.com/repos/{repo}/contents";
            var resp = await httpClient.GetStringAsync(contentsUrl);
            List<RepoRoot> repoRoot = JsonConvert.DeserializeObject<List<RepoRoot>>(resp);
            RepoRoot policyObject = repoRoot.First(kvp => kvp.Name == "policies");

            // fetch policy folder json
            contentsUrl = policyObject.Url.ToString();
            resp = await httpClient.GetStringAsync(contentsUrl);
            List<Policies> policiesList = JsonConvert.DeserializeObject<List<Policies>>(resp);

            //get specific policy url
            //string policyName = new string("banned-password-list-no-API");
            //Policies policies = policiesList.First(kvp => kvp.Name == policyName);
            List<string> policyNameList = new List<string>();
            foreach (Policies policies in policiesList)
            {
                try
                {
                    string policyName = policies.Name.ToString();
                    policyNameList.Add(policyName.ToString());

                }
                catch { }
            }

            return policyNameList;
        }


    }
}

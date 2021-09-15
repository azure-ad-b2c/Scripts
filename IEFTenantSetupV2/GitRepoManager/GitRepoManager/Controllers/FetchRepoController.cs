using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text.RegularExpressions;
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
                        = new AuthenticationHeaderValue("Bearer", "d6d2c46763a2631eccf7f6e7e7352ddaa3a8e283");
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
        public async Task<string> GetAsync()
        {
            var httpClient = new HttpClient();
            httpClient.DefaultRequestHeaders.UserAgent.Add(
                new ProductInfoHeaderValue("MyApplication", "1"));

            httpClient.DefaultRequestHeaders.Authorization
                         = new AuthenticationHeaderValue("Bearer", "d6d2c46763a2631eccf7f6e7e7352ddaa3a8e283");
            var repo = "azure-ad-b2c/samples";
            var contentsUrl = $"https://api.github.com/repos/{repo}/contents";
            var resp = await httpClient.GetStringAsync(contentsUrl);
            List<RepoRoot> repoRoot = JsonConvert.DeserializeObject<List<RepoRoot>>(resp);
            RepoRoot policyObject = repoRoot.First(kvp => kvp.Name == "policies");

            // fetch policy folder json
            contentsUrl = policyObject.Url.ToString();
            resp = await httpClient.GetStringAsync(contentsUrl);
            List<Policies> policiesList = JsonConvert.DeserializeObject<List<Policies>>(resp);

            var readmeUrl = $"https://raw.githubusercontent.com/azure-ad-b2c/samples/master/readme.md";
            var respReadmeUrl = await httpClient.GetStringAsync(readmeUrl);



            //get specific policy url
            //string policyName = new string("banned-password-list-no-API");
            //Policies policies = policiesList.First(kvp => kvp.Name == policyName);
            //Dictionary<string, string> policyNameList = new Dictionary<string, string>();
            List<policyRow> policyNameList = new List<policyRow>();
            foreach (Policies policies in policiesList)
            {
                try
                {
                    policyRow policyRow = new policyRow();
                    string policyName = policies.Name.ToString();
                    var regex = new Regex(@"\- \[(.*)\]\(policies\/" + policyName + @"\) - (.*)");
                    var match = regex.Match(respReadmeUrl);
                    //policyNameList.Add(policyName.ToString(), match.Groups[2].ToString());
                    policyRow.displayName = match.Groups[1].ToString();
                    policyRow.folderName = policyName;
                    policyRow.description = match.Groups[2].ToString();
                    policyNameList.Add(policyRow);
                }
                catch { }
            }
            var json = JsonConvert.SerializeObject(policyNameList);

            return json;
        }


    }
}

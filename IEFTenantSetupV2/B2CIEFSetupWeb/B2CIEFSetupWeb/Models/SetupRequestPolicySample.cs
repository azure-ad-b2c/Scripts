using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Threading.Tasks;

namespace B2CIEFSetupWeb.Models
{
    public class SetupRequestPolicySample
    {
        

        [Required]
        [MaxLength(256), MinLength(4)]
        [RegularExpression("^([a-zA-Z0-9]+)$", ErrorMessage = "Invalid tenant name")]
        [DisplayName("Your B2C domain name")]
        public string DomainName { get; set; }

        [Required]
        [DisplayName("Sample Folder Name")]
        public string SampleName { get; set; }

        [DisplayName("Possible Sample Values")]
        public List<Samples> SampleValues { get; set; }

        public class Samples
        {
            public string displayName;
            public string folderName;
            public string description;
        }
        public SetupRequestPolicySample()
        {
            SampleValues = new List<Samples>();
            HttpClient httpToRepoAPI = new HttpClient();
            string urlToFetchPolices = "https://gitrepomanager.azurewebsites.net/api/FetchRepo/all"; //https://localhost:44358/api/FetchRepo/all, "https://gitrepomanager.azurewebsites.net/api/FetchRepo/all"
            //string urlToFetchPolices = "https://localhost:44358/api/FetchRepo/all";
            var json = new WebClient().DownloadString(urlToFetchPolices);
            //var value = JArray.Parse(json);
            //var value = JObject.Parse(json);
            //Root myPolicyRows = JsonConvert.DeserializeObject<Root>(json);
            var myPolicyRows = PolicyRow.FromJson(json);
            foreach (var item in myPolicyRows)
            {
                Samples sample = new Samples();
                sample.displayName = item.DisplayName;
                sample.folderName = item.FolderName;
                sample.description = item.Description;
                SampleValues.Add(sample);

            }
        }
    }
}

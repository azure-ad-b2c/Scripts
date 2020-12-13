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
            public string Name;
        }
        public SetupRequestPolicySample()
        {
            SampleValues = new List<Samples>();
            HttpClient httpToRepoAPI = new HttpClient();
            string urlToFetchPolices = "https://-/api/FetchRepo/all";
            var json = new WebClient().DownloadString(urlToFetchPolices);
            var value = JArray.Parse(json);

            foreach (string name in value)
            {
                Samples sample = new Samples();
                sample.Name = name;
                SampleValues.Add(sample);

            }
        }
    }
}

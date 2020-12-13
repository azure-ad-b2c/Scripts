using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace B2CIEFSetupWeb.Models
{
    public class SetupState
    {
        public SetupState()
        {
            Items = new List<ItemSetupState>();
        }
        public string ConsentUrl { get; set; }
        public string AppConsentUrl { get; set; }
        public string LaunchUrl { get; set; }
        public List<ItemSetupState> Items { get; set; }
    }
    public class ItemSetupState
    {
        public string Name;
        public string Id;
        public string Status;
        public string Reason;
    }
}

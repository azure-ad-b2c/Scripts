using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Threading.Tasks;

namespace B2CIEFSetupWeb.Models
{
    public class SetupRequest
    {
        [Required]
        [MaxLength(256), MinLength(4)]
        [RegularExpression("^([a-zA-Z0-9]+)$", ErrorMessage = "Invalid tenant name")]
        [DisplayName("Your B2C domain name")]
        public string DomainName { get; set; }

        [Required]
        [DisplayName("Remove Facebook references")]
        public bool RemoveFacebookReferences { get; set; }
        [Required]
        [DisplayName("Deploy Phone SignIn Journeys")]
        public bool InitialisePhoneSignInJourneys{ get; set; }


        [Required]
        [DisplayName("Enable JavaScript")]
        public bool EnableJavaScript { get; set; }

    }
}

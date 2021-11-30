using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace B2CIEFSetupWeb.Models
{
    using System;
    using System.Collections.Generic;

    using System.Globalization;
    using Newtonsoft.Json;
    using Newtonsoft.Json.Converters;

    public class InnerError
    {
        public string correlationId { get; set; }
        public DateTime date { get; set; }

        [JsonProperty("request-id")]
        public string RequestId { get; set; }

        [JsonProperty("client-request-id")]
        public string ClientRequestId { get; set; }
    }

    public class Error
    {
        public string code { get; set; }
        public string message { get; set; }
        public InnerError innerError { get; set; }
    }

    public class UploadError
    {
        public Error error { get; set; }
    }



}

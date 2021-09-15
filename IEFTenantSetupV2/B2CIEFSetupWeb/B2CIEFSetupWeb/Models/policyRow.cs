namespace B2CIEFSetupWeb.Models
{
    using System;
    using System.Collections.Generic;

    using System.Globalization;
    using Newtonsoft.Json;
    using Newtonsoft.Json.Converters;
    public partial class PolicyRow
    {
        public static PolicyRow[] FromJson(string json) => JsonConvert.DeserializeObject<PolicyRow[]>(json, B2CIEFSetupWeb.Models.Converter.Settings);
    }
    public static class Serialize
    {
        public static string ToJson(this PolicyRow[] self) => JsonConvert.SerializeObject(self, B2CIEFSetupWeb.Models.Converter.Settings);
    }

    internal static class Converter
    {
        public static readonly JsonSerializerSettings Settings = new JsonSerializerSettings
        {
            MetadataPropertyHandling = MetadataPropertyHandling.Ignore,
            DateParseHandling = DateParseHandling.None,
            Converters =
            {
                new IsoDateTimeConverter { DateTimeStyles = DateTimeStyles.AssumeUniversal }
            },
        };
    }
    public partial class PolicyRow
    {
        [JsonProperty("displayName")]
        public string DisplayName { get; set; }

        [JsonProperty("folderName")]
        public string FolderName { get; set; }

        [JsonProperty("description")]
        public string Description { get; set; }
    }
}

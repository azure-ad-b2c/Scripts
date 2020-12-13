namespace GitRepoManager
{
    using System;
    using System.Collections.Generic;

    using System.Globalization;
    using Newtonsoft.Json;
    using Newtonsoft.Json.Converters;

    public partial class PolicyFiles
    {
        [JsonProperty("name")]
        public string Name { get; set; }

        [JsonProperty("path")]
        public string Path { get; set; }

        [JsonProperty("sha")]
        public string Sha { get; set; }

        [JsonProperty("size")]
        public long Size { get; set; }

        [JsonProperty("url")]
        public Uri Url { get; set; }

        [JsonProperty("html_url")]
        public Uri HtmlUrl { get; set; }

        [JsonProperty("git_url")]
        public Uri GitUrl { get; set; }

        [JsonProperty("download_url")]
        public Uri DownloadUrl { get; set; }

        [JsonProperty("type")]
        public string Type { get; set; }

        [JsonProperty("_links")]
        public Links PolicyFilesLinks { get; set; }
    }

    public partial class PolicyFilesLinks
    {
        [JsonProperty("self")]
        public Uri Self { get; set; }

        [JsonProperty("git")]
        public Uri Git { get; set; }

        [JsonProperty("html")]
        public Uri Html { get; set; }
    }
}

using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace B2CIEFSetupWeb
{
    public static class Constants
    {
        public static readonly string[] ReadWriteScopes =
        {
            "TrustFrameworkKeySet.ReadWrite.All", // write keys
            "Policy.ReadWrite.TrustFramework", // write IEF policies
            "Directory.AccessAsUser.All", // to create apps
        };

        public static readonly string[] ReadOnlyScopes =
        {
            "TrustFrameworkKeySet.Read.All",
            "Policy.Read.All",
            "Directory.Read.All"
        };
    }
}

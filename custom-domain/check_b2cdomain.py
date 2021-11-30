"""
    This includes necessary functions for CLI and Main.
"""

import argparse
import pydig
import requests
import json
import logging as log

################################################################################### 
#       Simple python script to check custom domain settings b/w AFD & Azure AD B2C
################################################################################### 
# Install instructions: 
#       https://github.com/azure-ad-b2c/Scripts/blob/master/custom-domain/readme.md
# Further reading: 
#       https://docs.microsoft.com/en-us/azure/active-directory-b2c/custom-domain
# Usage:
#       $ python check_b2cdomain.py -h  
#       $ python check_b2cdomain.py -custom-domain "accountuat.contosobank.co.uk" -policy "b2c_1_susi"
#       $ python check_b2cdomain.py -custom-domain "accountuat.contosobank.co.uk" -policy "b2c_1_susi" --verbose

welcome = """\
   ____          _                    ____                        _          ____ _               _             
  / ___|   _ ___| |_ ___  _ __ ___   |  _ \  ___  _ __ ___   __ _(_)_ __    / ___| |__   ___  ___| | _____ _ __ 
 | |  | | | / __| __/ _ \| '_ ` _ \  | | | |/ _ \| '_ ` _ \ / _` | | '_ \  | |   | '_ \ / _ \/ __| |/ / _ \ '__|
 | |__| |_| \__ \ || (_) | | | | | | | |_| | (_) | | | | | | (_| | | | | | | |___| | | |  __/ (__|   <  __/ |   
  \____\__,_|___/\__\___/|_| |_| |_| |____/ \___/|_| |_| |_|\__,_|_|_| |_|  \____|_| |_|\___|\___|_|\_\___|_| 

           _    _____ ____               _                             _    ____    ____ ____   ____ 
          / \  |  ___|  _ \     _       / \    _____   _ _ __ ___     / \  |  _ \  | __ )___ \ / ___|
         / _ \ | |_  | | | |  _| |_    / _ \  |_  / | | | '__/ _ \   / _ \ | | | | |  _ \ __) | |    
        / ___ \|  _| | |_| | |_   _|  / ___ \  / /| |_| | | |  __/  / ___ \| |_| | | |_) / __/| |___ 
       /_/   \_\_|   |____/    |_|   /_/   \_\/___|\__,_|_|  \___| /_/   \_\____/  |____/_____|\____|
"""
print(welcome)

parser = argparse.ArgumentParser(description="🚀 Simple script to check custom domain settings b/w AFD & Azure AD B2C", epilog="""example: check_b2cdomain.py  -custom-domain 'login.contoso.com' -policy 'b2c_1_susi'""")
optional = parser._action_groups.pop()
required = parser.add_argument_group('required arguments')
parser._action_groups.append(optional)
required.add_argument('-custom-domain', type=str, required=True,help='Custom domain (e.g. login.contoso.com)')
required.add_argument('-policy', type=str, required=True,help='Azure AD B2C policy (e.g. B2C_1_SUSI)')
optional.add_argument('-v', '--verbose', help="Be verbose",action="store_const", dest="loglevel", const=log.INFO)

def get_customdomain_info(domain):
    dig_result = pydig.query(domain,'A')
    try:
        dig_result = pydig.query(domain,'A')
        log.info(dig_result)
        for value in dig_result:
            log.info(value)
            if "azurefd.net." in value:
             return value
    except Exception as e:
        log.info(e)
    return ""

def get_JSON(response):
    try:
        response_json =  response.json()
        log.info(response_json)
        return response_json
    except Exception as e:
        log.info(e)
    return ""
    
def get_b2cinformation(b2c_wellknown_endpoint,custom_header):
    try:
        response = requests.get(b2c_wellknown_endpoint, headers= custom_header)
        log.info(response)
        return response
    except Exception as e:
        log.info(e)
    return ""

def main_interaction(args):
    custom_domain = args.custom_domain
    policy = args.policy

    #  python3 check_b2cdomain.py  -custom-domain 'accountuat.contosobank.co.uk' -tenant-name 'contosobankuat.onmicrosoft.com'  -policy 'b2c_1_susi'
    #https://docs.microsoft.com/en-us/azure/frontdoor/front-door-http-headers-protocol
    custom_header = {"X-Azure-DebugInfo": "1"}
    b2c_wellknown_endpoint = f'https://{custom_domain}/{custom_domain}/v2.0/.well-known/openid-configuration?p={policy}'
    
    print(f'⏳ Searching AFD mapping for domain: [{custom_domain}]')
    dig_result = get_customdomain_info(custom_domain)
    if dig_result:
        print(f'💯 FOUND! [{custom_domain}] is mapped to AFD [{dig_result}]')
    else:
        print(f'❓ Bummer! Cannot locate AFD information publicly. Hint: Is domain [{custom_domain}] using some type of WAF? Try running command with --verbose switch to view all DNS entries against this domain.')
    
    print(f'⏳ Connecting to Azure AD B2C endpoint [{b2c_wellknown_endpoint}]')
    
    response =  get_b2cinformation(b2c_wellknown_endpoint, custom_header)
    tenant_id = ""
    afd_header_found = False
    afd_header_origin_status = False
    b2c_tenant_found= False
    if response != "" and response.status_code == 200:
        response_json =  get_JSON(response)
        if response:
            for key, value in response_json.items():
                    log.info(f'{key}, :, {value}')
                    if key.lower() == "jwks_uri":
                        val = value.lower().split('/')
                        if val[2] == custom_domain.lower():
                            b2c_tenant_found = True
                    if key.lower() == "issuer":
                            tenant_id = val = value.lower().split('/')[3]

            response_headers = response.headers
            for item in response_headers.items():
                    log.info(f'{item[0]}, :, {item[1]}')
                    if item[0].lower() == "x-azure-ref":
                        afd_header_found = True   
                    if item[0].lower() == "x-azure-originstatuscode":
                        afd_header_origin_status = item[1]
    else:
            print(f'💔 Bummer! Connection to Azure AD B2C endpoint [{b2c_wellknown_endpoint}] failed. Run command with --verbose to see more details.')

    is_success = False
    if b2c_tenant_found and afd_header_found:
            print(f'💯 FOUND! [{custom_domain}] is configured for Azure AD B2C tenant [{tenant_id}]')
            print(f'   ✅ AFD Header [X-Azure-Ref] found. Response came through AFD! ')
            if afd_header_origin_status == "200":
                print(f'   ✅ AFD Header [X-Azure-OriginStatusCode] found with HTTP code 200! All good on the connection side from AFD --> Azure AD B2C.')
                is_success = True
            else:
                print(f'   💔 AFD Header [X-Azure-OriginStatusCode] is missing or value is not within normal range ! This is a symptom of backend calls from AFD --> Azure AD may be having issues. Run command with --verbose to see more details.')
    else:
        print(f'🛑 Verdict: Custom domain [{custom_domain}] seems to be not configured yet for AFD/Azure AD B2C.')
        print(f'    🔧 Hint: Check if this domain is using 3rd party WAF as it may be blocking request to AFD (think CAPTCHA etc.)')
        print(f'    🔧 Check troubleshooting section: [https://docs.microsoft.com/en-us/azure/active-directory-b2c/custom-domain?pivots=b2c-custom-policy#troubleshooting]')

    if is_success:
        print(f'🚀 Yay! Domain [{custom_domain}] is configured correctly for AFD & Azure AD B2C usage! [All Good ✅ ]')
    return 

def main():
    """
    Main function of the script
    :return: void
    """
    args = parser.parse_args()    
    
    log.basicConfig(level=args.loglevel)
    main_interaction(args)

if __name__ == "__main__":
    main()

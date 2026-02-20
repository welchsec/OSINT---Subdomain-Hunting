# OSINT---Subdomain-Hunting
**Use At Own Risk** - this was built using an idea of finding subdomains utillizing Claude. 


      -=(o '.
         '.-.\
         /|  \\
         '|  ||
          _\_):,_

**How to run:**

PowerShell -ExecutionPolicy Bypass -File .\subdomain_lookup.ps1

Enter domain to look up (e.g. example.com): tesla.com

Looking up subdomains for: tesla.com
Querying all sources in parallel, please wait...
-----------------------------------

Source Summary:
  [-] crt.sh: Failed - The remote server returned an error: (502) Bad Gateway.
  [+] HackerTarget: 51 result(s)
  [-] AlienVault OTX: Failed - The remote server returned an error: (429) Too Many Requests.

51 unique subdomain(s) found (all sources combined):

[![Build Status](https://jenkins1.ugent.be/job/AII/badge/icon)](https://jenkins1.ugent.be/job/AII/)

AII is the automated installation infrastructure.

If you are serving host profiles and kickstart files with Apache httpd, access to can be restricted with the a config based on the following.
This approach is obviously better than nothing, but is not a substitute for use of x509 certificates and/or Kerberos should you require secrets to be distributed in the profiles.

```apacheconf
# Use Aliases or set DocumentRoot
Alias /profiles /var/quattor/web/htdocs/profiles
Alias /kickstart /var/quattor/web/htdocs/kickstart

<location /profiles>
  Require all granted
</location>

HostnameLookups Double

RewriteEngine On
# The following ACL map can be used to specify hosts which can access all profiles
RewriteMap ACLmap txt:/var/quattor/web/ACLmap.txt

# Redirect every profile request to HTTPS
RewriteCond %{HTTPS} !=on
RewriteRule  ^/profiles/(.*)$ https://%{HTTP_HOST}/profiles/$1 [L]

# Serve only the profile corresponding to the remote host if the host is not part of the ACLmap
RewriteCond ${ACLmap:%{REMOTE_HOST}|NO} NO
RewriteRule  ^/profiles/.*\.(xml|json)(\.gz)?$ /var/quattor/web/htdocs/profiles/%{REMOTE_HOST}.$1$2 [L]

# Serve only the kickstart corresponding to the remote host if the host is not part of the ACLmap
RewriteCond ${ACLmap:%{REMOTE_HOST}|NO} NO
RewriteRule  ^/kickstart/.*\.ks$ /var/quattor/web/htdocs/kickstart/%{REMOTE_HOST}.ks [L]
```

`/var/quattor/web/ACLmap.txt` can be used as followed to specify hosts that should be able to access all profiles/kickstarts, for example:
```
quattor-deploy.example.org ok
```
The key (first column) being the hostname, the value (second-column) must be present, but is not used by the above rules.


If your AII server and Profile server are on the same host, you do not need the ACL map for that host and can instead specify the local filesystem path as the CDB URL in `aii-shellfe.conf`:
```
cdburl = dir:///var/quattor/...
```

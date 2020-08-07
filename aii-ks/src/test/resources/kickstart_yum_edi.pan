@{
Profile to test enable/disable/ignore repos
@}
object template kickstart_yum_edi;

include 'kickstart';

prefix "/system/aii/osinstall/ks";
"enabled_repos" = list("disable*not");
"disabled_repos" = list("disable*");
"ignored_repos" = list("repo1");

prefix "/software/repositories/2";
"name" = "disable_me";
"enabled" = true;
"owner" = "me@example.com";
"protocols/0/name" = "http";
"protocols/0/url" = "http://www.example.com";

prefix "/software/repositories/3";
"name" = "disable_me_not";
"enabled" = false;
"owner" = "me@example.com";
"protocols/0/name" = "http";
"protocols/0/url" = "http://www.example.com";

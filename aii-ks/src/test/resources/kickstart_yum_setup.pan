@{
Profile to ensure that the kickstart yum setup section is generated
@}
object template kickstart_yum_setup;

include 'kickstart';

prefix "/software/repositories/0";
"name" = "repo0";
"owner" = "me@example.com";
"protocols/0/name" = "http";
"protocols/0/url" = "http://www.example.com";

prefix "/software/repositories/1";
"name" = "repo1";
"owner" = "me@example.com";
"protocols/0/name" = "http";
"protocols/0/url" = "http://www.example.com";
"excludepkgs" = list('woo', 'hoo*');
"includepkgs" = list('everything', 'else');

@{
Profile to ensure that the kickstart quattor section is generated
@}
object template kickstart_quattor;

include 'kickstart';

prefix "/software/components/ccm";
"trust" = "MY@TRUST";
"group_readable" = "mygroup";
"world_readable" = 0;
"key_file" = "/path/to/key";
"cert_file" = "/path/to/cert";
"ca_file" = "/path/to/ca";
"dbformat" = "myformat";
"cache_root" = "/path/to/cache";
"force" = false;
"get_timeout" = 30;
"tabcompletion" = true;
"json_typed" = true;
"active" = true;
"version" = "1.2.3";
"profile" = "https://other.profile";

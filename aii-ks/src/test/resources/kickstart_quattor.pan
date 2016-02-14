@{
Profile to ensure that the kickstart quattor section is generated
@}
object template kickstart_quattor;

include 'kickstart';

prefix "/software/components/ccm";
"trust" = "MY@TRUST";
"world_readable" = 0;
"key_file" = "/path/to/key";
"cert_file" = "/path/to/cert";
"ca_file" = "/path/to/ca";
"dbformat" = "myformat";

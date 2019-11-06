@{ 
Profile to ensure that the kickstart commands and packages section are generated 
@}
object template kickstart_commands;

include 'kickstart';

prefix "/system/aii/osinstall/ks";
"repo/0" = "someurl";
"repo/1" = "@po1";  # should match repo1, not repo0

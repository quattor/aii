@{
Profile to ensure that the kickstart commands and packages section are generated
@}
object template kickstart_commands_glob;

include 'kickstart';

prefix "/system/aii/osinstall/ks";
"installtype" = "url @*epo0@/some/extra/whatever --noverifyssl";
"repo/0" = "someurl";
"repo/1" = "--abc=def @*po1*@/weird --other=option";  # should match repo1, not repo0

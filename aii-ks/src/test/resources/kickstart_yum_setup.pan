@{
Profile to ensure that the kickstart yum setup section is generated
@}
object template kickstart_yum_setup;

include 'kickstart';

prefix "/software/components/spma/main_options";
"exclude" = list("a", "b");
"retries" = 40;

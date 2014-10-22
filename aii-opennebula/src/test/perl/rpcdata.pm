# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}
=pod
=head1 rpcdata module
This module provides raw rpc data (output and exit code)
More info about ONE RPC-XML client:
http://docs.opennebula.org/4.4/integration/system_interfaces/api.html
and OpenNebula Perl module:
https://github.com/stdweird/p5-net-opennebula
=cut
package rpcdata;

use strict;
use warnings;
use XML::Simple;


our %cmds;
my $data;

# System
$cmds{rpc_one_version}{params} = [];
$cmds{rpc_one_version}{method} = "one.system.version";
$cmds{rpc_one_version}{out} = 5;

# Manage users

$cmds{rpc_create_newuser}{params} = ["lsimngar", "my_fancy_pass", "core"];
$cmds{rpc_create_newuser}{method} = "one.user.allocate";
$cmds{rpc_create_newuser}{out} = 3;

$cmds{rpc_create_newuser2}{params} = ["stdweird", "another_fancy_pass", "core"];
$cmds{rpc_create_newuser2}{method} = "one.user.allocate";
$cmds{rpc_create_newuser2}{out} = 4;

$cmds{rpc_delete_user}{params} = [3];
$cmds{rpc_delete_user}{method} = "one.user.delete";
$cmds{rpc_delete_user}{out} = 3;

$cmds{rpc_delete_user2}{params} = [4];
$cmds{rpc_delete_user2}{method} = "one.user.delete";
$cmds{rpc_delete_user2}{out} = 4;

$cmds{rpc_list_userspool}{params} = [];
$cmds{rpc_list_userspool}{method} = "one.userpool.info";
$cmds{rpc_list_userspool}{out} = <<'EOF';
<USER_POOL><USER><ID>0</ID><GID>0</GID><GROUPS><ID>0</ID></GROUPS><GNAME>oneadmin</GNAME><NAME>oneadmin</NAME><PASSWORD>98cxxfd8cd945cceb90f54ca2532b0fd6382db5b</PASSWORD><AUTH_DRIVER>core</AUTH_DRIVER><ENABLED>1</ENABLED><TEMPLATE><TOKEN_PASSWORD><![CDATA[8730b37913b4fad8ed06d6d248b5c51222790f36]]></TOKEN_PASSWORD></TEMPLATE></USER><QUOTAS><ID>0</ID><DATASTORE_QUOTA></DATASTORE_QUOTA><NETWORK_QUOTA></NETWORK_QUOTA><VM_QUOTA></VM_QUOTA><IMAGE_QUOTA></IMAGE_QUOTA></QUOTAS><USER><ID>1</ID><GID>0</GID><GROUPS><ID>0</ID></GROUPS><GNAME>oneadmin</GNAME><NAME>serveradmin</NAME><PASSWORD>3f5013xxa0354dc79cd5c4998eec39b457595724</PASSWORD><AUTH_DRIVER>server_cipher</AUTH_DRIVER><ENABLED>1</ENABLED><TEMPLATE><TOKEN_PASSWORD><![CDATA[205ca1e04934df2ac448b5e693f6aca567a5e450]]></TOKEN_PASSWORD></TEMPLATE></USER><QUOTAS><ID>1</ID><DATASTORE_QUOTA></DATASTORE_QUOTA><NETWORK_QUOTA></NETWORK_QUOTA><VM_QUOTA></VM_QUOTA><IMAGE_QUOTA></IMAGE_QUOTA></QUOTAS><USER><ID>3</ID><GID>1</GID><GROUPS><ID>1</ID></GROUPS><GNAME>users</GNAME><NAME>lsimngar</NAME><PASSWORD>ce29b9cb50f446a532203d8f66f59f63e259b5df</PASSWORD><AUTH_DRIVER>core</AUTH_DRIVER><ENABLED>1</ENABLED><TEMPLATE><QUATTOR><![CDATA[1]]></QUATTOR><TOKEN_PASSWORD><![CDATA[7b82ecfa1339d585df91ddb38c64c7ec8b7c9e6d]]></TOKEN_PASSWORD></TEMPLATE></USER><QUOTAS><ID>3</ID><DATASTORE_QUOTA></DATASTORE_QUOTA><NETWORK_QUOTA></NETWORK_QUOTA><VM_QUOTA></VM_QUOTA><IMAGE_QUOTA></IMAGE_QUOTA></QUOTAS></USER_POOL>
EOF

$cmds{rpc_list_user}{params} = [3];
$cmds{rpc_list_user}{method} = "one.user.info";
$cmds{rpc_list_user}{out} = <<'EOF';
<USER><ID>3</ID><GID>1</GID><GROUPS><ID>1</ID></GROUPS><GNAME>users</GNAME><NAME>lsimngar</NAME><PASSWORD>ce29b9cb50f446a532203d8f66f59f63e259b5df</PASSWORD><AUTH_DRIVER>core</AUTH_DRIVER><ENABLED>1</ENABLED><TEMPLATE><TOKEN_PASSWORD><![CDATA[4a782c2aec2b95bf97701d4a57f7cc9032d7331b]]></TOKEN_PASSWORD></TEMPLATE><DATASTORE_QUOTA></DATASTORE_QUOTA><NETWORK_QUOTA></NETWORK_QUOTA><VM_QUOTA></VM_QUOTA><IMAGE_QUOTA></IMAGE_QUOTA><DEFAULT_USER_QUOTAS><DATASTORE_QUOTA></DATASTORE_QUOTA><NETWORK_QUOTA></NETWORK_QUOTA><VM_QUOTA></VM_QUOTA><IMAGE_QUOTA></IMAGE_QUOTA></DEFAULT_USER_QUOTAS></USER>
EOF

$cmds{rpc_list_user2}{params} = [4];
$cmds{rpc_list_user2}{method} = "one.user.info";
$cmds{rpc_list_user2}{out} = <<'EOF';
<USER><ID>4</ID><GID>1</GID><GROUPS><ID>1</ID></GROUPS><GNAME>users</GNAME><NAME>stdweird</NAME><PASSWORD>954f663ba92466ccdc74a605f975904f59682dbc</PASSWORD><AUTH_DRIVER>core</AUTH_DRIVER><ENABLED>1</ENABLED><TEMPLATE><TOKEN_PASSWORD><![CDATA[4a782c2aec2b95bf97701d4a57f7cc9032d7331b]]></TOKEN_PASSWORD></TEMPLATE><DATASTORE_QUOTA></DATASTORE_QUOTA><NETWORK_QUOTA></NETWORK_QUOTA><VM_QUOTA></VM_QUOTA><IMAGE_QUOTA></IMAGE_QUOTA><DEFAULT_USER_QUOTAS><DATASTORE_QUOTA></DATASTORE_QUOTA><NETWORK_QUOTA></NETWORK_QUOTA><VM_QUOTA></VM_QUOTA><IMAGE_QUOTA></IMAGE_QUOTA></DEFAULT_USER_QUOTAS></USER>
EOF

$cmds{rpc_list_user3}{params} = [0];
$cmds{rpc_list_user3}{method} = "one.user.info";
$cmds{rpc_list_user3}{out} = <<'EOF';
<USER><ID>0</ID><GID>0</GID><GROUPS><ID>0</ID></GROUPS><GNAME>oneadmin</GNAME><NAME>oneadmin</NAME><PASSWORD>98cxxfd8cd945cceb90f54ca2532b0fd6382db5b</PASSWORD><AUTH_DRIVER>core</AUTH_DRIVER><ENABLED>1</ENABLED><TEMPLATE><TOKEN_PASSWORD><![CDATA[8730b37913b4fad8ed06d6d248b5c51222790f36]]></TOKEN_PASSWORD></TEMPLATE><DATASTORE_QUOTA></DATASTORE_QUOTA><NETWORK_QUOTA></NETWORK_QUOTA><VM_QUOTA></VM_QUOTA><IMAGE_QUOTA></IMAGE_QUOTA><DEFAULT_USER_QUOTAS><DATASTORE_QUOTA></DATASTORE_QUOTA><NETWORK_QUOTA></NETWORK_QUOTA><VM_QUOTA></VM_QUOTA><IMAGE_QUOTA></IMAGE_QUOTA></DEFAULT_USER_QUOTAS></USER>
EOF

$cmds{rpc_list_user4}{params} = [1];
$cmds{rpc_list_user4}{method} = "one.user.info";
$cmds{rpc_list_user4}{out} = <<'EOF';
<USER><ID>1</ID><GID>0</GID><GROUPS><ID>0</ID></GROUPS><GNAME>oneadmin</GNAME><NAME>serveradmin</NAME><PASSWORD>3f5013xxa0354dc79cd5c4998eec39b457595724</PASSWORD><AUTH_DRIVER>server_cipher</AUTH_DRIVER><ENABLED>1</ENABLED><TEMPLATE><TOKEN_PASSWORD><![CDATA[205ca1e04934df2ac448b5e693f6aca567a5e450]]></TOKEN_PASSWORD></TEMPLATE><DATASTORE_QUOTA></DATASTORE_QUOTA><NETWORK_QUOTA></NETWORK_QUOTA><VM_QUOTA></VM_QUOTA><IMAGE_QUOTA></IMAGE_QUOTA><DEFAULT_USER_QUOTAS><DATASTORE_QUOTA></DATASTORE_QUOTA><NETWORK_QUOTA></NETWORK_QUOTA><VM_QUOTA></VM_QUOTA><IMAGE_QUOTA></IMAGE_QUOTA></DEFAULT_USER_QUOTAS></USER>
EOF

# Manage VNETs

$data = <<'EOF';
BRIDGE = "br100"
DNS = "10.141.3.250"
GATEWAY = "10.141.3.250"
NAME = "altaria.os"
NETWORK_MASK = "255.255.0.0"
TYPE = "FIXED"
QUATTOR = 1
EOF
$cmds{rpc_create_newvnet}{params} = [$data, -1];
$cmds{rpc_create_newvnet}{method} = "one.vn.allocate";
$cmds{rpc_create_newvnet}{out} = 68;

$data = <<'EOF';
BRIDGE = "br101"
DNS = "10.141.3.250"
GATEWAY = "10.141.3.250"
NAME = "altaria.vsc"
NETWORK_MASK = "255.255.0.0"
TYPE = "FIXED"
QUATTOR = 1
EOF
$cmds{rpc_create_newvnet2}{params} = [$data, -1];
$cmds{rpc_create_newvnet2}{method} = "one.vn.allocate";
$cmds{rpc_create_newvnet2}{out} = 88;

$cmds{rpc_delete_vnet}{params} = [68];
$cmds{rpc_delete_vnet}{method} = "one.vn.delete";
$cmds{rpc_delete_vnet}{out} = 68;

$cmds{rpc_delete_vnet2}{params} = [88];
$cmds{rpc_delete_vnet2}{method} = "one.vn.delete";
$cmds{rpc_delete_vnet2}{out} = 88;

$cmds{rpc_list_vnetspool}{params} = [-2, -1, -1];
$cmds{rpc_list_vnetspool}{method} = "one.vnpool.info";
$cmds{rpc_list_vnetspool}{out} = <<'EOF';
<VNET_POOL><VNET><ID>0</ID><UID>0</UID><GID>0</GID><UNAME>oneadmin</UNAME><GNAME>oneadmin</GNAME><NAME>altaria.os</NAME><PERMISSIONS><OWNER_U>1</OWNER_U><OWNER_M>1</OWNER_M><OWNER_A>0</OWNER_A><GROUP_U>0</GROUP_U><GROUP_M>0</GROUP_M><GROUP_A>0</GROUP_A><OTHER_U>0</OTHER_U><OTHER_M>0</OTHER_M><OTHER_A>0</OTHER_A></PERMISSIONS><CLUSTER_ID>-1</CLUSTER_ID><CLUSTER/><BRIDGE>br100</BRIDGE><VLAN>0</VLAN><PARENT_NETWORK_ID/><PHYDEV/><VLAN_ID/><USED_LEASES>1</USED_LEASES><TEMPLATE><BRIDGE><![CDATA[br100]]></BRIDGE><DNS><![CDATA[10.141.3.250]]></DNS><GATEWAY><![CDATA[10.141.3.250]]></GATEWAY><NAME><![CDATA[altaria.os]]></NAME><NETWORK_MASK><![CDATA[255.255.0.0]]></NETWORK_MASK><PHYDEV><![CDATA[]]></PHYDEV><QUATTOR><![CDATA[1]]></QUATTOR><TYPE><![CDATA[FIXED]]></TYPE><VLAN><![CDATA[NO]]></VLAN><VLAN_ID><![CDATA[]]></VLAN_ID></TEMPLATE><AR_POOL><AR><ALLOCATED><![CDATA[068719476737]]></ALLOCATED><AR_ID><![CDATA[0]]></AR_ID><GLOBAL_PREFIX/><HOSTNAME><![CDATA[node630.cubone.os]]></HOSTNAME><IP><![CDATA[10.141.8.30]]></IP><MAC><![CDATA[AA:00:00:80:01:00]]></MAC><QUATTOR><![CDATA[1]]></QUATTOR><SIZE><![CDATA[1]]></SIZE><TYPE><![CDATA[IP4]]></TYPE><ULA_PREFIX/></AR></AR_POOL></VNET><VNET><ID>2</ID><UID>0</UID><GID>0</GID><UNAME>oneadmin</UNAME><GNAME>oneadmin</GNAME><NAME>altaria.vsc</NAME><PERMISSIONS><OWNER_U>1</OWNER_U><OWNER_M>1</OWNER_M><OWNER_A>0</OWNER_A><GROUP_U>0</GROUP_U><GROUP_M>0</GROUP_M><GROUP_A>0</GROUP_A><OTHER_U>0</OTHER_U><OTHER_M>0</OTHER_M><OTHER_A>0</OTHER_A></PERMISSIONS><CLUSTER_ID>-1</CLUSTER_ID><CLUSTER/><BRIDGE>br101</BRIDGE><VLAN>0</VLAN><PARENT_NETWORK_ID/><PHYDEV/><VLAN_ID/><USED_LEASES>1</USED_LEASES><TEMPLATE><BRIDGE><![CDATA[br101]]></BRIDGE><DNS><![CDATA[10.141.3.250]]></DNS><GATEWAY><![CDATA[10.141.3.250]]></GATEWAY><NETWORK_MASK><![CDATA[255.255.0.0]]></NETWORK_MASK><PHYDEV><![CDATA[]]></PHYDEV><QUATTOR><![CDATA[1]]></QUATTOR><TYPE><![CDATA[FIXED]]></TYPE><VLAN><![CDATA[NO]]></VLAN><VLAN_ID><![CDATA[]]></VLAN_ID></TEMPLATE><AR_POOL><AR><ALLOCATED><![CDATA[068719476737]]></ALLOCATED><AR_ID><![CDATA[0]]></AR_ID><GLOBAL_PREFIX/><HOSTNAME><![CDATA[node630.cubone.os]]></HOSTNAME><IP><![CDATA[172.24.8.30]]></IP><MAC><![CDATA[AA:00:00:80:01:01]]></MAC><QUATTOR><![CDATA[1]]></QUATTOR><SIZE><![CDATA[1]]></SIZE><TYPE><![CDATA[IP4]]></TYPE><ULA_PREFIX/></AR></AR_POOL></VNET></VNET_POOL>
EOF

$cmds{rpc_list_vnet2}{params} = [2];
$cmds{rpc_list_vnet2}{method} = "one.vn.info";
$cmds{rpc_list_vnet2}{out} = <<'EOF';
<VNET><ID>2</ID><UID>0</UID><GID>0</GID><UNAME>oneadmin</UNAME><GNAME>oneadmin</GNAME><NAME>altaria.vsc</NAME><PERMISSIONS><OWNER_U>1</OWNER_U><OWNER_M>1</OWNER_M><OWNER_A>0</OWNER_A><GROUP_U>0</GROUP_U><GROUP_M>0</GROUP_M><GROUP_A>0</GROUP_A><OTHER_U>0</OTHER_U><OTHER_M>0</OTHER_M><OTHER_A>0</OTHER_A></PERMISSIONS><CLUSTER_ID>-1</CLUSTER_ID><CLUSTER/><BRIDGE>br101</BRIDGE><VLAN>0</VLAN><PARENT_NETWORK_ID/><PHYDEV/><VLAN_ID/><USED_LEASES>1</USED_LEASES><TEMPLATE><BRIDGE><![CDATA[br101]]></BRIDGE><DNS><![CDATA[10.141.3.250]]></DNS><GATEWAY><![CDATA[10.141.3.250]]></GATEWAY><NETWORK_MASK><![CDATA[255.255.0.0]]></NETWORK_MASK><PHYDEV><![CDATA[]]></PHYDEV><QUATTOR><![CDATA[1]]></QUATTOR><TYPE><![CDATA[FIXED]]></TYPE><VLAN><![CDATA[NO]]></VLAN><VLAN_ID><![CDATA[]]></VLAN_ID></TEMPLATE><AR_POOL><AR><AR_ID><![CDATA[0]]></AR_ID><GLOBAL_PREFIX><![CDATA[]]></GLOBAL_PREFIX><HOSTNAME><![CDATA[node630.cubone.os]]></HOSTNAME><IP><![CDATA[172.24.14.1]]></IP><MAC><![CDATA[AA:01:00:80:02:03]]></MAC><QUATTOR><![CDATA[1]]></QUATTOR><SIZE><![CDATA[1]]></SIZE><TYPE><![CDATA[IP4]]></TYPE><ULA_PREFIX><![CDATA[]]></ULA_PREFIX><USED_LEASES>1</USED_LEASES><LEASES><LEASE><IP><![CDATA[172.24.8.30]]></IP><MAC><![CDATA[AA:00:00:80:01:01]]></MAC><VM><![CDATA[1]]></VM></LEASE></LEASES></AR></AR_POOL></VNET>
EOF

$cmds{rpc_list_vnet3}{params} = [0];
$cmds{rpc_list_vnet3}{method} = "one.vn.info";
$cmds{rpc_list_vnet3}{out} = <<'EOF';
<VNET><ID>0</ID><UID>0</UID><GID>0</GID><UNAME>oneadmin</UNAME><GNAME>oneadmin</GNAME><NAME>altaria.os</NAME><PERMISSIONS><OWNER_U>1</OWNER_U><OWNER_M>1</OWNER_M><OWNER_A>0</OWNER_A><GROUP_U>0</GROUP_U><GROUP_M>0</GROUP_M><GROUP_A>0</GROUP_A><OTHER_U>0</OTHER_U><OTHER_M>0</OTHER_M><OTHER_A>0</OTHER_A></PERMISSIONS><CLUSTER_ID>-1</CLUSTER_ID><CLUSTER/><BRIDGE>br100</BRIDGE><VLAN>0</VLAN><PARENT_NETWORK_ID/><PHYDEV/><VLAN_ID/><USED_LEASES>1</USED_LEASES><TEMPLATE><BRIDGE><![CDATA[br100]]></BRIDGE><DNS><![CDATA[10.141.3.250]]></DNS><GATEWAY><![CDATA[10.141.3.250]]></GATEWAY><NAME><![CDATA[altaria.os]]></NAME><NETWORK_MASK><![CDATA[255.255.0.0]]></NETWORK_MASK><PHYDEV><![CDATA[]]></PHYDEV><QUATTOR><![CDATA[1]]></QUATTOR><TYPE><![CDATA[FIXED]]></TYPE><VLAN><![CDATA[NO]]></VLAN><VLAN_ID><![CDATA[]]></VLAN_ID></TEMPLATE><AR_POOL><AR><AR_ID><![CDATA[0]]></AR_ID><GLOBAL_PREFIX><![CDATA[]]></GLOBAL_PREFIX><HOSTNAME><![CDATA[node630.cubone.os]]></HOSTNAME><IP><![CDATA[10.141.8.30]]></IP><MAC><![CDATA[AA:00:00:80:01:00]]></MAC><QUATTOR><![CDATA[1]]></QUATTOR><SIZE><![CDATA[1]]></SIZE><TYPE><![CDATA[IP4]]></TYPE><ULA_PREFIX><![CDATA[]]></ULA_PREFIX><USED_LEASES>1</USED_LEASES><LEASES><LEASE><IP><![CDATA[10.141.8.30]]></IP><MAC><![CDATA[AA:00:00:80:01:00]]></MAC><VM><![CDATA[1]]></VM></LEASE></LEASES></AR></AR_POOL></VNET>
EOF

$data = <<'EOF';

AR = [
    TYPE = "IP4",
    IP = "172.24.8.30",
    MAC = "AA:00:00:80:01:01",
    QUATTOR = "1",
    HOSTNAME = "node630.cubone.os",
    SIZE = "1"
]
EOF
$cmds{rpc_create_vnet_ar}{params} = [2, $data];
$cmds{rpc_create_vnet_ar}{method} = "one.vn.add_ar";
$cmds{rpc_create_vnet_ar}{out} = 0;

$cmds{rpc_update_vnet_ar}{params} = [2, $data];
$cmds{rpc_update_vnet_ar}{method} = "one.vn.update_ar";
$cmds{rpc_update_vnet_ar}{out} = 0;


$data = <<'EOF';

AR = [
    TYPE = "IP4",
    IP = "10.141.8.30",
    MAC = "AA:00:00:80:01:00",
    QUATTOR = "1",
    HOSTNAME = "node630.cubone.os",
    SIZE = "1"
]
EOF
$cmds{rpc_create_vnet_ar2}{params} = [0, $data];
$cmds{rpc_create_vnet_ar2}{method} = "one.vn.add_ar";
$cmds{rpc_create_vnet_ar2}{out} = 0;

$cmds{rpc_update_vnet_ar2}{params} = [0, $data];
$cmds{rpc_update_vnet_ar2}{method} = "one.vn.update_ar";
$cmds{rpc_update_vnet_ar2}{out} = 0;

$cmds{rpc_remove_vnet_ar2}{params} = [0, 0];
$cmds{rpc_remove_vnet_ar2}{method} = "one.vn.rm_ar";
$cmds{rpc_remove_vnet_ar2}{out} = 0;

# Manage Datastores

$data = <<'EOF';
BRIDGE_LIST = "hyp004.cubone.os"
CEPH_HOST = "ceph001.cubone.os ceph002.cubone.os ceph003.cubone.os"
CEPH_SECRET = "35b161e7-a3bc-440f-b007-cb98ac042646"
CEPH_USER = "libvirt"
DATASTORE_CAPACITY_CHECK = "yes"
DISK_TYPE = "RBD"
DS_MAD = "ceph"
NAME = "ceph"
POOL_NAME = "one"
TM_MAD = "ceph"
TYPE = "IMAGE_DS"
QUATTOR = 1
EOF
$cmds{rpc_create_newdatastore}{params} = [$data, -1];
$cmds{rpc_create_newdatastore}{method} = "one.datastore.allocate";
$cmds{rpc_create_newdatastore}{out} = 102;

$cmds{rpc_delete_datastore}{params} = [102];
$cmds{rpc_delete_datastore}{method} = "one.datastore.delete";
$cmds{rpc_delete_datastore}{out} = 102;

$cmds{rpc_list_datastorespool}{params} = [];
$cmds{rpc_list_datastorespool}{method} = "one.datastorepool.info";
$cmds{rpc_list_datastorespool}{out} = <<'EOF';
<DATASTORE_POOL><DATASTORE><ID>102</ID><UID>0</UID><GID>0</GID><UNAME>oneadmin</UNAME><GNAME>oneadmin</GNAME><NAME>ceph.altaria</NAME><PERMISSIONS><OWNER_U>1</OWNER_U><OWNER_M>1</OWNER_M><OWNER_A>0</OWNER_A><GROUP_U>1</GROUP_U><GROUP_M>0</GROUP_M><GROUP_A>0</GROUP_A><OTHER_U>0</OTHER_U><OTHER_M>0</OTHER_M><OTHER_A>0</OTHER_A></PERMISSIONS><DS_MAD><![CDATA[ceph]]></DS_MAD><TM_MAD><![CDATA[ceph]]></TM_MAD><BASE_PATH><![CDATA[/var/lib/one//datastores/101]]></BASE_PATH><TYPE>0</TYPE><DISK_TYPE>3</DISK_TYPE><CLUSTER_ID>-1</CLUSTER_ID><CLUSTER></CLUSTER><TOTAL_MB>48645212</TOTAL_MB><FREE_MB>48476696</FREE_MB><USED_MB>168515</USED_MB><IMAGES><ID>30</ID><ID>37</ID></IMAGES><TEMPLATE><BASE_PATH><![CDATA[/var/lib/one//datastores/]]></BASE_PATH><BRIDGE_LIST><![CDATA[one01.altaria.os]]></BRIDGE_LIST><CEPH_HOST><![CDATA[ceph021.altaria.os ceph022.altaria.os ceph023.altaria.os]]></CEPH_HOST><CEPH_SECRET><![CDATA[35b161e7-a3bc-440f-b007-cb98ac042646]]></CEPH_SECRET><CEPH_USER><![CDATA[libvirt]]></CEPH_USER><CLONE_TARGET><![CDATA[SELF]]></CLONE_TARGET><DATASTORE_CAPACITY_CHECK><![CDATA[yes]]></DATASTORE_CAPACITY_CHECK><DISK_TYPE><![CDATA[RBD]]></DISK_TYPE><DS_MAD><![CDATA[ceph]]></DS_MAD><LN_TARGET><![CDATA[NONE]]></LN_TARGET><POOL_NAME><![CDATA[one]]></POOL_NAME><QUATTOR><![CDATA[1]]></QUATTOR><TM_MAD><![CDATA[ceph]]></TM_MAD></TEMPLATE></DATASTORE></DATASTORE_POOL>
EOF

$cmds{rpc_list_datastore}{params} = [102];
$cmds{rpc_list_datastore}{method} = "one.datastore.info";
$cmds{rpc_list_datastore}{out} = <<'EOF';
<DATASTORE><ID>102</ID><UID>0</UID><GID>0</GID><UNAME>oneadmin</UNAME><GNAME>oneadmin</GNAME><NAME>ceph.altaria</NAME><PERMISSIONS><OWNER_U>1</OWNER_U><OWNER_M>1</OWNER_M><OWNER_A>0</OWNER_A><GROUP_U>1</GROUP_U><GROUP_M>0</GROUP_M><GROUP_A>0</GROUP_A><OTHER_U>0</OTHER_U><OTHER_M>0</OTHER_M><OTHER_A>0</OTHER_A></PERMISSIONS><DS_MAD><![CDATA[ceph]]></DS_MAD><TM_MAD><![CDATA[ceph]]></TM_MAD><BASE_PATH><![CDATA[/var/lib/one//datastores/101]]></BASE_PATH><TYPE>0</TYPE><DISK_TYPE>3</DISK_TYPE><CLUSTER_ID>-1</CLUSTER_ID><CLUSTER></CLUSTER><TOTAL_MB>48645212</TOTAL_MB><FREE_MB>48476696</FREE_MB><USED_MB>168515</USED_MB><IMAGES><ID>30</ID><ID>37</ID></IMAGES><TEMPLATE><BASE_PATH><![CDATA[/var/lib/one//datastores/]]></BASE_PATH><BRIDGE_LIST><![CDATA[one01.altaria.os]]></BRIDGE_LIST><CEPH_HOST><![CDATA[ceph021.altaria.os ceph022.altaria.os ceph023.altaria.os]]></CEPH_HOST><CEPH_SECRET><![CDATA[8271ce8a-385d-44d7-a228-c42de4259c5e]]></CEPH_SECRET><CEPH_USER><![CDATA[libvirt]]></CEPH_USER><CLONE_TARGET><![CDATA[SELF]]></CLONE_TARGET><DATASTORE_CAPACITY_CHECK><![CDATA[yes]]></DATASTORE_CAPACITY_CHECK><DISK_TYPE><![CDATA[RBD]]></DISK_TYPE><DS_MAD><![CDATA[ceph]]></DS_MAD><LN_TARGET><![CDATA[NONE]]></LN_TARGET><POOL_NAME><![CDATA[one]]></POOL_NAME><QUATTOR><![CDATA[1]]></QUATTOR><TM_MAD><![CDATA[ceph]]></TM_MAD></TEMPLATE></DATASTORE>
EOF

# Manage hosts

$cmds{rpc_create_newhost}{params} = ["hyp101", "kvm", "kvm", "dummy", -1];
$cmds{rpc_create_newhost}{method} = "one.host.allocate";
$cmds{rpc_create_newhost}{out} = 1;

$cmds{rpc_create_newhost2}{params} = ["hyp102", "kvm", "kvm", "dummy", -1];
$cmds{rpc_create_newhost2}{method} = "one.host.allocate";
$cmds{rpc_create_newhost2}{out} = 167;

$cmds{rpc_create_newhost3}{params} = ["hyp103", "kvm", "kvm", "dummy", -1];
$cmds{rpc_create_newhost3}{method} = "one.host.allocate";
$cmds{rpc_create_newhost3}{out} = 168;

$cmds{rpc_create_newhost4}{params} = ["hyp104", "kvm", "kvm", "dummy", -1];
$cmds{rpc_create_newhost4}{method} = "one.host.allocate";
$cmds{rpc_create_newhost4}{out} = 169;

$cmds{rpc_delete_host}{params} = [1];
$cmds{rpc_delete_host}{method} = "one.host.delete";
$cmds{rpc_delete_host}{out} = 1;

$cmds{rpc_delete_host2}{params} = [167];
$cmds{rpc_delete_host2}{method} = "one.host.delete";
$cmds{rpc_delete_host2}{out} = 167;

$cmds{rpc_delete_host3}{params} = [168];
$cmds{rpc_delete_host3}{method} = "one.host.delete";
$cmds{rpc_delete_host3}{out} = 168;

$cmds{rpc_delete_host4}{params} = [169];
$cmds{rpc_delete_host4}{method} = "one.host.delete";
$cmds{rpc_delete_host4}{out} = 169;

$cmds{rpc_list_hostspool}{params} = [];
$cmds{rpc_list_hostspool}{method} = "one.hostpool.info";
$cmds{rpc_list_hostspool}{out} = <<'EOF';
<HOST_POOL><HOST><ID>1</ID><NAME>hyp101</NAME><STATE>2</STATE><IM_MAD><![CDATA[kvm]]></IM_MAD><VM_MAD><![CDATA[kvm]]></VM_MAD><VN_MAD><![CDATA[dummy]]></VN_MAD><LAST_MON_TIME>1410339181</LAST_MON_TIME><CLUSTER_ID>-1</CLUSTER_ID><CLUSTER></CLUSTER><HOST_SHARE><DISK_USAGE>0</DISK_USAGE><MEM_USAGE>524288</MEM_USAGE><CPU_USAGE>100</CPU_USAGE><MAX_DISK>117529</MAX_DISK><MAX_MEM>16433996</MAX_MEM><MAX_CPU>800</MAX_CPU><FREE_DISK>109303</FREE_DISK><FREE_MEM>14898328</FREE_MEM><FREE_CPU>793</FREE_CPU><USED_DISK>1</USED_DISK><USED_MEM>1535668</USED_MEM><USED_CPU>6</USED_CPU><RUNNING_VMS>1</RUNNING_VMS><DATASTORES></DATASTORES></HOST_SHARE><VMS><ID>55</ID></VMS><TEMPLATE><ARCH><![CDATA[x86_64]]></ARCH><CPUSPEED><![CDATA[2158]]></CPUSPEED><HOSTNAME><![CDATA[hyp101.altaria.os]]></HOSTNAME><HYPERVISOR><![CDATA[kvm]]></HYPERVISOR><MODELNAME><![CDATA[Intel(R) Xeon(R) CPU           L5420  @ 2.50GHz]]></MODELNAME><NETRX><![CDATA[163198016825]]></NETRX><NETTX><![CDATA[538319851166]]></NETTX><RESERVED_CPU><![CDATA[]]></RESERVED_CPU><RESERVED_MEM><![CDATA[]]></RESERVED_MEM><VERSION><![CDATA[4.6.2]]></VERSION></TEMPLATE></HOST><HOST><ID>167</ID><NAME>hyp102</NAME><STATE>2</STATE><IM_MAD><![CDATA[kvm]]></IM_MAD><VM_MAD><![CDATA[kvm]]></VM_MAD><VN_MAD><![CDATA[dummy]]></VN_MAD><LAST_MON_TIME>1410339186</LAST_MON_TIME><CLUSTER_ID>-1</CLUSTER_ID><CLUSTER></CLUSTER><HOST_SHARE><DISK_USAGE>0</DISK_USAGE><MEM_USAGE>0</MEM_USAGE><CPU_USAGE>0</CPU_USAGE><MAX_DISK>117529</MAX_DISK><MAX_MEM>16433996</MAX_MEM><MAX_CPU>800</MAX_CPU><FREE_DISK>109232</FREE_DISK><FREE_MEM>15789528</FREE_MEM><FREE_CPU>800</FREE_CPU><USED_DISK>1</USED_DISK><USED_MEM>644468</USED_MEM><USED_CPU>0</USED_CPU><RUNNING_VMS>0</RUNNING_VMS><DATASTORES></DATASTORES></HOST_SHARE><VMS></VMS><TEMPLATE><ARCH><![CDATA[x86_64]]></ARCH><CPUSPEED><![CDATA[2158]]></CPUSPEED><HOSTNAME><![CDATA[hyp102.altaria.os]]></HOSTNAME><HYPERVISOR><![CDATA[kvm]]></HYPERVISOR><MODELNAME><![CDATA[Intel(R) Xeon(R) CPU           L5420  @ 2.50GHz]]></MODELNAME><NETRX><![CDATA[5883921637]]></NETRX><NETTX><![CDATA[4113222929]]></NETTX><RESERVED_CPU><![CDATA[]]></RESERVED_CPU><RESERVED_MEM><![CDATA[]]></RESERVED_MEM><VERSION><![CDATA[4.6.2]]></VERSION></TEMPLATE></HOST><HOST><ID>168</ID><NAME>hyp103</NAME><STATE>3</STATE><IM_MAD><![CDATA[kvm]]></IM_MAD><VM_MAD><![CDATA[kvm]]></VM_MAD><VN_MAD><![CDATA[dummy]]></VN_MAD><LAST_MON_TIME>1410339177</LAST_MON_TIME><CLUSTER_ID>-1</CLUSTER_ID><CLUSTER></CLUSTER><HOST_SHARE><DISK_USAGE>0</DISK_USAGE><MEM_USAGE>0</MEM_USAGE><CPU_USAGE>0</CPU_USAGE><MAX_DISK>0</MAX_DISK><MAX_MEM>0</MAX_MEM><MAX_CPU>0</MAX_CPU><FREE_DISK>0</FREE_DISK><FREE_MEM>0</FREE_MEM><FREE_CPU>0</FREE_CPU><USED_DISK>0</USED_DISK><USED_MEM>0</USED_MEM><USED_CPU>0</USED_CPU><RUNNING_VMS>0</RUNNING_VMS><DATASTORES></DATASTORES></HOST_SHARE><VMS></VMS><TEMPLATE><ERROR><![CDATA[Wed Sep 10 10:52:57 2014 : Error monitoring Host hyp103 (168): -]]></ERROR><RESERVED_CPU><![CDATA[]]></RESERVED_CPU><RESERVED_MEM><![CDATA[]]></RESERVED_MEM></TEMPLATE></HOST></HOST_POOL>
EOF

$cmds{rpc_list_host}{params} = [1];
$cmds{rpc_list_host}{method} = "one.host.info";
$cmds{rpc_list_host}{out} = <<'EOF';
<HOST><ID>1</ID><NAME>hyp101</NAME><STATE>2</STATE><IM_MAD><![CDATA[kvm]]></IM_MAD><VM_MAD><![CDATA[kvm]]></VM_MAD><VN_MAD><![CDATA[dummy]]></VN_MAD><LAST_MON_TIME>1410339181</LAST_MON_TIME><CLUSTER_ID>-1</CLUSTER_ID><CLUSTER></CLUSTER><HOST_SHARE><DISK_USAGE>0</DISK_USAGE><MEM_USAGE>524288</MEM_USAGE><CPU_USAGE>100</CPU_USAGE><MAX_DISK>117529</MAX_DISK><MAX_MEM>16433996</MAX_MEM><MAX_CPU>800</MAX_CPU><FREE_DISK>109303</FREE_DISK><FREE_MEM>14898328</FREE_MEM><FREE_CPU>793</FREE_CPU><USED_DISK>1</USED_DISK><USED_MEM>1535668</USED_MEM><USED_CPU>6</USED_CPU><RUNNING_VMS>1</RUNNING_VMS><DATASTORES></DATASTORES></HOST_SHARE><VMS><ID>55</ID></VMS><TEMPLATE><ARCH><![CDATA[x86_64]]></ARCH><CPUSPEED><![CDATA[2158]]></CPUSPEED><HOSTNAME><![CDATA[hyp101.altaria.os]]></HOSTNAME><HYPERVISOR><![CDATA[kvm]]></HYPERVISOR><MODELNAME><![CDATA[Intel(R) Xeon(R) CPU           L5420  @ 2.50GHz]]></MODELNAME><NETRX><![CDATA[163198016825]]></NETRX><NETTX><![CDATA[538319851166]]></NETTX><RESERVED_CPU><![CDATA[]]></RESERVED_CPU><RESERVED_MEM><![CDATA[]]></RESERVED_MEM><VERSION><![CDATA[4.6.2]]></VERSION></TEMPLATE></HOST>
EOF

$cmds{rpc_list_host2}{params} = [167];
$cmds{rpc_list_host2}{method} = "one.host.info";
$cmds{rpc_list_host2}{out} = <<'EOF';
<HOST><ID>167</ID><NAME>hyp102</NAME><STATE>2</STATE><IM_MAD><![CDATA[kvm]]></IM_MAD><VM_MAD><![CDATA[kvm]]></VM_MAD><VN_MAD><![CDATA[dummy]]></VN_MAD><LAST_MON_TIME>1410433302</LAST_MON_TIME><CLUSTER_ID>-1</CLUSTER_ID><CLUSTER></CLUSTER><HOST_SHARE><DISK_USAGE>0</DISK_USAGE><MEM_USAGE>0</MEM_USAGE><CPU_USAGE>0</CPU_USAGE><MAX_DISK>117529</MAX_DISK><MAX_MEM>16433996</MAX_MEM><MAX_CPU>800</MAX_CPU><FREE_DISK>109219</FREE_DISK><FREE_MEM>15779876</FREE_MEM><FREE_CPU>798</FREE_CPU><USED_DISK>1</USED_DISK><USED_MEM>654120</USED_MEM><USED_CPU>1</USED_CPU><RUNNING_VMS>0</RUNNING_VMS><DATASTORES></DATASTORES></HOST_SHARE><VMS></VMS><TEMPLATE><ARCH><![CDATA[x86_64]]></ARCH><CPUSPEED><![CDATA[2158]]></CPUSPEED><HOSTNAME><![CDATA[hyp102.altaria.os]]></HOSTNAME><HYPERVISOR><![CDATA[kvm]]></HYPERVISOR><MODELNAME><![CDATA[Intel(R) Xeon(R) CPU           L5420  @ 2.50GHz]]></MODELNAME><NETRX><![CDATA[6031706026]]></NETRX><NETTX><![CDATA[4223542027]]></NETTX><RESERVED_CPU><![CDATA[]]></RESERVED_CPU><RESERVED_MEM><![CDATA[]]></RESERVED_MEM><VERSION><![CDATA[4.6.2]]></VERSION></TEMPLATE></HOST>
EOF


$cmds{rpc_list_host3}{params} = [168];
$cmds{rpc_list_host3}{method} = "one.host.info";
$cmds{rpc_list_host3}{out} = <<'EOF';
<HOST><ID>168</ID><NAME>hyp103</NAME><STATE>5</STATE><IM_MAD><![CDATA[kvm]]></IM_MAD><VM_MAD><![CDATA[kvm]]></VM_MAD><VN_MAD><![CDATA[dummy]]></VN_MAD><LAST_MON_TIME>1410433305</LAST_MON_TIME><CLUSTER_ID>-1</CLUSTER_ID><CLUSTER></CLUSTER><HOST_SHARE><DISK_USAGE>0</DISK_USAGE><MEM_USAGE>0</MEM_USAGE><CPU_USAGE>0</CPU_USAGE><MAX_DISK>0</MAX_DISK><MAX_MEM>0</MAX_MEM><MAX_CPU>0</MAX_CPU><FREE_DISK>0</FREE_DISK><FREE_MEM>0</FREE_MEM><FREE_CPU>0</FREE_CPU><USED_DISK>0</USED_DISK><USED_MEM>0</USED_MEM><USED_CPU>0</USED_CPU><RUNNING_VMS>0</RUNNING_VMS><DATASTORES></DATASTORES></HOST_SHARE><VMS></VMS><TEMPLATE><ERROR><![CDATA[Thu Sep 11 13:00:42 2014 : Error monitoring Host hyp103 (180): -]]></ERROR><RESERVED_CPU><![CDATA[]]></RESERVED_CPU><RESERVED_MEM><![CDATA[]]></RESERVED_MEM></TEMPLATE></HOST>
EOF

$cmds{rpc_list_host4}{params} = [169];
$cmds{rpc_list_host4}{method} = "one.host.info";
$cmds{rpc_list_host4}{out} = <<'EOF';
<HOST><ID>169</ID><NAME>hyp104</NAME><STATE>5</STATE><IM_MAD><![CDATA[kvm]]></IM_MAD><VM_MAD><![CDATA[kvm]]></VM_MAD><VN_MAD><![CDATA[dummy]]></VN_MAD><LAST_MON_TIME>1410433305</LAST_MON_TIME><CLUSTER_ID>-1</CLUSTER_ID><CLUSTER></CLUSTER><HOST_SHARE><DISK_USAGE>0</DISK_USAGE><MEM_USAGE>0</MEM_USAGE><CPU_USAGE>0</CPU_USAGE><MAX_DISK>0</MAX_DISK><MAX_MEM>0</MAX_MEM><MAX_CPU>0</MAX_CPU><FREE_DISK>0</FREE_DISK><FREE_MEM>0</FREE_MEM><FREE_CPU>0</FREE_CPU><USED_DISK>0</USED_DISK><USED_MEM>0</USED_MEM><USED_CPU>0</USED_CPU><RUNNING_VMS>0</RUNNING_VMS><DATASTORES></DATASTORES></HOST_SHARE><VMS></VMS><TEMPLATE><ERROR><![CDATA[Thu Sep 11 13:00:42 2014 : Error monitoring Host hyp104 (181): -]]></ERROR><RESERVED_CPU><![CDATA[]]></RESERVED_CPU><RESERVED_MEM><![CDATA[]]></RESERVED_MEM></TEMPLATE></HOST>
EOF

# Manage VMs

$cmds{rpc_list_vmspool}{params} = [-2, -1, -1, -1];
$cmds{rpc_list_vmspool}{method} = "one.vmpool.info";
$cmds{rpc_list_vmspool}{out} = <<'EOF';
<VM_POOL><VM><ID>60</ID><UID>0</UID><GID>0</GID><UNAME>oneadmin</UNAME><GNAME>oneadmin</GNAME><NAME>testttylinux-60</NAME><PERMISSIONS><OWNER_U>1</OWNER_U><OWNER_M>1</OWNER_M><OWNER_A>0</OWNER_A><GROUP_U>0</GROUP_U><GROUP_M>0</GROUP_M><GROUP_A>0</GROUP_A><OTHER_U>0</OTHER_U><OTHER_M>0</OTHER_M><OTHER_A>0</OTHER_A></PERMISSIONS><LAST_POLL>1410855058</LAST_POLL><STATE>3</STATE><LCM_STATE>3</LCM_STATE><RESCHED>0</RESCHED><STIME>1410854434</STIME><ETIME>0</ETIME><DEPLOY_ID>one-60</DEPLOY_ID><MEMORY>524288</MEMORY><CPU>3</CPU><NET_TX>0</NET_TX><NET_RX>0</NET_RX><TEMPLATE><AUTOMATIC_REQUIREMENTS><![CDATA[!(PUBLIC_CLOUD=YES)]]></AUTOMATIC_REQUIREMENTS><CONTEXT><DISK_ID><![CDATA[1]]></DISK_ID><NETWORK><![CDATA[YES]]></NETWORK><TARGET><![CDATA[hdb]]></TARGET></CONTEXT><CPU><![CDATA[1]]></CPU><DISK><CACHE><![CDATA[none]]></CACHE><CEPH_HOST><![CDATA[ceph021.altaria.osceph022.altaria.osceph023.altaria.os]]></CEPH_HOST><CEPH_SECRET><![CDATA[8271ce8a-385d-44d7-a228-c42de4259c5e]]></CEPH_SECRET><CEPH_USER><![CDATA[libvirt]]></CEPH_USER><CLONE><![CDATA[YES]]></CLONE><CLONE_TARGET><![CDATA[SELF]]></CLONE_TARGET><DATASTORE><![CDATA[ceph.altaria]]></DATASTORE><DATASTORE_ID><![CDATA[105]]></DATASTORE_ID><DEV_PREFIX><![CDATA[hd]]></DEV_PREFIX><DISK_ID><![CDATA[0]]></DISK_ID><IMAGE><![CDATA[ttylinux-kvm_file0]]></IMAGE><IMAGE_ID><![CDATA[43]]></IMAGE_ID><IMAGE_UNAME><![CDATA[oneadmin]]></IMAGE_UNAME><LN_TARGET><![CDATA[NONE]]></LN_TARGET><READONLY><![CDATA[NO]]></READONLY><SAVE><![CDATA[NO]]></SAVE><SIZE><![CDATA[40]]></SIZE><SOURCE><![CDATA[one/one-43]]></SOURCE><TARGET><![CDATA[hda]]></TARGET><TM_MAD><![CDATA[ceph]]></TM_MAD><TYPE><![CDATA[RBD]]></TYPE></DISK><GRAPHICS><LISTEN><![CDATA[0.0.0.0]]></LISTEN><PORT><![CDATA[5960]]></PORT><TYPE><![CDATA[VNC]]></TYPE></GRAPHICS><MEMORY><![CDATA[512]]></MEMORY><TEMPLATE_ID><![CDATA[4]]></TEMPLATE_ID><VMID><![CDATA[60]]></VMID></TEMPLATE><USER_TEMPLATE><QUATTOR><![CDATA[1]]></QUATTOR><SCHED_MESSAGE><![CDATA[TueSep1610:04:002014:NosystemdatastoresfoundtorunVMs]]></SCHED_MESSAGE></USER_TEMPLATE><HISTORY_RECORDS><HISTORY><OID>60</OID><SEQ>0</SEQ><HOSTNAME>hyp101</HOSTNAME><HID>190</HID><CID>-1</CID><STIME>1410854670</STIME><ETIME>0</ETIME><VMMMAD>kvm</VMMMAD><VNMMAD>dummy</VNMMAD><TMMAD>shared</TMMAD><DS_LOCATION>/var/lib/one//datastores</DS_LOCATION><DS_ID>106</DS_ID><PSTIME>1410854670</PSTIME><PETIME>1410854671</PETIME><RSTIME>1410854671</RSTIME><RETIME>0</RETIME><ESTIME>0</ESTIME><EETIME>0</EETIME><REASON>0</REASON><ACTION>0</ACTION></HISTORY></HISTORY_RECORDS></VM></VM_POOL>
EOF

$cmds{rpc_list_vm}{params} = [60];
$cmds{rpc_list_vm}{method} = "one.vm.info";
$cmds{rpc_list_vm}{out} = <<'EOF';
<VM><ID>60</ID><UID>0</UID><GID>0</GID><UNAME>oneadmin</UNAME><GNAME>oneadmin</GNAME><NAME>testttylinux-60</NAME><PERMISSIONS><OWNER_U>1</OWNER_U><OWNER_M>1</OWNER_M><OWNER_A>0</OWNER_A><GROUP_U>0</GROUP_U><GROUP_M>0</GROUP_M><GROUP_A>0</GROUP_A><OTHER_U>0</OTHER_U><OTHER_M>0</OTHER_M><OTHER_A>0</OTHER_A></PERMISSIONS><LAST_POLL>1410855578</LAST_POLL><STATE>3</STATE><LCM_STATE>3</LCM_STATE><RESCHED>0</RESCHED><STIME>1410854434</STIME><ETIME>0</ETIME><DEPLOY_ID>one-60</DEPLOY_ID><MEMORY>524288</MEMORY><CPU>2</CPU><NET_TX>0</NET_TX><NET_RX>0</NET_RX><TEMPLATE><AUTOMATIC_REQUIREMENTS><![CDATA[!(PUBLIC_CLOUD=YES)]]></AUTOMATIC_REQUIREMENTS><CONTEXT><DISK_ID><![CDATA[1]]></DISK_ID><NETWORK><![CDATA[YES]]></NETWORK><TARGET><![CDATA[hdb]]></TARGET></CONTEXT><CPU><![CDATA[1]]></CPU><DISK><CACHE><![CDATA[none]]></CACHE><CEPH_HOST><![CDATA[ceph021.altaria.osceph022.altaria.osceph023.altaria.os]]></CEPH_HOST><CEPH_SECRET><![CDATA[8271ce8a-385d-44d7-a228-c42de4259c5e]]></CEPH_SECRET><CEPH_USER><![CDATA[libvirt]]></CEPH_USER><CLONE><![CDATA[YES]]></CLONE><CLONE_TARGET><![CDATA[SELF]]></CLONE_TARGET><DATASTORE><![CDATA[ceph.altaria]]></DATASTORE><DATASTORE_ID><![CDATA[105]]></DATASTORE_ID><DEV_PREFIX><![CDATA[hd]]></DEV_PREFIX><DISK_ID><![CDATA[0]]></DISK_ID><IMAGE><![CDATA[ttylinux-kvm_file0]]></IMAGE><IMAGE_ID><![CDATA[43]]></IMAGE_ID><IMAGE_UNAME><![CDATA[oneadmin]]></IMAGE_UNAME><LN_TARGET><![CDATA[NONE]]></LN_TARGET><READONLY><![CDATA[NO]]></READONLY><SAVE><![CDATA[NO]]></SAVE><SIZE><![CDATA[40]]></SIZE><SOURCE><![CDATA[one/one-43]]></SOURCE><TARGET><![CDATA[hda]]></TARGET><TM_MAD><![CDATA[ceph]]></TM_MAD><TYPE><![CDATA[RBD]]></TYPE></DISK><GRAPHICS><LISTEN><![CDATA[0.0.0.0]]></LISTEN><PORT><![CDATA[5960]]></PORT><TYPE><![CDATA[VNC]]></TYPE></GRAPHICS><MEMORY><![CDATA[512]]></MEMORY><TEMPLATE_ID><![CDATA[4]]></TEMPLATE_ID><VMID><![CDATA[60]]></VMID></TEMPLATE><USER_TEMPLATE><QUATTOR><![CDATA[1]]></QUATTOR><SCHED_MESSAGE><![CDATA[TueSep1610:04:002014:NosystemdatastoresfoundtorunVMs]]></SCHED_MESSAGE></USER_TEMPLATE><HISTORY_RECORDS><HISTORY><OID>60</OID><SEQ>0</SEQ><HOSTNAME>hyp101</HOSTNAME><HID>190</HID><CID>-1</CID><STIME>1410854670</STIME><ETIME>0</ETIME><VMMMAD>kvm</VMMMAD><VNMMAD>dummy</VNMMAD><TMMAD>shared</TMMAD><DS_LOCATION>/var/lib/one//datastores</DS_LOCATION><DS_ID>106</DS_ID><PSTIME>1410854670</PSTIME><PETIME>1410854671</PETIME><RSTIME>1410854671</RSTIME><RETIME>0</RETIME><ESTIME>0</ESTIME><EETIME>0</EETIME><REASON>0</REASON><ACTION>0</ACTION></HISTORY></HISTORY_RECORDS></VM>
EOF

# Manage images

$cmds{rpc_list_imagespool}{params} = [-2, -1, -1];
$cmds{rpc_list_imagespool}{method} = "one.imagepool.info";
$cmds{rpc_list_imagespool}{out} = <<'EOF';
<IMAGE_POOL><IMAGE><ID>43</ID><UID>0</UID><GID>0</GID><UNAME>oneadmin</UNAME><GNAME>oneadmin</GNAME><NAME>node630.cubone.os_vda</NAME><PERMISSIONS><OWNER_U>1</OWNER_U><OWNER_M>1</OWNER_M><OWNER_A>0</OWNER_A><GROUP_U>0</GROUP_U><GROUP_M>0</GROUP_M><GROUP_A>0</GROUP_A><OTHER_U>0</OTHER_U><OTHER_M>0</OTHER_M><OTHER_A>0</OTHER_A></PERMISSIONS><TYPE>0</TYPE><DISK_TYPE>3</DISK_TYPE><PERSISTENT>0</PERSISTENT><REGTIME>1410854276</REGTIME><SOURCE><![CDATA[one/one-43]]></SOURCE><PATH><![CDATA[http://marketplace.c12g.com/appliance/4fc76a938fb81d3517000003/download/0]]></PATH><FSTYPE><![CDATA[]]></FSTYPE><SIZE>40</SIZE><STATE>1</STATE><RUNNING_VMS>1</RUNNING_VMS><CLONING_OPS>0</CLONING_OPS><CLONING_ID>-1</CLONING_ID><DATASTORE_ID>105</DATASTORE_ID><DATASTORE>ceph.altaria</DATASTORE><VMS><ID>60</ID></VMS><CLONES/><TEMPLATE><DEV_PREFIX><![CDATA[vd]]></DEV_PREFIX><FROM_APP><![CDATA[4fc76a938fb81d3517000003]]></FROM_APP><FROM_APP_FILE><![CDATA[0]]></FROM_APP_FILE><FROM_APP_NAME><![CDATA[ttylinux-kvm]]></FROM_APP_NAME><MD5><![CDATA[04c7d00e88fa66d9aaa34d9cf8ad6aaa]]></MD5><QUATTOR><![CDATA[1]]></QUATTOR></TEMPLATE></IMAGE><IMAGE><ID>44</ID><UID>0</UID><GID>0</GID><UNAME>oneadmin</UNAME><GNAME>oneadmin</GNAME><NAME>node630.cubone.os_vdb</NAME><PERMISSIONS><OWNER_U>1</OWNER_U><OWNER_M>1</OWNER_M><OWNER_A>0</OWNER_A><GROUP_U>0</GROUP_U><GROUP_M>0</GROUP_M><GROUP_A>0</GROUP_A><OTHER_U>0</OTHER_U><OTHER_M>0</OTHER_M><OTHER_A>0</OTHER_A></PERMISSIONS><TYPE>0</TYPE><DISK_TYPE>3</DISK_TYPE><PERSISTENT>0</PERSISTENT><REGTIME>1410854276</REGTIME><SOURCE><![CDATA[one/one-43]]></SOURCE><PATH><![CDATA[http://marketplace.c12g.com/appliance/4fc76a938fb81d3517000003/download/0]]></PATH><FSTYPE><![CDATA[]]></FSTYPE><SIZE>40</SIZE><STATE>1</STATE><RUNNING_VMS>1</RUNNING_VMS><CLONING_OPS>0</CLONING_OPS><CLONING_ID>-1</CLONING_ID><DATASTORE_ID>105</DATASTORE_ID><DATASTORE>ceph.altaria</DATASTORE><VMS><ID>60</ID></VMS><CLONES/><TEMPLATE><DEV_PREFIX><![CDATA[vd]]></DEV_PREFIX><FROM_APP><![CDATA[4fc76a938fb81d3517000003]]></FROM_APP><FROM_APP_FILE><![CDATA[0]]></FROM_APP_FILE><FROM_APP_NAME><![CDATA[ttylinux-kvm]]></FROM_APP_NAME><MD5><![CDATA[04c7d00e88fa66d9aaa34d9cf8ad6aaa]]></MD5><QUATTOR><![CDATA[1]]></QUATTOR></TEMPLATE></IMAGE></IMAGE_POOL>
EOF

$cmds{rpc_list_image}{params} = [43];
$cmds{rpc_list_image}{method} = "one.image.info";
$cmds{rpc_list_image}{out} = <<'EOF';
<IMAGE><ID>43</ID><UID>0</UID><GID>0</GID><UNAME>oneadmin</UNAME><GNAME>oneadmin</GNAME><NAME>node630.cubone.os_vda</NAME><PERMISSIONS><OWNER_U>1</OWNER_U><OWNER_M>1</OWNER_M><OWNER_A>0</OWNER_A><GROUP_U>0</GROUP_U><GROUP_M>0</GROUP_M><GROUP_A>0</GROUP_A><OTHER_U>0</OTHER_U><OTHER_M>0</OTHER_M><OTHER_A>0</OTHER_A></PERMISSIONS><TYPE>0</TYPE><DISK_TYPE>3</DISK_TYPE><PERSISTENT>0</PERSISTENT><REGTIME>1410854276</REGTIME><SOURCE><![CDATA[one/one-43]]></SOURCE><PATH><![CDATA[http://marketplace.c12g.com/appliance/4fc76a938fb81d3517000003/download/0]]></PATH><FSTYPE><![CDATA[]]></FSTYPE><SIZE>40</SIZE><STATE>1</STATE><RUNNING_VMS>1</RUNNING_VMS><CLONING_OPS>0</CLONING_OPS><CLONING_ID>-1</CLONING_ID><DATASTORE_ID>105</DATASTORE_ID><DATASTORE>ceph.altaria</DATASTORE><VMS><ID>60</ID></VMS><CLONES/><TEMPLATE><DEV_PREFIX><![CDATA[vd]]></DEV_PREFIX><FROM_APP><![CDATA[4fc76a938fb81d3517000003]]></FROM_APP><FROM_APP_FILE><![CDATA[0]]></FROM_APP_FILE><FROM_APP_NAME><![CDATA[ttylinux-kvm]]></FROM_APP_NAME><MD5><![CDATA[04c7d00e88fa66d9aaa34d9cf8ad6aaa]]></MD5><QUATTOR><![CDATA[1]]></QUATTOR></TEMPLATE></IMAGE>
EOF

$cmds{rpc_list_image2}{params} = [44];
$cmds{rpc_list_image2}{method} = "one.image.info";
$cmds{rpc_list_image2}{out} = <<'EOF';
<IMAGE><ID>43</ID><UID>0</UID><GID>0</GID><UNAME>oneadmin</UNAME><GNAME>oneadmin</GNAME><NAME>node630.cubone.os_vdb</NAME><PERMISSIONS><OWNER_U>1</OWNER_U><OWNER_M>1</OWNER_M><OWNER_A>0</OWNER_A><GROUP_U>0</GROUP_U><GROUP_M>0</GROUP_M><GROUP_A>0</GROUP_A><OTHER_U>0</OTHER_U><OTHER_M>0</OTHER_M><OTHER_A>0</OTHER_A></PERMISSIONS><TYPE>0</TYPE><DISK_TYPE>3</DISK_TYPE><PERSISTENT>0</PERSISTENT><REGTIME>1410854276</REGTIME><SOURCE><![CDATA[one/one-43]]></SOURCE><PATH><![CDATA[http://marketplace.c12g.com/appliance/4fc76a938fb81d3517000003/download/0]]></PATH><FSTYPE><![CDATA[]]></FSTYPE><SIZE>40</SIZE><STATE>1</STATE><RUNNING_VMS>1</RUNNING_VMS><CLONING_OPS>0</CLONING_OPS><CLONING_ID>-1</CLONING_ID><DATASTORE_ID>105</DATASTORE_ID><DATASTORE>ceph.altaria</DATASTORE><VMS><ID>60</ID></VMS><CLONES/><TEMPLATE><DEV_PREFIX><![CDATA[vd]]></DEV_PREFIX><FROM_APP><![CDATA[4fc76a938fb81d3517000003]]></FROM_APP><FROM_APP_FILE><![CDATA[0]]></FROM_APP_FILE><FROM_APP_NAME><![CDATA[ttylinux-kvm]]></FROM_APP_NAME><MD5><![CDATA[04c7d00e88fa66d9aaa34d9cf8ad6aaa]]></MD5><QUATTOR><![CDATA[1]]></QUATTOR></TEMPLATE></IMAGE>
EOF

$cmds{rpc_remove_image}{params} = [43];
$cmds{rpc_remove_image}{method} = "one.image.delete";
$cmds{rpc_remove_image}{out} = 43;

$cmds{rpc_remove_image2}{params} = [44];
$cmds{rpc_remove_image2}{method} = "one.image.delete";
$cmds{rpc_remove_image2}{out} = 44;

$data = <<'EOF';

TYPE = "DATABLOCK"
PERSISTENT = "YES"
DEV_PREFIX = "vd"
NAME = "node630.cubone.os_vda"
TARGET = "vda"
SIZE = 20480
DESCRIPTION = "QUATTOR image for node630.cubone.os: vda"
QUATTOR = 1
EOF
$cmds{rpc_create_image}{params} = [$data, 102];
$cmds{rpc_create_image}{method} = "one.image.allocate";
$cmds{rpc_create_image}{out} = 43;

$data = <<'EOF';

TYPE = "DATABLOCK"
PERSISTENT = "YES"
DEV_PREFIX = "vd"
NAME = "node630.cubone.os_vdb"
TARGET = "vdb"
SIZE = 10480
DESCRIPTION = "QUATTOR image for node630.cubone.os: vdb"
QUATTOR = 1
EOF
$cmds{rpc_create_image2}{params} = [$data, 102];
$cmds{rpc_create_image2}{method} = "one.image.allocate";
$cmds{rpc_create_image2}{out} = 44;


# Manage VM templates

$cmds{rpc_list_templatespool}{params} = [-2, -1, -1];
$cmds{rpc_list_templatespool}{method} = "one.templatepool.info";
$cmds{rpc_list_templatespool}{out} = <<'EOF';
<VMTEMPLATE_POOL><VMTEMPLATE><ID>4</ID><UID>0</UID><GID>0</GID><UNAME>oneadmin</UNAME><GNAME>oneadmin</GNAME><NAME>node630.cubone.os</NAME><PERMISSIONS><OWNER_U>1</OWNER_U><OWNER_M>1</OWNER_M><OWNER_A>0</OWNER_A><GROUP_U>0</GROUP_U><GROUP_M>0</GROUP_M><GROUP_A>0</GROUP_A><OTHER_U>0</OTHER_U><OTHER_M>0</OTHER_M><OTHER_A>0</OTHER_A></PERMISSIONS><REGTIME>1405587240</REGTIME><TEMPLATE><CONTEXT><NETWORK><![CDATA[YES]]></NETWORK><SSH_PUBLIC_KEY><![CDATA[$USER[SSH_PUBLIC_KEY]]]></SSH_PUBLIC_KEY></CONTEXT><CPU><![CDATA[1]]></CPU><DISK><CACHE><![CDATA[none]]></CACHE><DEV_PREFIX><![CDATA[hd]]></DEV_PREFIX><IMAGE><![CDATA[ttylinux-kvm_file0]]></IMAGE><IMAGE_UNAME><![CDATA[oneadmin]]></IMAGE_UNAME></DISK><GRAPHICS><LISTEN><![CDATA[0.0.0.0]]></LISTEN><TYPE><![CDATA[VNC]]></TYPE></GRAPHICS><MEMORY><![CDATA[512]]></MEMORY><QUATTOR><![CDATA[1]]></QUATTOR></TEMPLATE></VMTEMPLATE></VMTEMPLATE_POOL>
EOF

$cmds{rpc_list_template}{params} = [4];
$cmds{rpc_list_template}{method} = "one.template.info";
$cmds{rpc_list_template}{out} = <<'EOF';
<VMTEMPLATE><ID>4</ID><UID>0</UID><GID>0</GID><UNAME>oneadmin</UNAME><GNAME>oneadmin</GNAME><NAME>node630.cubone.os</NAME><PERMISSIONS><OWNER_U>1</OWNER_U><OWNER_M>1</OWNER_M><OWNER_A>0</OWNER_A><GROUP_U>0</GROUP_U><GROUP_M>0</GROUP_M><GROUP_A>0</GROUP_A><OTHER_U>0</OTHER_U><OTHER_M>0</OTHER_M><OTHER_A>0</OTHER_A></PERMISSIONS><REGTIME>1405587240</REGTIME><TEMPLATE><CONTEXT><NETWORK><![CDATA[YES]]></NETWORK><SSH_PUBLIC_KEY><![CDATA[$USER[SSH_PUBLIC_KEY]]]></SSH_PUBLIC_KEY></CONTEXT><CPU><![CDATA[1]]></CPU><DISK><CACHE><![CDATA[none]]></CACHE><DEV_PREFIX><![CDATA[hd]]></DEV_PREFIX><IMAGE><![CDATA[ttylinux-kvm_file0]]></IMAGE><IMAGE_UNAME><![CDATA[oneadmin]]></IMAGE_UNAME></DISK><GRAPHICS><LISTEN><![CDATA[0.0.0.0]]></LISTEN><TYPE><![CDATA[VNC]]></TYPE></GRAPHICS><MEMORY><![CDATA[512]]></MEMORY><QUATTOR><![CDATA[1]]></QUATTOR></TEMPLATE></VMTEMPLATE>
EOF

$data = <<'EOF';

NIC = [
    IP = "10.141.8.30",
    MAC = "AA:00:00:80:01:00",
    MODEL = "virtio",
    NETWORK = "altaria.os",
    NETWORK_UNAME = "oneadmin"
]
NIC = [
    IP = "172.24.8.30",
    MAC = "AA:00:00:80:01:01",
    MODEL = "virtio",
    NETWORK = "altaria.vsc",
    NETWORK_UNAME = "oneadmin"
]
NAME = "node630.cubone.os"
CONTEXT = [
    NETWORK = "YES",
    HOSTNAME = "node630.cubone.os",
    TOKEN = "YES"
]
CPU = "4"
VCPU = "4"
DESCRIPTION = "KVM Virtual Machine node630.cubone.os"
DISK = [
    IMAGE = "node630.cubone.os_vda",
    TARGET = "vda",
    DEV_PREFIX = "vd",
    IMAGE_UNAME = "oneadmin"
]
DISK = [
    IMAGE = "node630.cubone.os_vdb",
    TARGET = "vdb",
    DEV_PREFIX = "vd",
    IMAGE_UNAME = "oneadmin"
]
GRAPHICS = [
    LISTEN = "0.0.0.0",
    TYPE = "VNC"
]
MEMORY = "4096"
OS = [
    BOOT = "network,hd"
]
RAW = [
    DATA = "<cpu mode='host-passthrough'/>",
    TYPE = "kvm"
]
QUATTOR = 1
EOF
$cmds{rpc_create_template}{params} = [$data];
$cmds{rpc_create_template}{method} = "one.template.allocate";
$cmds{rpc_create_template}{out} = 4;

$cmds{rpc_update_template}{params} = [4, $data, 0];
$cmds{rpc_update_template}{method} = "one.template.update";
$cmds{rpc_update_template}{out} = 4;

$data = <<'EOF';
EOF
$cmds{rpc_instantiate_template}{params} = [4, "node630.cubone.os", 1, $data];
$cmds{rpc_instantiate_template}{method} = "one.template.instantiate";
$cmds{rpc_instantiate_template}{out} = 60;

$cmds{rpc_remove_template}{params} = [4];
$cmds{rpc_remove_template}{method} = "one.template.delete";
$cmds{rpc_remove_template}{out} = 4;

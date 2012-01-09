#!/usr/bin/perl -T
# ${license-info}
# ${developer-info
# ${author-info}
# ${build-info}

# Configuration file to boot from HD. Following pxelinux convention
# it must be called default so if the <IpAddressInHex> link 
# is missing the node will boot from the hard disk
my $boothd = "default";

# Quattor XML profiles
my $web_root = "/var/www/html";
my $profiles_path="profiles";
my $profiles_dir = $web_root.'/'.$profiles_path;

# Number of different boot types
my %boot_type;

# Array of available pxelinux configurations
my @cfg;

# Data collected from the form  
my %nodes_cfg;

# Hostname and domainname
my ($server_name,$server_domain);

# Profiles .xml available
my (@profiles);

# whether or not to auto-configure nodes (set by form)
my $autoconfig;

################################################################
sub GetHexAddr {
################################################################
# Get the hostname or an IP address and return the IP address in
# hex (as required by pxelinux)

  # The 4th field is an array of the IP address of this node
  my @all_address;
  @all_address =(gethostbyname($_[0]))[4];
  if ($#all_address < 0) { # The array is empty
    return ;
  }
  # We unpack the IP address
  my @tmp_address = unpack('C4',$all_address[0]);
  my @result;
  $result[0]=sprintf ("%02X%02X%02X%02X",$tmp_address[0], $tmp_address[1],
                                         $tmp_address[2], $tmp_address[3]);
  $result[1]=sprintf ("%u.%u.%u.%u",$tmp_address[0], $tmp_address[1],
                                    $tmp_address[2], $tmp_address[3]);
  return @result;
}


#########################################################################
sub Initialize {
#########################################################################

  # Get the domain of the server
  $server_name   = $ENV{'SERVER_NAME'};
#  $server_name=`hostname -f`; chomp($server_name);
  $server_domain = $server_name;
  $server_domain =~ s/[^.]*\.//;

  # Get the domain of the client
  my $your_name   = $ENV{'REMOTE_ADDR'};
  my $your_domain = $your_name;
  $your_domain =~ s/[^.]*\.//;

  @profiles=();

  opendir(DIR,$profiles_dir);
#  my @dirs=readdir(DIR);


  # find all profiles in directory
  my $d;


  push @profiles,map { s/\.xml$//; $_.=".".$server_domain; } sort(grep(/\.xml$/, readdir(DIR)));    

  for my $profile (@profiles) {
    $profile=~s/profile\_//;
    if ($profile=~/\.$server_domain\.$server_domain/ ) {
	$profile=~s/\.$server_domain$//;
    }
  }
    
    # need to remove profile


  closedir(DIR);
  # Load the configurations list
  opendir(DIR, $pxelinux_dir);
  @cfg      = sort(grep(/(\.cfg$)|(default)/, readdir(DIR)));
  closedir(DIR);
}

######################################################################
sub CollectHtmlDetails{
######################################################################
# Return the html code with the description of the nodes status
  my $html="<h3>Node details<hr></h3> \
         <form method=\"POST\" action=\"aii-web.cgi\"> \
         <center><table width=\"80%\" cellpadding=\"2\" cellspacing=\"0\" border =\"1\">\
         <tr><th align=left>Hostname<th align=left>IP Address (HEX)<th align=left>Boot type</tr>";
# For each node we get its current cfg file; if this one is missing
# we show default
  my ($k, $i, $hostname, $existing_cfg, $hexaddr, $dotaddr);
  for $k (@profiles) {

    my $fqdn = ($k =~ /\.$server_domain$/);
    if ($fqdn) {
	$hostname = $k;
    }
    else {
      $hostname = $k.='.'.$server_domain;
  }
    
    
    ($hexaddr,$dotaddr) = GetHexAddr($hostname);
    $existing_cfg = "";
    $existing_cfg = readlink($pxelinux_dir . "/" . $hexaddr);
    # If the link does not exist we create a link to the default boot mode via HD
    if ($existing_cfg eq "") {
      $existing_cfg="NOT CONFIGURED";
      if (!(grep $_ eq "NOT CONFIGURED", @cfg )) {
        unshift @cfg, "NOT CONFIGURED";
      }
    }
    $html.="<tr><td>$hostname \
           <td>$dotaddr ($hexaddr)<td><select name=\"$hostname\">";
    # We maintain the number of nodes for each boot type
    $boot_type{$existing_cfg}++;

    for $i (@cfg) {
      $html.="\n<option value=\"$i\"";
      if ($existing_cfg eq $i) {
        $html.=" SELECTED";
      }
      $html.=">$i</option>";
    }
    $html.="</select>";  
  }
  return $html."</table></center><br>";
}

#############################################################################
sub GetInput {
#############################################################################
# Get input from the form and put it into %nodes_cfg and return TRUE
# if the user requested some changes
  my ($do_changes,$temp,$name,$value,$item,@temp_nodes_cfg);
  $do_changes=0; 
  read (STDIN,$temp,$ENV{'CONTENT_LENGTH'});
  @temp_nodes_cfg=split(/&/,$temp);
  # We should get as input nodes_cfg (name,value) where
  # the name is FQDN of the node, and the value is the pxelinux cfg file
  foreach $item (@temp_nodes_cfg) {
    ($name,$value)=split(/=/,$item,2);
    $value=~tr/+/ /;
    $value=~s/%(..)/pack("c",hex($1))/ge;
    if ($name eq "Operation" && $value eq "Apply changes") {
      $do_changes=1;
    } elsif ($name eq "autoconfig" && $value) {
	$autoconfig=$value;
    } else {
      $nodes_cfg{$name}=$value; 
    }
  }
  return ($do_changes);
}

######################################################################
sub UpdateSymlinks {
######################################################################
# Update the symlinks on the disk according with nodes_cfg (i.e. user 
# input)


  my ($node, $value,@found,$hexaddr,$dotaddr);
  my $error_str='';
  while (($node, $value) = each(%nodes_cfg)) {

    # Check if the configuration file exists
    @found=grep(/^$nodes_cfg{$node}$/,@cfg);
    if ($#found < 0 && $nodes_cfg{$node} ne "NOT CONFIGURED") {
       $error_str.="Config file \"$nodes_cfg{$node}\" not found<br>";
      next;
    }
    # Check if the hostname is one of the XML profiles
    @found=grep(/^$node$/,@profiles);
    if ($#found < 0) {
       $error_str.="Profile for hostname \"$node\" does not exist<br>";
      next;
    }
    # Get the IP address in hex
    ($hexaddr,$dotaddr) = GetHexAddr($node);
    if ($hexaddr eq "") {
      $error_str.="Hostname \"$node\" not valid<br>";
      next;
    }

    my $existing_cfg = "";
    $existing_cfg = readlink($pxelinux_dir . "/" . $hexaddr);

    $ENV{PATH}="/bin:/usr/bin:/sbin:/usr/bin:/usr/sbin";
    # Run AII to configure the node if it's not
    if ($existing_cfg eq "" && $autoconfig) {
      if (system ("/usr/bin/sudo", "/usr/sbin/aii-shellfe", "--configure", $node) != 0) {
	$error_str.= "Failed to configure $node using aii-shellfe<br>";
      }
    }
    # Finally update the symlink
    my $node_cfg=$nodes_cfg{$node};
    if ($node_cfg =~ /((\w*\.)*cfg|NOT CONFIGURED)/) {
      $node_cfg = "$1";
    } else {
      warn ("TAINTED DATA SENT BY $ENV{'REMOTE_ADDR'}: $node_cfg: $!");
      $node_cfg = ""; # successful match did not occur
    }
    
    if ($node_cfg ne "NOT CONFIGURED") {
	my ($target, $ref);
	chdir($pxelinux_dir);
	$target = $node_cfg;
	$ref = $hexaddr;
	my $cur_target=readlink($ref);
        if ($cur_target ne $node_cfg ) {
	    unlink($ref);	
	if (!symlink($target, $hexaddr)) {
	    ($error_str.= "Failed to link $target to $hexaddr<br>");


	}
	

    }
    }
  

  }
  if ($error_str ne '') {
    $error_str="<h2>Error messages from reconfiguration</h2>".$error_str;
  }
  return $error_str;
}


########################################################################
sub PrintHtml($) {
########################################################################
# Print the page; receive as parameter the details for each node
  my ($i,$temp);
  print "Content-type: text/html\n\n\
<html><head><META HTTP-EQUIV=\"Pragma\" CONTENT=\"no-cache\">\
<title>AII server status</title></head>\
<body><h3>AII server summary<hr></h3><center>\
<table width=\"50%\" cellpadding=\"2\" cellspacing=\"0\" border =\"1\">\
<tr><td><b>XML Profiles</b>\
    <td><a href=\"http://$server_name/$profiles_path\">\
           http://$server_name/$profiles_path/</a></tr>\
<tr><td><b>Total nodes</b><td>". ($#profiles+1) . "</tr>\
</table>\
<br>\
<table width=\"50%\" cellpadding=\"2\" cellspacing=\"0\" border =\"1\">\
    <tr><th>Boot Type<th> # of Nodes</tr>";
  for $i (@cfg) {
    if ( defined ($boot_type{$i}) && $boot_type{$i} != 0) {
       $temp=$i;
       $temp=~s/\.cfg$//;
       print "<tr><td width=260>$temp<td>$boot_type{$i}</tr>";
    }
  }
  # Here we put the details
  print "</table></center><br>\n";

  print"@_";
  # We show the buttons' form only if there are nodes
  if ($#profiles >=0) {
    print "<center><input type=\"checkbox\" name=\"autoconfig\"> Auto-initialise nodes<br> \
<input type=\"submit\" name=\"Operation\" value=\"Apply changes\"> ";
  }
  print "&nbsp;&nbsp;<input type=\"submit\" name=\"Operation\" value=\"Reload\">\  
 \
         </form></center></body></html>";
}


#########################################################################
# MAIN
#########################################################################

my ($do_reload,$output_details,$error);
# Load the directory entries (*.xml and *.cfg)
&Initialize;

# If there are changes, update the symlinks
if (&GetInput) {
  $error=&UpdateSymlinks;
}
# Collect the symlinks and print the page
&PrintHtml($error.&CollectHtmlDetails);


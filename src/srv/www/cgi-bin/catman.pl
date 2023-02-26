#!/usr/bin/perl
######################################################################## 
# 
#  $ manage switch (C) (R) 2017 pawel.trepka@gmail.com $
# 
######################################################################## 

# use Modern::Perl qw/2015/;
use strict;
# use warnings;
use CGI;
use Data::Dumper;
use Path::Tiny;
use autodie;
use HTML::HashTable;
use Text::Diff;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use Switch;


# ooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo
#  Sub's Load Config
# ooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo
#  Sub Content

my $appVersion = "1.6.6.0 build 20180907";

my $fCopyCR = sprintf <<EOF;

<TABLE ALIGN="right">
<TR><TD>CatMan&trade;&nbsp;ver.&nbsp;$appVersion</TD></TR><TR><TD>&copy;&reg;2017,2018 Paweł Trepka</TD></TR>
</TABLE>

EOF

sub contentHeader {
#	print "Content-type: text/html \n\n";
#	print CGI::header( charset=>"utf-8"} );
	print CGI::header(
		-type => "text/html; charset=utf-8"
	);
}

#  Sub Load Config

sub errorMe {
 my $err=$1;
 contentHeader;
 print "No config file found $err";
 exit 1;
}

# ooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo
# Global vars
# ooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo

my $actiontype = "";
my $OK = 0;
my @keyValuePairs="";
my %params=();
my $query = "";
my $hw_model = "";
my $hw_portFastEth = "";
my $hw_portGbitEth = "";
my $hw_swRunVersion = "";
my $hw_swUpTime = "";
my $hw_SystemName = "";
my $clock_time = "";
my @port=();
my @port_description=();
my @port_status=();
my @port_vlan_nr=();
my @port_duplex=();
my @port_speed=();
my @port_type=();
my @vlan_id=();
my @vlan_name=();
my @vlan_active=();
my @vlan_type=();
my $MyMethod='';
my $QueryString='';
my $ContentLength='';
my $wasContent=0;
my $prog_conf="/etc/catman/config";
my %configs=();


#
# Load basis of config
# 

sub load_app_config {
	open(FIC,"$prog_conf");
	my @results_conf=<FIC>;
	close(FIC);
	foreach my $field (@results_conf) {
		if ( !($field =~ m/^#/) and !($field eq '') ) {
		(my $key, my $value) = split(/\=/,$field);
			$key =~ s/%([a-f0-9]{2})/chr(hex($1))/eig; # URL decode the key
			$value =~ s/%([a-f0-9]{2})/chr(hex($1))/eig; # URL decode the value
			$value =~ s/\"//eig;
			$value =~ s/\n//eig;
			$configs{$key}=$value if ( !($value eq '') );
		}
	}
}

sub load_config {

my $fpath = "$configs{cidevices}";

open (File,'<', $fpath) or die "$!";
my @results = <File>;
close (File);

contentHeader;

print <<EOF;

<HTML>
<HEAD>
<META HTTP-EQUIV="Pragma" CONTENT="no-cache">
<META HTTP-EQUIV="Expires" CONTENT="-1">
<TITLE>Load Device Config</TITLE>
</HEAD>
<SCRIPT TYPE="text/javascript">
funtion Refresh()
{
    var iframe = document.getElementById('iframe1');
    iframe.reload(true);
}

setTimeout('Refresh()', 3000);
</SCRIPT>
<BODY>
<FORM ACTION="$configs{cgibinurl}" METHOD="POST" TARGET="_body">
<INPUT TYPE="hidden" NAME="config" VALUE="no">
<INPUT TYPE="hidden" NAME="man" VALUE="yes">
<P>Select device<BR>
<SELECT NAME="select_cisco_by_ip">

EOF

foreach my $line(@results) {
	my $addr;
	my $name;
	my $other;
	chop $line;
	if ( !($line =~ m/^#/) ) {
	($addr,$name,$other) = split /\s*:\s*/,$line,3;
	printf "<OPTION VALUE=\"$addr\">$name</OPTION>\n";
	}

}

print <<EOF;
</SELECT>
<INPUT TYPE="submit" NAME="showDevID" VALUE="Show Device ID"></P>

<P>Put port Down/Up<BR>
<INPUT TYPE="submit" NAME="putDownUpPort" VALUE="Port Down/Up"></P>

<P>Change Description<BR>
<INPUT TYPE="submit" NAME="descPortChange" VALUE="Change Port Description"></P>

<P>Change Port Vlan<BR>
<INPUT TYPE="submit" NAME="changePortVlan" VALUE="Change Port Vlan"></P>

<P>Port Error Counter reset<BR>
<INPUT TYPE="submit" NAME="clearPortCounters" VALUE="Clear Port Counters"></P>

<P>&nbsp;<BR></P>
<P>&nbsp;<BR></P>

<!-- P>List of devices with issued changes<BR>
<IFRAME NAME="iframe1" SRC="http://switche.local.pl/change.html"></IFRAME>
</P -->

<P>&nbsp;<BR></P>
<P>&nbsp;<BR></P>

</FORM>

<P>&nbsp;<BR><A HREF="/left_menu.html" TARGET="_menu" STYLE="text-decoration: none; border:0px; background-color:#D3D3D3; color:#000; font-weight:bold; padding:10px; cursor:pointer; border-radius:5px;">Reload list of devices</A></P>
<P>&nbsp;<BR><A HREF="/admin/" TARGET="_new" STYLE="text-decoration: none; border:0px; background-color:#FFD3D3; color:#000; font-weight:bold; padding:10px; cursor:pointer; border-radius:5px;">Admin: config changes</A></P>
<P>&nbsp;<BR></P>
<P>&nbsp;<BR></P>
<P>&nbsp;<BR></P>
$fCopyCR

</BODY>
</HTML>

EOF

}

# ooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo
#  Sub's SwDialog
# ooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo
#  Sub Switch Dialog

if ($ENV{"REQUEST_METHOD"} eq 'POST') {
	read(STDIN, $query, $ENV{CONTENT_LENGTH}) == $ENV{CONTENT_LENGTH}
		or return undef;
	push @keyValuePairs, split /&/, $query;
	$OK=1;
}

if ($ENV{"REQUEST_METHOD"} eq 'GET') {
	my $queryString = $ENV{"QUERY_STRING"};
#	@keyValuePairs = split(/\&/, $queryString);
	push @keyValuePairs, split /&/, $queryString;
	$OK=1;
}

if ( ! $OK eq 0 ) {
	contentHeader if ($wasContent == 0);
	print "Nothing Exiting $!";
}

$MyMethod=$ENV{REQUEST_METHOD};
$ContentLength=$ENV{CONTENT_LENGTH};
if ($query) {
$QueryString=$query;
} else {
$QueryString=$ENV{QUERY_STRING};
}

load_app_config;

if ($OK == 1) {
	foreach my $keyValuePair (@keyValuePairs) {
		(my $key, my $value) = split(/\=/, $keyValuePair);
		$key =~ s/%([a-f0-9]{2})/chr(hex($1))/eig; # URL decode the key
		$value =~ s/%([a-f0-9]{2})/chr(hex($1))/eig; # URL decode the value
		$params{$key} = $value;
#		print "<P>$key: $params{$key}</P>\n";
	}

	if ( ($ENV{"REQUEST_METHOD"} eq 'GET') and $params{'config'} eq 'yes' or ( ($ENV{"REQUEST_METHOD"} eq 'POST') and $params{'config'} eq 'yes' ) ) {
			load_config;
			exit 0;
	}

# ooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo
# Show Device ID
# ooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo
	if ( ($ENV{"REQUEST_METHOD"} eq 'POST') and $params{'man'} eq 'yes' and !($params{select_cisco_by_ip} eq '' ) and ( $params{'showDevID'} eq 'Show+Device+ID') ) {
	my $action="$configs{cidialog} $params{'select_cisco_by_ip'} showDevID";
	my $loc_date=`date "+%X.%N\ %d-%b-%Y"`;
	open(FIC,"$action |");
	my @results=<FIC>;
	close(FIC);
#	contentHeader;
	my $cnt=0;
	my $cntvl=0;
	foreach my $res (@results) {
		(my $key, my $value) = split(/\n/, $res);
		$params{$key} = $value;
		$key =~ s/\r|\n//g;
		$key =~ s/%([a-f0-9]{2})/chr(hex($1))/eig;
		$hw_model = sprintf "%s",$key if $key =~ m/Model\ number/;
		$hw_model =~ substr($hw_model,-2);
		$hw_portFastEth = sprintf "%02s",$key if $key =~ m/FastEthernet\ interfaces/;

		$hw_portGbitEth = sprintf "%s",$key if $key =~ m/Gigabit\ Ethernet\ interfaces/;
		$hw_swRunVersion = sprintf "%s",$key if $key =~ m/Version/;
		$hw_swUpTime = sprintf "%s",$key if $key =~ m/uptime/;
		$hw_SystemName = sprintf "%s",$key if $key =~ m/uptime/;
		$clock_time = sprintf "%s",$key if $key =~ m/\d\d:\d\d?:\d\d\.\d\d\d./;
#		if ( ($key =~ m/^Fa/) or ($key =~ m/^Gi/) ) {
		if ( ($key =~ m/^Fa\d+/) ) {
			my $MyPort='';
			my $MyPortDescription='';
			my $MyPortStatus='';
			my $MyPortVlanNr='';
			my $MyPortDuplex='';
			my $MyPortSpeed='';
			my $MyPortType='';
			if ( ($key =~ m/^Fa\d+/) or ($key =~ m/^Gi\d+/) ) {
				my @columns = split(//, $key);
				my $col_cnt=0;
				foreach my $letter (@columns) {
					$MyPort .= "${letter}" if ( ($col_cnt >= 0) and ($col_cnt <= 9) );
					$MyPort =~ s/\s+.*//g;
					$MyPortDescription .= "${letter}" if ( ($col_cnt >= 10) and ($col_cnt <= 28) );
					$MyPortDescription =~ s/%([a-f0-9]{2})/chr(hex($1))/eig;
					$MyPortStatus .= "${letter}" if ( ($col_cnt >= 29) and ($col_cnt <= 41) );
					$MyPortStatus =~ s/\s+.*//g;
					$MyPortVlanNr .= "${letter}" if ( ($col_cnt >= 42) and ($col_cnt <= 52) );
					$MyPortVlanNr =~ s/\s+.*//g;
					$MyPortDuplex .= "${letter}" if ( ($col_cnt >= 53) and ($col_cnt <= 60) );
					$MyPortDuplex =~ s/\s+.*//g;
					$MyPortSpeed .= "${letter}" if ( ($col_cnt >= 61) and ($col_cnt <= 66) );
					$MyPortSpeed =~ s/\s+.*//g;
					$MyPortType .= "${letter}" if ( ($col_cnt >= 67) and ($col_cnt <= 78) );
					$MyPortType =~ s/\s+.*//g;
					$col_cnt++ if $col_cnt < $#columns;
				}
				$port[$cnt] = "$MyPort";
				$port_description[$cnt] = "$MyPortDescription";
				$port_status[$cnt] = "$MyPortStatus";
				$port_vlan_nr[$cnt] = "$MyPortVlanNr";
				$port_duplex[$cnt] = "$MyPortDuplex";
				$port_speed[$cnt] = "$MyPortSpeed";
				$port_type[$cnt] = "$MyPortType";
			}
		}
#		if ( (($key =~ m/^\d+.*\d+/) and ($key =~ m/active|act\/unsup/)) and !( ($key =~ m/^Fa/) or
#						($key =~ m/^Gi/) or
#						($key =~ m/\d\d:\d\d?:\d\d\.\d\d\d./) or
#						($key =~ m/Gigabit\ Ethernet\ interfaces/) or
#						($key =~ m/FastEthernet\ interfaces/) or
#						($key =~ m/bytes\ of\ flash-simulated/)
#					) ) {

		if ( ( ($key =~ m/active|act\/unsup/) and ($key =~ m/^\d+.*/) and !($key == '' ) and ($key =~ m/[A-Za-z0-9]/)) and !( ($key =~ m/^Fa\d+/) or
						($key =~ m/^Fa\d+/) or
						($key =~ m/^Gi\d+/) or
						($key =~ m/\d\d:\d\d?:\d\d\.\d\d\d./) or
						($key =~ m/Gigabit\ Ethernet\ interfaces/) or
						($key =~ m/FastEthernet\ interfaces/) or
						($key =~ m/bytes\ of\ flash-simulated/)
					) ) {

        		$key =~ s/\n//;
                	(my $vlan_id, my $vlan_name, my $vlan_act) = split (/\s+/, $key,4);
			my $MyVlanActive='';
			my $MyVlanType='';
			$vlan_id[$cntvl]=$vlan_id;
			$vlan_name[$cntvl]=$vlan_name;
			$vlan_active[$cntvl]=$vlan_act;
#			$vlan_type[$cntvl]=$MyVlanType;
#			if ( ($vlan_id[$cntvl] =~ m/[0-9]/) or ($vlan_name[$cntvl] =~ m/[A-Za-z0-9]/) ) {
#				$cntvl++ if ( $cntvl eq $#vlan_id); 
#			}
			$cntvl++ if ( $cntvl eq $#vlan_id); 
		}
		$cnt++ if ( ($key =~ m/^Fa\d+/) or ($key =~ m/^Gi\d+/));
	}
# Formatting information
	$hw_portGbitEth =~ s/[^0-9]//g;
	$hw_portFastEth =~ s/[^0-9]//g;
	$hw_swUpTime =~ s/^[^\ ]*//;
	$hw_model =~ s/.*://g;
	$hw_SystemName =~ s/\s.*//;
	}

# ooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo
#  Manage Devices <ACTIONS>
# ooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo

# ooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo
# Set Device Timezone and Clock Time And show it
# ooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo
	if ( ($ENV{"REQUEST_METHOD"} eq 'POST') and $params{'man'} eq 'yes' and !($params{select_cisco_by_ip} eq '' ) and ( $params{'setTime'} eq 'Set+Time') ) { 

	my $action="$configs{cidialog} $params{'select_cisco_by_ip'} setTime";
	my $loc_date=`date "+%X.%N\ %d-%b-%Y"`;
	open(FIC,"$action |");
	my @results=<FIC>;
	close(FIC);
	foreach my $res (@results) {
		(my $key, my $value) = split(/\n/, $res);
		$params{$key} = $value;
		$key =~ s/\r|\n//g;
		$key =~ s/%([a-f0-9]{2})/chr(hex($1))/eig;
		$clock_time = sprintf "%s",$key if $key =~ m/\d\d:\d\d?:\d\d\.\d\d\d.*/;
	}
	}


# ooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo
# saveConfig Form
# ooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo

my $fSaveConfig = sprintf <<EOF;

<FORM ACTION="/cgi-bin/catman.cgi" METHOD="POST" TARGET="_body">
<INPUT TYPE="hidden" NAME="config" VALUE="no">
<INPUT TYPE="hidden" NAME="man" VALUE="yes">
<INPUT TYPE="hidden" NAME="select_cisco_by_ip" VALUE="$params{select_cisco_by_ip}">
<INPUT TYPE="submit" NAME="saveConfig" VALUE="Save Device Config"></P>

<P>&nbsp;<BR>
<P>&nbsp;<BR>
<P>&nbsp;<BR>
<P>&nbsp;<BR>

</FORM>


EOF

# ooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo
# Manage diff configs
# ooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo

	if ( ($ENV{"REQUEST_METHOD"} eq 'POST') and $params{'man'} eq 'yes' and !($params{select_cisco_by_ip} eq '' ) and ( $params{'showConfigChanges'} eq 'Show+config+changes') ) { 

# config show for all and build list of devices with changes


# changes_new_begin
	open (File,'<', $configs{cidevices}) or die "$!";
	my @results = <File>;
	close (File);

my $cfDiffFormOut = sprintf <<EOF;

<HTML>
<HEAD>
<META HTTP-EQUIV="Pragma" CONTENT="no-cache">
<META HTTP-EQUIV="Expires" CONTENT="-1">
<TITLE>MF SYSTEMS CISCO PORT ON/OFF</TITLE>
</HEAD>
<STYLE TYPE="text/css">
input[type=submit] {
    padding:5px 15px;
    background:#FAA;
    border:0 none;
    cursor:pointer;
    -webkit-border-radius: 5px;
    border-radius: 5px;
}
.button {
    color: #FF00AA
}
.button_on {
    color: #99DD99
}
</STYLE>
<BODY>
EOF

	foreach my $line(@results) {
        my $addr;
        my $name;
        my $acPass;
        my $enPass;
        my $other;
        chop $line;
        if ( !($line =~ m/^#/) ) {
        	($addr,$name,$acPass,$enPass,$other) = split /\s*:\s*/,$line,5;
#        	printf "<P><B>&nbsp;[$addr]&nbsp;<BR>&nbsp;[$name]&nbsp;<BR>&nbsp;[$acPass]&nbsp;<BR>&nbsp;[$enPass]&nbsp;<BR>&nbsp;[$other]</B></P>\n";
	my $cmd_dev_diff_conf="$configs{cidialog} $addr isConfigChangeDiff";
	open(FIC,"$cmd_dev_diff_conf |");
	my @results_diff=<FIC>;
	close(FIC);

	my $encrypt_md5 = md5_hex(@results_diff);
	my $filename = "/etc/catman/changes/checkconf_$addr.md5";
	my $mdok=1;
	my $knownmd5='';
	if ( -f $filename ) {
		open(FIC,"$filename");
		$knownmd5=<FIC>;
		close(FIC);
		if ( "$encrypt_md5" eq "$knownmd5" ) {
			$mdok=0;
		}
	} else {
		open my $fh, '>>', $filename;
		print $fh $encrypt_md5;
		close $fh;
	}
	if ((@results_diff ne '') and ($mdok == 1 )) {

$cfDiffFormOut .= sprintf <<EOF;
<P>Config was changed for&nbsp;<B>$name&nbsp;($addr)</B><BR>
<PRE>DISCOVERED:$encrypt_md5<BR>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;SAVED:$knownmd5</PRE><BR>
<P><PRE>@results_diff</PRE><BR></P>
EOF

# dev_config_save
#		print "<P>Would you want to save config device?<BR>";
#		print <<EOF;
#<FORM ACTION="/cgi-bin/catman.cgi" METHOD="POST" TARGET="_body">
#<INPUT TYPE="hidden" NAME="config" VALUE="no">
#<INPUT TYPE="hidden" NAME="man" VALUE="yes">
#<INPUT TYPE="hidden" NAME="select_cisco_by_ip" VALUE="$params{select_cisco_by_ip}">
#<INPUT TYPE="hidden" NAME="newConfID" VALUE="$encrypt_md5">
#<INPUT TYPE="submit" NAME="saveConfig" VALUE="Save Device Config"></P>
#
#<P>&nbsp;<BR>
#<P>&nbsp;<BR>
#<P>&nbsp;<BR>
#<P>&nbsp;<BR>
#</FORM>
#
#EOF
#$cfDiffFormOut .= sprintf <<EOF;
#</BODY></HTML>
#EOF

#		open(FIC,"$filename");
# send mail to operator
# #		my $cmd_x="echo \"@results_diff\" \|/usr/bin/mutt -s \"Cisco $params{'select_cisco_by_ip'} from \$(hostname)\" $configs{'mailto'}";
#		my $cmd_x="echo \"@results_diff\" \|/usr/bin/mutt -s \"Cisco $params{'select_cisco_by_ip'} from \$(hostname)\" $configs{mailto}";
#		open(CMD,"$cmd_x |");
#		my @res=<CMD>;
#		close(CMD);
	} elsif ((@results_diff ne '') and ($mdok == 0 )) {
$cfDiffFormOut .= sprintf <<EOF;
<P>No changes for&nbsp;<B>$name&nbsp;($addr)</B><BR> from last saved state</B><BR>
<PRE>DISCOVERED:$encrypt_md5<BR>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;SAVED:$knownmd5</PRE><BR>
<PRE>@results_diff</PRE><BR></P>
EOF
	}

# **********
        }
	}
$cfDiffFormOut .= sprintf <<EOF;
</BODY></HTML>
EOF

contentHeader if ($wasContent == 0);
$wasContent=1;
print $cfDiffFormOut;

}
# changes_new_end

# ooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo
# Manage port Up/Down
# ooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo
	if ( ($ENV{"REQUEST_METHOD"} eq 'POST') and $params{'man'} eq 'yes' and !($params{select_cisco_by_ip} eq '' ) and ( $params{'putDownUpPort'} eq 'Port+Down/Up') ) { 
	my $action="$configs{cidialog} $params{'select_cisco_by_ip'} putDownUpPort state";
	my $loc_date=`date "+%X.%N\ %d-%b-%Y"`;
	open(FIC,"$action |");
	my @results=<FIC>;
	close(FIC);
	my $cnt=0;

	foreach my $res (@results) {
		(my $key, my $value) = split(/\a \t/, $res);
		$params{$key} = $value;
		$key =~ s/\r|\n//g;
		$key =~ s/%([a-f0-9]{2})/chr(hex($1))/eig;
		my $MyPort='';
		my $MyPortDescription='';
		my $MyPortStatus='';
		my $MyPortVlanNr='';
		my $MyPortDuplex='';
		my $MyPortSpeed='';
		my $MyPortType='';

		if ( ($key =~ m/^Fa\d+/) ) {
			my @columns = split(//, $key);
			my $col_cnt=0;
			foreach my $letter (@columns) {
				$MyPort .= "${letter}" if ( ($col_cnt >= 0) and ($col_cnt <= 9) );
				$MyPort =~ s/\s+.*//g;
				$MyPortDescription .= "${letter}" if ( ($col_cnt >= 10) and ($col_cnt <= 28) );
				$MyPortDescription =~ s/%([a-f0-9]{2})/chr(hex($1))/eig;
				$MyPortStatus .= "${letter}" if ( ($col_cnt >= 29) and ($col_cnt <= 41) );
				$MyPortStatus =~ s/\s+.*//g;
				$MyPortVlanNr .= "${letter}" if ( ($col_cnt >= 42) and ($col_cnt <= 52) );
				$MyPortVlanNr =~ s/\s+.*//g;
				$MyPortDuplex .= "${letter}" if ( ($col_cnt >= 53) and ($col_cnt <= 60) );
				$MyPortDuplex =~ s/\s+.*//g;
				$MyPortSpeed .= "${letter}" if ( ($col_cnt >= 61) and ($col_cnt <= 66) );
				$MyPortSpeed =~ s/\s+.*//g;
				$MyPortType .= "${letter}" if ( ($col_cnt >= 67) and ($col_cnt <= 78) );
				$MyPortType =~ s/\s+.*//g;
				$col_cnt++ if $col_cnt < $#columns;
			}
			$port[$cnt] = "$MyPort";
			$port_description[$cnt] = "$MyPortDescription";
			$port_status[$cnt] = "$MyPortStatus";
			$port_vlan_nr[$cnt] = "$MyPortVlanNr";
			$port_duplex[$cnt] = "$MyPortDuplex";
			$port_speed[$cnt] = "$MyPortSpeed";
			$port_type[$cnt] = "$MyPortType";
			$cnt++;
		}	
	}
	}

# ooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo
# Manage Port Vlan Assignement
# ooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo

	if ( ($ENV{"REQUEST_METHOD"} eq 'POST') and $params{'man'} eq 'yes' and !($params{select_cisco_by_ip} eq '' ) and ( $params{'changePortVlan'} eq 'Change+Port+Vlan') ) {
	my $action="$configs{cidialog} $params{'select_cisco_by_ip'} showDevID";
	my $loc_date=`date "+%X.%N\ %d-%b-%Y"`;
	open(FIC,"$action |");
	my @results=<FIC>;
	close(FIC);
#	contentHeader;
	my $cnt=0;
	my $cntvl=0;
	foreach my $res (@results) {
		(my $key, my $value) = split(/\n/, $res);
		$params{$key} = $value;
		$key =~ s/\r|\n//g;
		$key =~ s/%([a-f0-9]{2})/chr(hex($1))/eig;
		$hw_model = sprintf "%s",$key if $key =~ m/Model\ number/;
		$hw_model =~ substr($hw_model,-2);
		$hw_portFastEth = sprintf "%02s",$key if $key =~ m/FastEthernet\ interfaces/;

		$hw_swRunVersion = sprintf "%s",$key if $key =~ m/Version/;
		$hw_swUpTime = sprintf "%s",$key if $key =~ m/uptime/;
		$hw_SystemName = sprintf "%s",$key if $key =~ m/uptime/;
		$clock_time = sprintf "%s",$key if $key =~ m/\d\d:\d\d?:\d\d\.\d\d\d./;
		if ( ($key =~ m/^Fa\d+/) ) {
			my $MyPort='';
			my $MyPortDescription='';
			my $MyPortStatus='';
			my $MyPortVlanNr='';
			my $MyPortDuplex='';
			my $MyPortSpeed='';
			my $MyPortType='';
			if ( ($key =~ m/^Fa\d+/) ) {
				my @columns = split(//, $key);
				my $col_cnt=0;
				foreach my $letter (@columns) {
					$MyPort .= "${letter}" if ( ($col_cnt >= 0) and ($col_cnt <= 9) );
					$MyPort =~ s/\s+.*//g;
					$MyPortDescription .= "${letter}" if ( ($col_cnt >= 10) and ($col_cnt <= 28) );
					$MyPortDescription =~ s/%([a-f0-9]{2})/chr(hex($1))/eig;
					$MyPortStatus .= "${letter}" if ( ($col_cnt >= 29) and ($col_cnt <= 41) );
					$MyPortStatus =~ s/\s+.*//g;
					$MyPortVlanNr .= "${letter}" if ( ($col_cnt >= 42) and ($col_cnt <= 52) );
					$MyPortVlanNr =~ s/\s+.*//g;
					$MyPortDuplex .= "${letter}" if ( ($col_cnt >= 53) and ($col_cnt <= 60) );
					$MyPortDuplex =~ s/\s+.*//g;
					$MyPortSpeed .= "${letter}" if ( ($col_cnt >= 61) and ($col_cnt <= 66) );
					$MyPortSpeed =~ s/\s+.*//g;
					$MyPortType .= "${letter}" if ( ($col_cnt >= 67) and ($col_cnt <= 78) );
					$MyPortType =~ s/\s+.*//g;
					$col_cnt++ if $col_cnt < $#columns;
				}
				$port[$cnt] = "$MyPort";
				$port_description[$cnt] = "$MyPortDescription";
				$port_status[$cnt] = "$MyPortStatus";
				$port_vlan_nr[$cnt] = "$MyPortVlanNr";
				$port_duplex[$cnt] = "$MyPortDuplex";
				$port_speed[$cnt] = "$MyPortSpeed";
				$port_type[$cnt] = "$MyPortType";
			}
		}
                if ( ( ($key =~ m/active|act\/unsup/) and ($key =~ m/^\d+.*/) and !($key == '' ) and ($key =~ m/[A-Za-z0-9]/)) and !( ($key =~ m/^Fa\d+/) or
                                                ($key =~ m/^Fa\d+/) or
                                                ($key =~ m/^Gi\d+/) or
                                                ($key =~ m/\d\d:\d\d?:\d\d\.\d\d\d./) or
                                                ($key =~ m/Gigabit\ Ethernet\ interfaces/) or
                                                ($key =~ m/FastEthernet\ interfaces/) or
                                                ($key =~ m/bytes\ of\ flash-simulated/)
                                        ) ) {

                        $key =~ s/\n//;
                        (my $vlan_id, my $vlan_name, my $vlan_act) = split (/\s+/, $key,4);
                        $vlan_id[$cntvl]=$vlan_id;
                        $vlan_name[$cntvl]=$vlan_name;
                        $vlan_active[$cntvl]=$vlan_act;
                        $cntvl++ if ( $cntvl eq $#vlan_id);
		}
		$cnt++ if ( ($key =~ m/^Fa\d+/) );

	}
# Formatting information
	$hw_portGbitEth =~ s/[^0-9]//g;
	$hw_portFastEth =~ s/[^0-9]//g;
	$hw_swUpTime =~ s/^[^\ ]*//;
	$hw_model =~ s/.*://g;
	$hw_SystemName =~ s/\s.*//;
	}

# ooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo

# ooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo
# Clear port counters
# ooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo

	if ( ($ENV{"REQUEST_METHOD"} eq 'POST') and $params{'man'} eq 'yes' and !($params{select_cisco_by_ip} eq '' ) and ( $params{'clearPortCounters'} eq 'Clear+Port+Counters') ) { 
	contentHeader if ($wasContent == 0);
	$wasContent=1;
	print "Please Wait. Gathering detailed errors from device IP $params{'select_cisco_by_ip'}...<BR>\n";
	my $action="$configs{cidialog} $params{'select_cisco_by_ip'} putDownUpPort state";
	my $loc_date=`date "+%X.%N\ %d-%b-%Y"`;
	open(FIC,"$action |");
	my @results=<FIC>;
	close(FIC);
	my $cnt=0;
	foreach my $res (@results) {
		(my $key, my $value) = split(/\a \t/, $res);
		$params{$key} = $value;
		$key =~ s/\r|\n//g;
		$key =~ s/%([a-f0-9]{2})/chr(hex($1))/eig;
		my $MyPort='';
		my $MyPortDescription='';
		my $MyPortStatus='';
		my $MyPortVlanNr='';
		my $MyPortDuplex='';
		my $MyPortSpeed='';
		my $MyPortType='';
		if ( ($key =~ m/^Fa\d+/) ) {
			my @columns = split(//, $key);
			my $col_cnt=0;
			foreach my $letter (@columns) {
				$MyPort .= "${letter}" if ( ($col_cnt >= 0) and ($col_cnt <= 9) );
				$MyPort =~ s/\s+.*//g;
				$MyPortDescription .= "${letter}" if ( ($col_cnt >= 10) and ($col_cnt <= 28) );
				$MyPortDescription =~ s/%([a-f0-9]{2})/chr(hex($1))/eig;
				$MyPortStatus .= "${letter}" if ( ($col_cnt >= 29) and ($col_cnt <= 41) );
				$MyPortStatus =~ s/\s+.*//g;
				$MyPortVlanNr .= "${letter}" if ( ($col_cnt >= 42) and ($col_cnt <= 52) );
				$MyPortVlanNr =~ s/\s+.*//g;
				$MyPortDuplex .= "${letter}" if ( ($col_cnt >= 53) and ($col_cnt <= 60) );
				$MyPortDuplex =~ s/\s+.*//g;
				$MyPortSpeed .= "${letter}" if ( ($col_cnt >= 61) and ($col_cnt <= 66) );
				$MyPortSpeed =~ s/\s+.*//g;
				$MyPortType .= "${letter}" if ( ($col_cnt >= 67) and ($col_cnt <= 78) );
				$MyPortType =~ s/\s+.*//g;
				$col_cnt++ if $col_cnt < $#columns;
			}
			$port[$cnt] = "$MyPort";
			$port_description[$cnt] = "$MyPortDescription";
			$port_status[$cnt] = "$MyPortStatus";
			$port_vlan_nr[$cnt] = "$MyPortVlanNr";
			$port_duplex[$cnt] = "$MyPortDuplex";
			$port_speed[$cnt] = "$MyPortSpeed";
			$port_type[$cnt] = "$MyPortType";
			$cnt++;
		}
	}

my $fErrorContent = sprintf <<EOF;

<HTML>
<HEAD>
<META HTTP-EQUIV="Pragma" CONTENT="no-cache">
<META HTTP-EQUIV="Expires" CONTENT="-1">
<TITLE>MF SYSTEMS CISCO PORT ON/OFF</TITLE>
</HEAD>
<STYLE TYPE="text/css">
input[type=submit] {
    padding:5px 15px;
    background:#FAA;
    border:0 none;
    cursor:pointer;
    -webkit-border-radius: 5px;
    border-radius: 5px;
}
.button {
    color: #FF00AA
}
.button_on {
    color: #99DD99
}
</STYLE>
<BODY>
<TABLE ALIGN="center" BORDER=1>

EOF

	my $ccp=0;
	my $syscmd="$configs{cidialog} $params{'select_cisco_by_ip'} portCounterStats";
	open(FIC,"$syscmd |");
	my @err_res=<FIC>;
	close(FIC);
	my %errors_port=();
	my $lines_cnt=0;
	my $tabbgcol='';

#############################################################################
## NEWCODE
#############################################################################

REGEX:
while ( <@err_res> ) {
        $err_res[$lines_cnt] =~ s/\r|\n//g;
        $err_res[$lines_cnt] =~ s/%([a-f0-9]{2})/chr(hex($1))/eig;
        if ( $err_res[$lines_cnt] =~ m/^GigabitEthernet[0-9]+.*$/ ) { $lines_cnt++; next REGEX; }
        if ( $err_res[$lines_cnt] =~ m/^FastEthernet[0-9]+.*$/) {
                if ( ($err_res[$lines_cnt] =~ m/\s+.*\ d+\ output\ buffers\ swapped\ out/) ) {
                        print "** MATCH LAST LINE $lines_cnt";
                        next REGEX;
                } elsif ( ($err_res[$lines_cnt] !~ m/\s+.*\ d+\ output\ buffers\ swapped\ out/) ) {
                        for (my $i=0; $i<28; $i++) {
                                my $cmnt=$lines_cnt+$i;
                                if ( $err_res[$cmnt] =~ m/^FastEthernet[0-9]+.*$/ ) {
                                        next;
                                } else {
                                        $errors_port{$port[$ccp]} .= $err_res[$cmnt] if (  ($err_res[$cmnt] =~ m/\s+.*input errors,/)
											or ($err_res[$cmnt] =~ m/\s+.*output errors,/)
											or ($err_res[$cmnt] =~ m/\s+.*late collision,/)
											or ($err_res[$cmnt] =~ m/\s+.*lost carrier,/)
											or ($err_res[$cmnt] =~ m/\s+.*output buffer failures,/)
											);
#					DEBUG
#					contentHeader if ($wasContent == 0);
#					print "<TD BGCOLOR=\"$tabbgcol\"><P><PRE>$errors_port{$port[$ccp]}</PRE></P></TD>";
					
                                }
                        }
#DUMP:<BR>\n
#$port[$ccp]<BR>\n
#$errors_port{$port[$ccp]}<BR>\n
#<SVG HEIGHT="10" WIDTH="210">
#<LINE x1="0" y1="0" x2="200" y2="0" STYLE="stroke:rgb(255,0,0);stroke-width:10" />
#</SVG>
                        if ( $err_res[$lines_cnt] =~ m/^FastEthernet[0-9]+.*$/) {
				$ccp++;
			}
                        $lines_cnt++;
#                        if ( $lines_cnt == 4401 ) { next; }
                }
                if ($err_res[$lines_cnt] =~ m/^FastEthernet[0-9]+.*$/) {
			$ccp++;
		}
        }
        $lines_cnt++;
        if ( $lines_cnt == 4402 ) { next; }
}

#############################################################################
## NEWCODE
#############################################################################

	my $ccp=0;
	foreach my $p (@port) {
#		DEBUG
#		contentHeader if ($wasContent == 0);
#		print "<TD BGCOLOR=\"$tabbgcol\"><P>$ccp&nbsp;$port[$ccp]&nbsp;<PRE>$errors_port{$port[$ccp]}</PRE></P></TD>";
		

		if( $port[$ccp] =~ m/Fa\d+/) {
			if ($ccp % 2) {
				$tabbgcol='#A0A0FE';
			} else {
				$tabbgcol='#CCCCEF';
			}
			$fErrorContent .= sprintf <<EOF;
<TR>
<TD ALIGN="center" VALIGN="top">
<FORM ACTION="/cgi-bin/catman.cgi" METHOD="POST" TARGET="_body">
<INPUT TYPE="hidden" NAME="man" VALUE="yes">
<INPUT TYPE="hidden" NAME="select_cisco_by_ip" VALUE="$params{'select_cisco_by_ip'}">
<INPUT TYPE="hidden" NAME="swPort" VALUE="$port[$ccp]">
<INPUT TYPE="submit" NAME="resetPortCounters" VALUE="Reset Counters">
</FORM><B>$port[$ccp]</B></TD>
<TD BGCOLOR="$tabbgcol"><P><PRE>$errors_port{$port[$ccp]}</PRE></P></TD>
</TR>
EOF
			$ccp++;
                }
	}

$fErrorContent .= sprintf <<EOF;
</TABLE>
</BODY>
</HTML>
EOF

	contentHeader if ($wasContent == 0);
	print "\r".$fErrorContent."\n";
	}
	


# ooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo
# Save config
# ooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo

my $fSaveConfigStart = sprintf <<EOF;

<HTML>
<BODY>
<P>Saving config to following device IP <B>$params{select_cisco_by_ip}</B>. Please wait...</P>
</BODY>
</HTML>

EOF

	if ( ($ENV{"REQUEST_METHOD"} eq 'POST') and $params{'man'} eq 'yes' and !($params{select_cisco_by_ip} eq '' ) and ( $params{'saveConfig'} eq 'Save+Device+Config') ) { 
		contentHeader if ($wasContent == 0);
		$wasContent = 1;
		print $fSaveConfigStart . "\n";
		my $action="$configs{cidialog} $params{'select_cisco_by_ip'} saveConfig";
		open(FIC,"$action |");
		my @results=<FIC>;
		close(FIC);
		my $filename = "/etc/catman/changes/checkconf_$params{'select_cisco_by_ip'}.md5";
                open my $fh, '>', $filename;
                print $fh $params{'newConfID'};
                close $fh;
	}

# ooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo
# Manage port Description
# ooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo

	if ( ($ENV{"REQUEST_METHOD"} eq 'POST') and $params{'man'} eq 'yes' and !($params{select_cisco_by_ip} eq '' ) and ( $params{'descPortChange'} eq 'Change+Port+Description') ) { 
	my $action="$configs{cidialog} $params{'select_cisco_by_ip'} putDownUpPort state";
	my $loc_date=`date "+%X.%N\ %d-%b-%Y"`;
	open(FIC,"$action |");
	my @results=<FIC>;
	close(FIC);
	my $cnt=0;
	foreach my $res (@results) {
		(my $key, my $value) = split(/\a \t/, $res);
		$params{$key} = $value;
		$key =~ s/\r|\n//g;
		$key =~ s/%([a-f0-9]{2})/chr(hex($1))/eig;
		my $MyPort='';
		my $MyPortDescription='';
		my $MyPortStatus='';
		my $MyPortVlanNr='';
		my $MyPortDuplex='';
		my $MyPortSpeed='';
		my $MyPortType='';
		if ( ($key =~ m/^Fa\d+/) ) {
			my @columns = split(//, $key);
			my $col_cnt=0;
			foreach my $letter (@columns) {
				$MyPort .= "${letter}" if ( ($col_cnt >= 0) and ($col_cnt <= 9) );
				$MyPort =~ s/\s+.*//g;
				$MyPortDescription .= "${letter}" if ( ($col_cnt >= 10) and ($col_cnt <= 28) );
				$MyPortDescription =~ s/%([a-f0-9]{2})/chr(hex($1))/eig;
				$MyPortStatus .= "${letter}" if ( ($col_cnt >= 29) and ($col_cnt <= 41) );
				$MyPortStatus =~ s/\s+.*//g;
				$MyPortVlanNr .= "${letter}" if ( ($col_cnt >= 42) and ($col_cnt <= 52) );
				$MyPortVlanNr =~ s/\s+.*//g;
				$MyPortDuplex .= "${letter}" if ( ($col_cnt >= 53) and ($col_cnt <= 60) );
				$MyPortDuplex =~ s/\s+.*//g;
				$MyPortSpeed .= "${letter}" if ( ($col_cnt >= 61) and ($col_cnt <= 66) );
				$MyPortSpeed =~ s/\s+.*//g;
				$MyPortType .= "${letter}" if ( ($col_cnt >= 67) and ($col_cnt <= 78) );
				$MyPortType =~ s/\s+.*//g;
				$col_cnt++ if $col_cnt < $#columns;
			}
			$port[$cnt] = "$MyPort";
			$port_description[$cnt] = "$MyPortDescription";
			$port_status[$cnt] = "$MyPortStatus";
			$port_vlan_nr[$cnt] = "$MyPortVlanNr";
			$port_duplex[$cnt] = "$MyPortDuplex";
			$port_speed[$cnt] = "$MyPortSpeed";
			$port_type[$cnt] = "$MyPortType";
			$cnt++;
		}	
	}
	}
}

	my $fContentTop = sprintf <<EOF;

<HTML>
<HEAD>
<META HTTP-EQUIV="refresh" CONTENT="5">
<META HTTP-EQUIV="Pragma" CONTENT="no-cache">
<META HTTP-EQUIV="Expires" CONTENT="-1">
<TITLE>MF SYSTEMS CISCO</TITLE>
</HEAD>
<BODY>
<TABLE BORDER="1">
<TR><TH>Device Name/Identity/Model</TH><TH>Eth. Port count</TH><TH>Gbit. port count</TH><TH>Clock</TH></TR>
<TR><TD VALIGN="center" ALIGN="center">[${hw_SystemName}]&nbsp;/&nbsp;[${hw_model}]</TD><TD VALIGN="center" ALIGN="center">${hw_portFastEth}</TD><TD VALIGN="center" ALIGN="center">${hw_portGbitEth}</TD>
EOF
if ( ($clock_time =~ m/^\*\d\d:\d\d?:\d\d\.\d\d\d./) ) {
$fContentTop .= sprintf <<EOF;
<TD><B>Time device after boot. Change it!</B><BR>$clock_time<BR>
<FORM ACTION="/cgi-bin/catman.cgi" METHOD="POST" TARGET="_body">
<INPUT TYPE="hidden" NAME="config" VALUE="no">
<INPUT TYPE="hidden" NAME="man" VALUE="yes">
<INPUT TYPE="hidden" NAME="select_cisco_by_ip" VALUE="$params{'select_cisco_by_ip'}">
Set Clock Time and date from this OS<BR>
<INPUT TYPE="submit" NAME="setTime" VALUE="Set Time"></P>
</FORM>
</TD>
EOF
# ooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo
} else {
$fContentTop .= sprintf <<EOF;
<TD>$clock_time</TD>
EOF
}

$fContentTop .= sprintf <<EOF;
</TR>
</TABLE>
&nbsp;
</BODY>
</HTML>

EOF


	my $fContentPlain = sprintf <<EOF;

<HTML>
<HEAD>
<META HTTP-EQUIV="Pragma" CONTENT="no-cache">
<META HTTP-EQUIV="Expires" CONTENT="-1">
<TITLE>MF SYSTEMS CISCO</TITLE>
</HEAD>
<BODY>
<TABLE BORDER="1">
<TR><TH>Port #</TH><TH>Port Description</TH><TH>Port State</TH><TH>Vlan # / Vlan Name</TH></TR>
EOF

my $cnt=0;
foreach my $p (@port) {
	my $bgcolor="#FFFFFF";
	my $focolor="#000000";
	my $VlanName='';
	if ($port_status[$cnt] =~ "connected") {
		$bgcolor="#AFFFAF";
		$focolor="#000000";
	} elsif ($port_status[$cnt] =~ "disabled") {
		$bgcolor="#AF1020";
		$focolor="#FFFFFF";
	} elsif ($port_status[$cnt] =~ "notconnected") {
	} else {
		$bgcolor="#A0A0FA";
		$focolor="#FFFFFF";
	}
	my $vlan_cnt=0;
	foreach my $vlan_id (@vlan_id) {
	if ($port_vlan_nr[$cnt] =~ $vlan_id[$vlan_cnt]) {
	 	$VlanName = $vlan_name[$vlan_cnt];
	}
	$vlan_cnt++;
	}

if ( $p ~~ m/Fa/ ) {
	$fContentPlain .= sprintf <<EOF;
<TR><TD>&nbsp;<B>$p</B>&nbsp;</TD><TD>$port_description[$cnt]</TD><TD BGCOLOR="${bgcolor}"><FONT COLOR="${focolor}">$port_status[$cnt]</FONT></TD><TD ALIGN="center">$port_vlan_nr[$cnt]&nbsp;/&nbsp;$VlanName</TD></TR>
EOF
}

$cnt++;
}

	$fContentPlain .= sprintf <<EOF;
</TABLE>
</BODY>
</HTML>

EOF


	my $fContentPortOnOff = <<EOF;

<HTML>
<HEAD>
<META HTTP-EQUIV="Pragma" CONTENT="no-cache">
<META HTTP-EQUIV="Expires" CONTENT="-1">
<TITLE>MF SYSTEMS CISCO PORT ON/OFF</TITLE>
</HEAD>
<STYLE TYPE="text/css">
input[type=submit] {
    padding:5px 15px; 
    background:#FAA; 
    border:0 none;
    cursor:pointer;
    -webkit-border-radius: 5px;
    border-radius: 5px; 
}
.button_off {
    color: #FF00AA
}
.button_on {
    color: #99DD99
}
</STYLE>
<BODY>
<TABLE BORDER="1">
<TR><TH>Port #</TH><TH>Port State</TH><TH>Administrative Enable or Disable</TH></TR>
EOF

#my $cnt=0;
$cnt=0;
foreach my $p (@port) {
	my $thisPort='';
	my $ThisForm='';
	my $bgcolor="#FFFFFF";
	my $focolor="#000000";
	if ($port_status[$cnt] =~ m/connected/) {
		$bgcolor="#AFFFAF";
		$focolor="#000000";
		$ThisForm=sprintf <<EOF;
<FORM ACTION="/cgi-bin/catman.cgi" NAME="swPortOnOff" METHOD="POST" TARGET="_body">
<INPUT TYPE="hidden" NAME="config" VALUE="no">
<INPUT TYPE="hidden" NAME="man" VALUE="yes">
<INPUT TYPE="hidden" NAME="select_cisco_by_ip" VALUE="$params{'select_cisco_by_ip'}">
<INPUT TYPE="hidden" NAME="swPort" VALUE="$p">
<INPUT TYPE="submit" NAME="setPortOff" VALUE="Switch Port Off" CLASS="button_off">
</FORM>
EOF
	} elsif ($port_status[$cnt] =~ m/err-disabled/) {
		$bgcolor="#FF00FF";
		$focolor="#FFFFFF";
		$ThisForm=sprintf <<EOF;
<FORM ACTION="/cgi-bin/catman.cgi" NAME="swPortOnOff" METHOD="POST" TARGET="_body">
<INPUT TYPE="hidden" NAME="config" VALUE="no">
<INPUT TYPE="hidden" NAME="man" VALUE="yes">
<INPUT TYPE="hidden" NAME="select_cisco_by_ip" VALUE="$params{'select_cisco_by_ip'}">
<INPUT TYPE="hidden" NAME="swPort" VALUE="$p">
<INPUT TYPE="submit" NAME="setPortOff" VALUE="Switch Port Off" CLASS="button_off">
</FORM>
EOF
	} elsif ($port_status[$cnt] =~ m/disabled/) {
		$bgcolor="#AF1020";
		$focolor="#FFFFFF";
		$ThisForm=sprintf <<EOF;
<FORM ACTION="/cgi-bin/catman.cgi" NAME="swPortOnOff" METHOD="POST" TARGET="_body">
<INPUT TYPE="hidden" NAME="config" VALUE="no">
<INPUT TYPE="hidden" NAME="man" VALUE="yes">
<INPUT TYPE="hidden" NAME="select_cisco_by_ip" VALUE="$params{'select_cisco_by_ip'}">
<INPUT TYPE="hidden" NAME="swPort" VALUE="$p">
<INPUT TYPE="submit" NAME="setPortOn" VALUE="Switch Port On" CLASS="button_on">
</FORM>
EOF
	} elsif ($port_status[$cnt] =~ m/notconnect/) {
		$bgcolor="#A0A0FA";
		$focolor="#FFFFFF";
                $ThisForm=sprintf <<EOF;
<FORM ACTION="/cgi-bin/catman.cgi" NAME="swPortOnOff" METHOD="POST" TARGET="_body">
<INPUT TYPE="hidden" NAME="config" VALUE="no">
<INPUT TYPE="hidden" NAME="man" VALUE="yes">
<INPUT TYPE="hidden" NAME="select_cisco_by_ip" VALUE="$params{'select_cisco_by_ip'}">
<INPUT TYPE="hidden" NAME="swPort" VALUE="$p">
<INPUT TYPE="submit" NAME="setPortOff" VALUE="Switch Port Off">
</FORM>
EOF
	}

if ( $port_vlan_nr[$cnt] !~ m/trunk/ ) {
	$fContentPortOnOff .= sprintf <<EOF;
<TR><TD>&nbsp;<B>$p</B>&nbsp;</TD><TD BGCOLOR="$bgcolor"><FONT COLOR="${focolor}">$port_status[$cnt]</FONT></TD><TD>
	$ThisForm
</TD></TR>
EOF
} elsif ( $port_vlan_nr[$cnt] ~~ m/trunk/ ) {
	$fContentPortOnOff .= sprintf <<EOF;
<TR><TD>&nbsp;<B>$p</B>&nbsp;</TD><TD BGCOLOR="$bgcolor"><FONT COLOR="${focolor}">$port_status[$cnt]</FONT></TD><TD>
<FONT COLOR="#FF0000"><B>&nbsp;Warning&nbsp;trunk!;&nbsp;</B></FONT>
<P>$ThisForm</P>
</TD></TR>
EOF

}

	$ThisForm='';
	$cnt++;

}

	$fContentPortOnOff .= sprintf <<EOF;
</TABLE>
</BODY>
</HTML>

EOF


	my $fContentPortDescription = sprintf <<EOF;
<HTML>
<HEAD>
<META HTTP-EQUIV="Pragma" CONTENT="no-cache">
<META HTTP-EQUIV="Expires" CONTENT="-1">
<TITLE>MF SYSTEMS CISCO PORT ON/OFF</TITLE>
</HEAD>
<STYLE TYPE="text/css">
input[type=submit] {
    padding:5px 15px;
    background:#FFAAAA;
    border:0 none;
    cursor:pointer;
    -webkit-border-radius: 5px;
    border-radius: 5px;
}
.button_off {
    color: #FF00AA
}
.button_on {
    color: #000000
}
</STYLE>
<BODY>
<TABLE BORDER="1">
<TR><TH>Port #</TH><TH>Old Port Description</TH><TH>new Port Description - Change</TH></TR>

EOF


$cnt=0;
foreach my $p (@port) {
        $fContentPortDescription .= sprintf <<EOF;
<TR><TD>&nbsp;<B>$p</B>&nbsp;</TD>
<TD><B>$port_description[$cnt]</B></TD>
<TD>
EOF

if ($port_vlan_nr[$cnt] !~ m/trunk/) {

$fContentPortDescription .= sprintf <<EOF;
<FORM ACTION="/cgi-bin/catman.cgi" NAME="portDescriptionChange" METHOD="POST" TARGET="_body">
<INPUT TYPE="hidden" NAME="swPort" VALUE="$p">
<INPUT TYPE="hidden" NAME="man" VALUE="yes">
<INPUT TYPE="hidden" NAME="select_cisco_by_ip" VALUE="$params{select_cisco_by_ip}">
<INPUT TYPE="text" NAME="NewPortDescription" MAXLENGTH=19 VALUE="New Description">
<INPUT TYPE="submit" NAME="setPortDescription" VALUE="New Port Description" CLASS="button_on"></FORM>
EOF

} else {

$fContentPortDescription .= sprintf <<EOF;
<FONT COLOR="#FF0000"><B>&nbsp;trunk;&nbsp;</B>Administratively Disabled</FONT>
EOF

}


$fContentPortDescription .= sprintf <<EOF;
</TD><TR>

EOF

$cnt++;
}

	$fContentPortDescription .= sprintf <<EOF;
</TABLE>
</BODY>
</HTML>

EOF

my $fSaveConfigCompleted = sprintf <<EOF;

<HTML>
<BODY>
<P><B>Saving config Completed successfully</B>.</P>
</BODY>
</HTML>

EOF


	my $fContentPort2Vlan = <<EOF;

<HTML>
<HEAD>
<META HTTP-EQUIV="Pragma" CONTENT="no-cache">
<META HTTP-EQUIV="Expires" CONTENT="-1">
<TITLE>MF SYSTEMS CISCO</TITLE>
</HEAD>
<STYLE TYPE="text/css">
input[type=submit] {
    padding:5px 15px;
    background:#FFAAAA;
    border:0 none;
    cursor:pointer;
    -webkit-border-radius: 5px;
    border-radius: 5px;
}
.button_off {
    color: #FF00AA
}
.button_on {
    color: #000000
}
</STYLE>
<BODY>
<TABLE BORDER="1">
<TR><TH>Port #</TH><TH>Recent&nbsp;assignement<BR>Vlan&nbsp;ID/Vlan&nbsp;Name</TH><TH>Set&nbsp;New&nbsp;Vlan</TH></TR>
EOF

my $cnt=0;
my $vlan_cnt=0;

foreach my $p (@port) {
	my $myVlancnt=0;
	foreach my $myVlanID (@vlan_id) {
		my $pVlanID = $port_vlan_nr[$cnt];
		$myVlanID =~ s/\n//g;
		$pVlanID =~ s/\n//g;
		if ( ($cnt => 1 ) and ($myVlancnt == 0 ) ) {
			$myVlancnt = $cnt;
		}
		if ( ($pVlanID eq $myVlanID) and ($port_vlan_nr[$cnt] !~ m/trunk/) ) {

			$fContentPort2Vlan .= sprintf <<EOF;
<TR><TD>&nbsp;<B>$p</B>&nbsp;</TD><TD>$port_vlan_nr[$cnt]&nbsp;/&nbsp;$vlan_name[$myVlancnt-$cnt]</TD>
EOF

		} elsif ( ($cnt eq $myVlancnt) and ($port_vlan_nr[$cnt] ~~ m/trunk/) ) {

			$fContentPort2Vlan .= sprintf <<EOF;
<TR><TD>&nbsp;<B>$p</B>&nbsp;</TD><TD>$port_vlan_nr[$cnt]&nbsp;</TD>
EOF
		}
	$myVlancnt++;
	}


$fContentPort2Vlan .= sprintf <<EOF;
<TD>
EOF

if ( $port_vlan_nr[$cnt] == "trunk" ) {

$fContentPort2Vlan .= sprintf <<EOF;
<FONT COLOR="#FF0000"><B>&nbsp;&nbsp;&nbsp;</B>Administratively Disabled</FONT>
EOF

} else {
$fContentPort2Vlan .= sprintf <<EOF;
<FORM ACTION="/cgi-bin/catman.cgi" METHOD="POST" TARGET="_body">
<INPUT TYPE="hidden" NAME="man" VALUE="yes">
<INPUT TYPE="hidden" NAME="select_cisco_by_ip" VALUE="$params{'select_cisco_by_ip'}">
<INPUT TYPE="hidden" NAME="port2Vlan" VALUE="Move Port to Vlan">
<INPUT TYPE="hidden" NAME="swPort" VALUE="$p">
<SELECT NAME="portNewVlan">
EOF

	my $myAllowedVlansFile=$configs{allowvlan};
	open (File,'<', $myAllowedVlansFile) or die "$!";
	my @myAllowedVlans = <File>;
	close (File);

        $vlan_cnt=0;
        foreach my $VlanID (@vlan_id) {
		$VlanID =~ s/\n//g;
		my $pVlanID = $port_vlan_nr[$cnt];
		$pVlanID =~ s/\n//g;
		if ( !($pVlanID eq $VlanID) and ($port_vlan_nr[$cnt] !~ "trunk") ) {

			foreach my $fvl (@myAllowedVlans) {
				if ( !($fvl =~ m/^#/) and !($fvl eq '') ) {
					if ( !($fvl =~ m/^#/) and !($fvl eq '') ) {
						(my $key, my $value) = split(/=/,$fvl);
						$key =~ s/%([a-f0-9]{2})/chr(hex($1))/eig; # URL decode the key
						$value =~ s/%([a-f0-9]{2})/chr(hex($1))/eig; # URL decode the value
						$value =~ s/\"//eig;
						$value =~ s/\n//eig;

if ( ($vlan_id[$vlan_cnt] eq $value) and !($value eq '') ) {
$fContentPort2Vlan .= sprintf <<EOF;
<OPTION VALUE="$vlan_id[$vlan_cnt]">[$vlan_id[$vlan_cnt]]&nbsp;/&nbsp;[$vlan_name[$vlan_cnt]]</OPTION>
EOF
}

					}
				}
			}
		}
	$vlan_cnt++;
        }

if ( $port_vlan_nr[$cnt] == "trunk" ) {

        $fContentPort2Vlan .= sprintf <<EOF;
</TD></TR>
EOF


} else {

	$fContentPort2Vlan .= sprintf <<EOF;
</SELECT>
<INPUT TYPE="submit" NAME="SetNewPortVlan" VALUE="Set new Port Vlan" CLASS="button_on">
</FORM>
</TD></TR>
EOF

}

}

$cnt++;
}

	$fContentPort2Vlan .= sprintf <<EOF;
</TABLE>
</BODY>
</HTML>

EOF

# print to text file for php display
sub PrintToLogChanges {

   my ($cisco_by_ip,$cisco_port,$cisco_action) = @_;

   my @months = qw( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec );
   my @days = qw(Sun Mon Tue Wed Thu Fri Sat Sun);
   my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();


   $year += 1900;
   $mon = sprintf("%02d",$mon+1);
   $mday = sprintf("%02d",$mday);
   $hour = sprintf("%02d",$hour);
   $min = sprintf("%02d",$min);
   $sec = sprintf("%02d",$sec);

   my $myDate = "${year}\-${mon}\-${mday}\-${hour}:${min}:${sec}";
   my $myFileDate = "${year}${mon}${mday}";

   my $linelogs = "$myDate - Device:$cisco_by_ip - Port:$cisco_port - Action:$cisco_action - User:$ENV{'REMOTE_USER'} - FromHost:$ENV{'REMOTE_ADDR'}\n";

   my $mychanges = "$configs{actionlog}/change_${cisco_by_ip}_${myFileDate}.txt";
   open (my $fh,'>>:encoding(UTF-8)', $mychanges) or die "Canot open file $mychanges $!";
   print $fh $linelogs or die "Cannot write to file $!";
   close ($fh) or die "Cannot close file $!";

}

contentHeader if ($wasContent == 0);
	
if ( ($ENV{"REQUEST_METHOD"} eq 'POST') and $params{'man'} eq 'yes' and !($params{select_cisco_by_ip} eq '' ) and ( $params{'showDevID'} eq 'Show+Device+ID') ) { 
	my $htmlTopFile="$configs{tophtml}";
	open (my $fh, '>', $htmlTopFile) or die "Canot open file $htmlTopFile $!";
	print $fh $fContentTop;
	close ($fh);
	print "<B><U>Show Device Port State for selected device $params{select_cisco_by_ip} </U></B><BR>\n".$fContentPlain;
}

if ( ($ENV{"REQUEST_METHOD"} eq 'POST') and $params{'man'} eq 'yes' and !($params{select_cisco_by_ip} eq '' ) and ( $params{'setTime'} eq 'Set+Time') ) { 
	print <<EOF;
<HTML>
<HEAD>
</HEAD>
<BODY>
<P>&nbsp;</P>
<TABLE>
<TR><TD><B>Save of system time completed</B></TD></TR>
<TR><TD><B>please hit left sided "Show Device ID" button to refresh state.</B></TD></TR>
</TABLE>
<P>&nbsp;</P>
</BODY>
</HTML>

EOF
}

if ( ($ENV{"REQUEST_METHOD"} eq 'POST') and $params{'man'} eq 'yes' and !($params{select_cisco_by_ip} eq '' ) and ( $params{'putDownUpPort'} eq 'Port+Down/Up') ) { 
	print "<B><U>Port Up/Down Section</U> for device IP $params{'select_cisco_by_ip'}</B><BR>\n".$fContentPortOnOff;
}

if ( ($ENV{"REQUEST_METHOD"} eq 'POST') and $params{'man'} eq 'yes' and !($params{select_cisco_by_ip} eq '' ) and ( $params{'setPortOff'} eq 'Switch+Port+Off') ) { 
	print "<BR><B>".$params{'swPort'} ." Was enabled. Now is <FONT COLOR=\"#FF0000\">disabled</FONT></B><BR>";
	my $action="$configs{cidialog} $params{'select_cisco_by_ip'} putPortDown $params{'swPort'}";
	open(FIC,"$action |");
	my @results=<FIC>;
	close(FIC);
	$actiontype = "PutPortDown";
	PrintToLogChanges $params{'select_cisco_by_ip'}, $params{'swPort'}, $actiontype;
}

if ( ($ENV{"REQUEST_METHOD"} eq 'POST') and $params{'man'} eq 'yes' and !($params{select_cisco_by_ip} eq '' ) and ( $params{'setPortOn'} eq 'Switch+Port+On') ) { 
	print "<BR>For device IP $params{'select_cisco_by_ip'} <B>".$params{'swPort'} ." Was disabled. Now is <FONT COLOR=\"#00FF00\">enabled</FONT>.</B><BR>";
        my $action="$configs{cidialog} $params{'select_cisco_by_ip'} putPortUp $params{'swPort'}";
        open(FIC,"$action |");
        my @results=<FIC>;
        close(FIC);
	$actiontype = "PutPortUp";
	PrintToLogChanges $params{'select_cisco_by_ip'}, $params{'swPort'}, $actiontype;
}

if ( ($ENV{"REQUEST_METHOD"} eq 'POST') and $params{'man'} eq 'yes' and !($params{select_cisco_by_ip} eq '' ) and ( $params{'descPortChange'} eq 'Change+Port+Description') ) { 
	print "<B><U>Show Port Description</U> for device IP$params{'select_cisco_by_ip'}</B><BR>\n".$fContentPortDescription;
}

if ( ($ENV{"REQUEST_METHOD"} eq 'POST') and $params{'man'} eq 'yes' and !($params{select_cisco_by_ip} eq '' ) and ( $params{'setPortDescription'} eq 'New+Port+Description') ) { 
	my $NewDescLoc = "$params{'NewPortDescription'}";
	$NewDescLoc =~ s/\+/\ /g;
	print "<BR>For device IP $params{'select_cisco_by_ip'}<B>".$params{'swPort'} ." Has following description now <FONT COLOR=\"#00FF00\">$NewDescLoc</FONT>.</B><BR>";
        my $action="$configs{cidialog} $params{'select_cisco_by_ip'} portDescriptionChange $params{'swPort'} \"$NewDescLoc\"";
        open(FIC,"$action |");
        my @results=<FIC>;
        close(FIC);
	$actiontype = "SetPortDescription";
	PrintToLogChanges $params{'select_cisco_by_ip'}, $params{'swPort'}, $actiontype;
}

if ( ($ENV{"REQUEST_METHOD"} eq 'POST') and $params{'man'} eq 'yes' and !($params{select_cisco_by_ip} eq '' ) and ( $params{'saveConfig'} eq 'Save+Device+Config') ) { 
	print $fSaveConfigCompleted . "\n";
}


if ( ($ENV{"REQUEST_METHOD"} eq 'POST') and $params{'man'} eq 'yes' and !($params{select_cisco_by_ip} eq '' ) and ( $params{'changePortVlan'} eq 'Change+Port+Vlan') ) { 
	print "<B><U>Port Vlan Selection</U> for device IP $params{'select_cisco_by_ip'}</B><BR>" . $fContentPort2Vlan;

}

if ( ($ENV{"REQUEST_METHOD"} eq 'POST') and $params{'man'} eq 'yes' and !($params{select_cisco_by_ip} eq '' ) and ( $params{'port2Vlan'} eq 'Move+Port+to+Vlan') and !($params{'portNewVlan'} eq '') ) { 
        my $action="$configs{cidialog} $params{'select_cisco_by_ip'} changePortVlan $params{'swPort'} $params{'portNewVlan'}";
	print "Changing of Port assignement to vlan at device IP $params{'select_cisco_by_ip'}, please wait...<BR>\n";
	open(FIC,"$action |");
	my @results=<FIC>;
	close(FIC);
	print "Assignement Completed<BR>@results\n\n";
	$actiontype = "SetPortNewVlan";
	PrintToLogChanges $params{'select_cisco_by_ip'}, $params{'swPort'}, $actiontype;
}

if ( ($ENV{"REQUEST_METHOD"} eq 'POST') and ($params{'man'} eq 'yes') and !($params{select_cisco_by_ip} eq '' ) and ( $params{'resetPortCounters'} eq 'Reset+Counters') and !($params{'swPort'} eq '') ) { 
	print "Resetting counters on way. at device IP $params{'select_cisco_by_ip'}, port $params{'swPort'}. Please wait...<BR>\n";
        my $action="$configs{cidialog} $params{'select_cisco_by_ip'} resetPortCounters $params{'swPort'}";
	open(FIC,"$action |");
	my @results=<FIC>;
	close(FIC);
	my $myDate=`date "+%a, %d %b %Y %X %Z"`;
	print "Expires: $myDate\n\n";
	print "\rReseting port counters for $params{'swPort'} completed.<BR>\n\n";
}

#################################################
# extra test and debug below
#################################################

#contentHeader if ($wasContent == 0);
#print <<EOF;

#Device: $params{'select_cisco_by_ip'}<BR>\n
#Method: $ENV{REQUEST_METHOD}<BR>\n
#STDIN: $query<BR>\n
#or: $ENV{CONTENT_LENGTH}<BR>\n
#Content Length: $ENV{CONTENT_LENGTH}<BR>\n



# VLAN table test
#my $vlan_cnt_x=0;
#print <<EOF;
#<TABLE>
#EOF
#foreach my $VlanIDx (@vlan_id) {
#       $VlanIDx =~ s/\n//g;
#       my $pVlanIDx = $port_vlan_nr[1];
#       $pVlanIDx =~ s/\n//g;
#                if ( !($pVlanIDx =~ $VlanIDx) ) {
#       if ( !($port_vlan_nr[$cnt] =~ $VlanID) ) {
#print <<EOF;
#<TR><TD>$VlanIDx</TD><TD>&nbsp;/&nbsp;[$vlan_name[$vlan_cnt_x]]</TD><TD>$port_vlan_nr[0]</TD></TR>
#EOF
#		}
#       }
#$vlan_cnt_x++;
#}
#print <<EOF;
#</TABLE>
#EOF

#while( my( $key, $val ) = each %{configs} ) {
#        print "<P>$key\t=>$val</P>\n";
#}

#EOF

exit 0;


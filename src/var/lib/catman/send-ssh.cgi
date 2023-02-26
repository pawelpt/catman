#!/usr/bin/expect -f
# 
# core engine to change some at your switch with expect dialog ;)
# (c) (r) 2017 Pawel Trepka
# Under GPLv2.
# Remark:
#  Feel free to adapt on your behalf
# 
# set variables
#

set timeout 5

#
set IPs [lindex $argv 0]
set action [lindex $argv 1]
set swPort [lindex $argv 2]
set swPortDescriptionOrVlan [lindex $argv 3]
#
set Uname "technicy"
global PassAuth PassEnable vlanVoice vlanData
set PassAuth ""
set PassEnable ""
set vlanVoice ""
set vlanData ""
set Dir /var/log/apache2/cisco_web
set AuthFile /etc/catman/router.list/devices
# set myDate [timestamp -format %H:%M:%S %d %b %Y]
set myDate [clock format [clock seconds] -format "%H:%M:%S %d %b %Y" -timezone Europe/Warsaw]

# 
# log operations to logfile
# 

if {[llength $argv] == 0 } {
send_user "Usage: ssh-send.sh <IP> what value \[options\]\n"
send_user "wherei     IP - the machine IPwhat \n"
send_user "         what - port date\n"
send_user "        value - status/set\n"
send_user "        when set enabled then opted new value would be issued\n"
exit 1
}

log_file -a $Dir/session2_$IPs.log

proc seekAuthFile { ip } {

set fp [open "/etc/catman/router.list/devices" r]
set file_data [read $fp]
close $fp

set records [split $file_data "\n"]

foreach res $records {
        if {[regexp {^\#} $res]} {
                continue
        }
        set fields [split $res ":"]
        lassign $fields\
                        devIP devName secAccess secEnable SpecVlan1 SpecVlan2
        if {[string length $res] != 0} {
#		puts "$ip Device IP: $devIP, DevName: $devName SecAcc: $secAccess, secEna: $secEnable, VLANs: $SpecVlan1, $SpecVlan2,"
		if {$devIP eq $ip} {
			global PassAuth PassEnable vlanVoice vlanData
			set PassAuth $secAccess
			set PassEnable $secEnable
			set vlanVoice $SpecVlan1
			set vlanData $SpecVlan2
#			send_user "$ip Entering Match Pa:$PassAuth En:$PassEnable\n"
		}
        }
	}
}

seekAuthFile $IPs

#send_user "Pa:$PassAuth En:$PassEnable\n"

# exit 0

proc common {} {
log_user 0
send "terminal length 512\r"
expect "*#"
log_user 1
}

proc Authorize { ip user pass } {
log_user 0
#spawn /usr/bin/ssh -1 -o "StrictHostKeyChecking=no" $user@$ip
spawn /usr/bin/ssh -2 -o "StrictHostKeyChecking=no" -o "KexAlgorithms=diffie-hellman-group1-sha1" -o "StrictHostKeyChecking=no" $user@$ip
expect "*assword:"
send "$pass\r"
expect "*>"
log_user 1
}

proc Elevate { pass } {
log_user 0
send "enable 2\r"
expect "*assword:"
send "$pass\r"
expect "*#"
log_user 1
}

# 
# Manipulating of the config
# 

# show running config

proc searchMacAddr { ip date user passauth passenable mac } {
log_user 1
send_user "\n### MAC Search $ip / $mac\n"
# send_log "\n### start device dialog resetPortCounters $ip $date $port ###\n"
# send_log "processing $ip $date\n"
spawn /usr/bin/ssh -2 -o "StrictHostKeyChecking=no" -o "KexAlgorithms=diffie-hellman-group1-sha1" -o "StrictHostKeyChecking=no" $user@$ip
expect "*assword:"
send "$passauth\r"
expect "*#"
send "terminal length 512\r"
expect "*#"
send "sh mac address-table | include $mac\r"
expect "*#"
send "exit\r"
send_user "\n"
}


proc showConfigRunning { ip date user passauth passenable } {
log_user 0
send_log "\n### start device dialog showConfigRunning $ip $date ###\n"
spawn /usr/bin/ssh -2 -o "StrictHostKeyChecking=no" -o "KexAlgorithms=diffie-hellman-group1-sha1" -o "StrictHostKeyChecking=no" $user@$ip
expect "*assword:"
send "$passauth\r"
expect "*#"
send "terminal length 512\r"
log_user 1
expect "*#"
send "show run\r"
expect "*#"
log_user 0
send "exit\r"
}

proc showConfigSaved { ip date user passauth passenable } {
log_user 0
send_log "\n### start device dialog showConfigRunning $ip $date ###\n"
spawn /usr/bin/ssh -2 -o "StrictHostKeyChecking=no" -o "KexAlgorithms=diffie-hellman-group1-sha1" -o "StrictHostKeyChecking=no" $user@$ip
expect "*assword:"
send "$passauth\r"
expect "*#"
send "terminal length 512\r"
log_user 1
expect "*#"
send "show startup-config\r"
expect "*#"
log_user 0
send "exit\r"
}


# show difference running startup
proc showConfigDiff { ip date user passauth passenable } {
log_user 0
send_log "\n### start device dialog showConfigDiff $ip $date ###\n"
spawn /usr/bin/ssh -2 -o "StrictHostKeyChecking=no" -o "KexAlgorithms=diffie-hellman-group1-sha1" -o "StrictHostKeyChecking=no" $user@$ip
expect "*assword:"
send "$passauth\r"
expect "*#"
send "terminal length 512\r"
expect "*#"
#send "show archive config differences flash:config.text system:running-config\r"
send "show archive config differences\r"
log_user 1
sleep 1
expect "*#"
log_user 0
send "exit\r"
}

# save config
proc saveConfig { ip date user passauth passenable } {
log_user 0
send_log "\n### start device dialog saveConfig $ip $date ###\n"
spawn /usr/bin/ssh -2 -o "StrictHostKeyChecking=no" -o "KexAlgorithms=diffie-hellman-group1-sha1" -o "StrictHostKeyChecking=no" $user@$ip
expect "*assword:"
send "$passauth\r"
expect "*#"
send "terminal length 512\r"
expect "*#"
send "write mem\r"
expect "*#"
send "copy running-config startup-config\r"
expect "*]?"
send "\r"
expect "*#"
send "show startup-config\r"
expect "*#"
send "exit\r"
}

proc showDevID { ip date user passauth passenable} {
log_user 0
send_log "\n### start device dialog showDevID $ip $date ###\n"
spawn /usr/bin/ssh -2 -o "StrictHostKeyChecking=no" -o "KexAlgorithms=diffie-hellman-group1-sha1" -o "StrictHostKeyChecking=no" $user@$ip
expect "*assword:"
send "$passauth\r"
expect "*#"
send "terminal length 512\r"
expect "*#"
log_user 1
send "show version\r"
expect "*#"
send "show clock\r"
expect "*#"
send "show int status\r"
expect "*#"
send "show vlan\r"
expect "*#"
log_user 0
send "exit\r"
}

#
# setDateTime
#
proc setTime { ip date user passauth passenable } {
log_user 0
send_log "\n### start device dialog setTime $ip $date ###\n"
spawn /usr/bin/ssh -2 -o "StrictHostKeyChecking=no" -o "KexAlgorithms=diffie-hellman-group1-sha1" -o "StrictHostKeyChecking=no" $user@$ip
expect "*assword:"
send "$passauth\r"
expect "*#"
send "terminal length 512\r"
expect "*#"
send "conf t\r"
expect "*)#"
log_user 1
send "clock timezone CET +1\r"
expect "*)#"
send  "exit\r"
expect "*#"
send "clock set $date\r"
expect "*#"
send "write mem\r"
expect "*#"
send "copy running-config startup-config\r"
expect "*]?"
send "\r"
expect "*#"
send "show clock\r"
expect "*#"
log_user 0
send "exit\r"
}



# 
# putDownUpPort
# 
proc putDownUpPort { ip date user passauth passenable} {
log_user 1
send_log "\n### start device dialog putDownUpPort $ip $date ###\n"
send_log "processing $ip $date\n"
spawn /usr/bin/ssh -2 -o "StrictHostKeyChecking=no" -o "KexAlgorithms=diffie-hellman-group1-sha1" -o "StrictHostKeyChecking=no" $user@$ip
expect "*assword:"
send "$passauth\r"
expect "*#"
send "terminal length 512\r"
expect "*#"
send "show int status\r"
expect "*#"
send "exit\r"
}

proc putPortDown { ip date user port passauth passenable } {
log_user 1
send_log "\n### start device dialog putPortDown $ip $date $port ###\n"
send_log "processing $ip $date\n"
spawn /usr/bin/ssh -2 -o "StrictHostKeyChecking=no" -o "KexAlgorithms=diffie-hellman-group1-sha1" -o "StrictHostKeyChecking=no" $user@$ip
expect "*assword:"
send "$passauth\r"
expect "*#"
send "terminal length 512\r"
expect "*#"
send "conf term\r"
expect "*)#"
log_user 1
send "interface $port\r"
expect "*if)#"
send "shutdown\r"
expect "*if)#"
log_user 0
send "exit\r"
expect "*)#"
send "exit\r"
expect "*#"
send "exit\r"
}

proc putPortUp { ip date user port passauth passenable} {
log_user 0
send_log "\n### start device dialog putPortUp $ip $date $port ###\n"
send_log "processing $ip $date\n"
spawn /usr/bin/ssh -2 -o "StrictHostKeyChecking=no" -o "KexAlgorithms=diffie-hellman-group1-sha1" -o "StrictHostKeyChecking=no" $user@$ip
expect "*assword:"
send "$passauth\r"
expect "*#"
send "terminal length 512\r"
expect "*#"
send "conf term\r"
expect "*)#"
log_user 1
send "interface $port\r"
expect "*if)#"
send "no shutdown\r"
expect "*if)#"
log_user 0
send "exit\r"
expect "*)#"
send "exit\r"
expect "*#"
send "exit\r"
}

proc portDescriptionChange { ip date user port description passauth passenable } {
if { $description ne ""} {
 set cmd {description}
} else {
 set cmd {no description}
}
log_user 0
send_log "\n### start device dialog portDescriptionChange $ip $date $port ###\n"
send_log "processing $ip $date\n"
spawn /usr/bin/ssh -2 -o "StrictHostKeyChecking=no" -o "KexAlgorithms=diffie-hellman-group1-sha1" -o "StrictHostKeyChecking=no" $user@$ip
expect "*assword:"
send "$passauth\r"
expect "*#"
send "terminal length 512\r"
expect "*#"
send "conf term\r"
expect "*)#"
log_user 1
send "interface $port\r"
expect "*if)#"
send "$cmd $description\r"
expect "*if)#"
log_user 0
send "exit\r"
expect "*)#"
send "exit\r"
expect "*#"
send "exit\r"
}

proc changePortVlan { ip date user port vlanid passauth passenable voicevlan datavlan } {
log_user 0

send_log "\n### start device dialog portNewVlan $ip $date $port $vlanid ###\n"
send_log "processing $ip $date\n"
spawn /usr/bin/ssh -2 -o "StrictHostKeyChecking=no" -o "KexAlgorithms=diffie-hellman-group1-sha1" -o "StrictHostKeyChecking=no" $user@$ip
expect "*assword:"
send "$passauth\r"
expect "*#"
send "terminal length 512\r"
expect "*#"
send "conf term\r"
expect "*)#"
send "interface $port\r"
expect "*if)#"
if {$vlanid eq $voicevlan} {
#	send "switchport access vlan $datavlan\r"
	send "switchport access vlan $vlanid\r"
	expect "*if)#"
	send "switchport mode access\r"
	expect "*if)#"
#	send "switchport voice vlan $vlanid\r"
#	expect "*if)#"
#	send "auto qos voip cisco-phone\r"
#	expect "*if)#"
#	send "auto qos voip trust\r"
#	expect "*if)#"
#	send "mls qos trust dscp\r"
#	expect "*if)#"
#	send "spanning-tree bpduguard enable 2\r"
#	expect "*if)#"
#	send "switchport trunk encapsulation dot1q\r"
#	expect "*if)#"
} else {
	send "switchport access vlan $vlanid\r"
	expect "*if)#"
	send "no switchport mode access\r"
	expect "*if)#"
#	send "no switchport voice vlan\r"
#	expect "*if)#"
#	send "no auto qos voip cisco-phone\r"
#	expect "*if)#"
#	send "no auto qos voip trust\r"
#	expect "*if)#"
#	send "no spanning-tree portfast\r"
#	expect "*if)#"
#	send "no mls qos trust dscp\r"
#	expect "*if)#"
#	send "no spanning-tree bpduguard enable 2\r"
#	expect "*if)#"
#	send "no switchport trunk encapsulation dot1q\r"
#	expect "*if)#"
}
send "exit\r"
expect "*)#"
send "exit\r"
expect "*#"
send "exit\r"
log_user 0
}

proc portCounterStats { ip date user port passauth passenable} {
log_user 0
send_log "\n### start device dialog portCounterStats $ip $date $port ###\n"
send_log "processing $ip $date\n"
spawn /usr/bin/ssh -2 -o "StrictHostKeyChecking=no" -o "KexAlgorithms=diffie-hellman-group1-sha1" -o "StrictHostKeyChecking=no" $user@$ip
expect "*assword:"
send "$passauth\r"
expect "*#"
send "terminal length 0\r"
expect "*#"
send "show interface\r"
log_user 1
expect "*#"
log_user 0
send "exit\r"
}

proc resetPortCounters { ip date user port passauth passenable} {
log_user 0
send_log "\n### start device dialog resetPortCounters $ip $date $port ###\n"
send_log "processing $ip $date\n"
spawn /usr/bin/ssh -2 -o "StrictHostKeyChecking=no" -o "KexAlgorithms=diffie-hellman-group1-sha1" -o "StrictHostKeyChecking=no" $user@$ip
expect "*assword:"
send "$passauth\r"
expect "*#"
send "terminal length 512\r"
expect "*#"
send "clear count $port\r"
expect "*confirm]"
send "y\r"
expect "*#"
send "exit\r"
}


# MAIN FUNCTION

switch -regexp -- $action {
saveConfig {
	saveConfig $IPs $myDate $Uname $PassAuth $PassEnable
}
showDevID {
	showDevID $IPs $myDate $Uname $PassAuth $PassEnable
}
setTime {
	setTime $IPs $myDate $Uname $PassAuth $PassEnable
}
putDownUpPort {
	putDownUpPort $IPs $myDate $Uname $PassAuth $PassEnable
}
putPortDown {
	putPortDown $IPs $myDate $Uname $swPort $PassAuth $PassEnable
}
putPortUp {
	putPortUp $IPs $myDate $Uname $swPort $PassAuth $PassEnable
}
portDescriptionChange {
	portDescriptionChange $IPs $myDate $Uname $swPort $swPortDescriptionOrVlan $PassAuth $PassEnable
}
changePortVlan {
	changePortVlan $IPs $myDate $Uname $swPort $swPortDescriptionOrVlan $PassAuth $PassEnable $vlanVoice $vlanData
}
portCounterStats {
	portCounterStats $IPs $myDate $Uname $swPort $PassAuth $PassEnable
}
resetPortCounters {
	resetPortCounters $IPs $myDate $Uname $swPort $PassAuth $PassEnable
}
isConfigChangeDiff {
	showConfigDiff $IPs $myDate $Uname $PassAuth $PassEnable
}
isConfig_run {
	showConfigRunning $IPs $myDate $Uname $PassAuth $PassEnable
}
isConfig_startup {
	showConfigSaved $IPs $myDate $Uname $PassAuth $PassEnable
}
searchMac {
	searchMacAddr $IPs $myDate $Uname $PassAuth $PassEnable $swPort
}
default {
	showDevID $IPs $myDate $Uname $PassAuth $PassEnable
}
}




## CISCO management web interface

Designated for 3550/3750 standalone and stacked way of implementation


# Fully besed at opensource architecture stack

# Volounteer welcome
```
# TODO
- interface for usage of UI templates
- graphical switch look
```


# Remark

- [] are you an perl programmer ;)

```
------------------------------------------------------------------------------------
```

# How it work

# Scripts

## build AD Access group for Apache

```
#!/bin/bash
##############################################################################################
#
# generate access apache list group
#

# definitions
apache_group_file="/etc/apache2/apache_groups.tmp";
apache_acl_group="switche_app_dostep";
acl_list="";

# functions here
update_apache_groups() {

local apache_acl=$1;

for u in $(wbinfo -u 2>&1); do

text_cmd=" Processing $u ";

id $u 2>&1 | grep ${apache_acl} >/dev/null 2>&1;
err=$?

[ $err -ne 1 ] && {

acl_list+=" $(id $u | awk -F '[()]' '{print $2}')";
text_cmd+=" +++ adding +++";

}

echo "$text_cmd";

done
}

#
# main issue done below
#
##############################################################################################
update_apache_groups $apache_acl_group;

# build the fresh file
[ -f ${apache_group_file} ] && {
cp ${apache_group_file} ${apache_group_file}.bk
ls -lart ${apache_group_file} ${apache_group_file}.bk

cat <<EOF >${apache_group_file}
switche_app_dostep: ptrepka27${acl_list}
switche_app_admins: ptrepka27 penglisz02 lszulc11 mswierczek02 ldrzyzga73
EOF

cat ${apache_group_file}
}

exit 0
```

#!/bin/bash
# debugging
set -x

# Set userid for oracle user
sed -e '/oracle/ s/x:[0-9]*:/x:'`id -u`':/' /etc/passwd >/tmp/passwd
mv /tmp/passwd /etc/passwd

# Set path if path not set (if called from /etc/rc)
case $PATH in
    "") PATH=/bin:/usr/bin:/sbin:/etc
        export PATH ;;
esac

# Save LD_LIBRARY_PATH
SAVE_LLP=$LD_LIBRARY_PATH
RETVAL=0
export ORACLE_HOME=/u01/app/oracle/product/11.2.0/xe
export ORACLE_SID=XE
export ORACLE_BASE=/u01/app/oracle
export PATH=$ORACLE_HOME/bin:$PATH
LSNR=$ORACLE_HOME/bin/lsnrctl
SQLPLUS=$ORACLE_HOME/bin/sqlplus
ORACLE_OWNER=oracle
LOG="$ORACLE_HOME_LISTNER/listener.log"

if [ -z "$CHOWN" ]; then CHOWN=/bin/chown; fi
if [ -z "$CHMOD" ]; then CHMOD=/bin/chmod; fi
if [ -z "$HOSTNAME" ]; then HOSTNAME=/bin/hostname; fi
if [ -z "$NSLOOKUP" ]; then NSLOOKUP=/usr/bin/nslookup; fi
if [ -z "$GREP" ]; then GREP=/usr/bin/grep; fi
if [ ! -f "$GREP" ]; then GREP=/bin/grep; fi
if [ -z "$SED" ]; then SED=/bin/sed; fi
if [ -z "$AWK" ]; then AWK=/bin/awk; fi

export LC_ALL=C

CONFIG_NAME=oracle-xe
CONFIGURATION="/etc/sysconfig/$CONFIG_NAME"

# Set hostname  in listener.ora
sed -i -E "s/HOST = [^)]+/HOST = $HOSTNAME/g" $ORACLE_HOME/network/admin/listener.ora;

# Source configuration

[ -f "$CONFIGURATION" ] && . "$CONFIGURATION"


if [ "$CONFIGURE_RUN" != "true" ]		
then
  echo "Oracle Database 11g Express Edition is not configured.  You must run
'/etc/init.d/oracle-xe configure' as the root user to configure the database."
  exit 1
fi

start() {
status=`ps -ef | grep tns | grep oracle|grep -v grep`
if [ "$status" == "" ]
then
	if [ -f $ORACLE_HOME/bin/tnslsnr ]  
        then
	     	echo "Starting Oracle Net Listener."
       		$LSNR  start > /dev/null 2>&1
	fi
fi

pmon=`ps -ef | egrep pmon_$ORACLE_SID'\>' | grep -v grep`
if [ "$pmon" = "" ];
then
         echo "Starting Oracle Database 11g Express Edition instance."
         $SQLPLUS -s /nolog @$ORACLE_HOME/config/scripts/startdb.sql > /dev/null 2>&1
else
         echo "Oracle Database 11g Express Edition instance is already started"
fi

RETVAL=$?
if [ $RETVAL -eq 0 ]
then
       	echo
else
       	echo Failed to start Oracle Net Listener using $ORACLE_HOME/bin/tnslsnr\
      and Oracle Express Database using $ORACLE_HOME/bin/sqlplus.
RETVAL=1
fi

return $RETVAL
}



while true; do
    pmon=`ps -ef | grep pmon_$ORACLE_SID | grep -v grep`

    if [ "$pmon" == "" ]
    then
        date
        start
    fi
    sleep 1m
done;


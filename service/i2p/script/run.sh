#!/bin/sh

#
# Copyright (c) 1999, 2011 Tanuki Software, Ltd.
# http://www.tanukisoftware.com
# All rights reserved.
#
# Make sure that PIDFILE points to the correct location,
# if you have changed the default location set in the
# wrapper configuration file.
#
# If this script fails to successfully invoke i2psvc on your platform,
# try the i2prouter-nowrapper script instead.
#
# This software is the proprietary information of Tanuki Software.
# You shall use it only in accordance with the terms of the
# license agreement you entered into with Tanuki Software.
# http://wrapper.tanukisoftware.com/doc/english/licenseOverview.html
#
# Java Service Wrapper sh script.  Suitable for starting and stopping
#  wrapped Java applications on UNIX platforms.
#
#-----------------------------------------------------------------------------
# These settings can be modified to fit the needs of your application
# Optimized for use with version 3.5.22 of the Wrapper.

# Read config file if found
[ -f /etc/default/i2p ] && . /etc/default/i2p

I2P="/usr/share/i2p"
I2P_CONFIG_DIR="$HOME/.i2p"
I2PTEMP="/tmp"
# PORTABLE installation:
# Use the following instead.
#I2PTEMP="%INSTALL_PATH"

# Application
APP_NAME="i2p"
APP_LONG_NAME="I2P Service"

# gettext - we look for it in the path
# fallback to echo is below, we can't set it to echo here.
GETTEXT=$(which gettext > /dev/null 2>&1)

# Where to install the systemd service
SYSTEMD_SERVICE="/etc/systemd/system/${APP_NAME}.service"
if grep -q systemd /proc/1/comm > /dev/null 2>&1 ; then
    USE_SYSTEMD=1
fi

# If specified, the Wrapper will be run as the specified user.
# IMPORTANT - Make sure that the user has the required privileges to write
#  the PID file and wrapper.log files and that the directories exist.
#  Failure to write the pid file will cause the Wrapper to exit.
#  Failure to write the log file will cause the Wrapper to use CWD for the log file location.
#
# NOTE - This will set the user which is used to run the Wrapper as well as
#  the JVM and is not useful in situations where a privileged resource or
#  port needs to be allocated prior to the user being changed.
#RUN_AS_USER=

# Wrapper
WRAPPER_CMD="/usr/sbin/wrapper"
WRAPPER_CONF="/etc/i2p/wrapper.config"

# Priority at which to run the wrapper.  See "man nice" for valid priorities.
#  nice is only used if a priority is specified.
PRIORITY=

# Location of the pid and status files.
PIDDIR="$I2P_CONFIG_DIR"
#PIDDIR="$I2PTEMP"

# Location of the wrapper.log file
LOGDIR="$I2P_CONFIG_DIR"
#LOGDIR="$I2PTEMP"
LOGFILE="$LOGDIR/wrapper.log"

# If you'd like to run I2P as root (not recommended), uncomment the
# following line
ALLOW_ROOT=true

# FIXED_COMMAND tells the script to use a hard coded action rather than
# expecting the first parameter of the command line to be the command.
# By default the command will will be expected to be the first parameter.
#FIXED_COMMAND=console

# PASS_THROUGH tells the script to pass all arguments through to the JVM
#  as is.  If FIXED_COMMAND is specified then all arguments will be passed.
#  If not set then all arguments starting with the second will be passed.
#PASS_THROUGH=true

# If uncommented, causes the Wrapper to be shutdown using an anchor file.
#  When launched with the 'start' command, it will also ignore all INT and
#  TERM signals.
#IGNORE_SIGNALS=true

# Wrapper will start the JVM asynchronously. Your application may have some
#  initialization tasks and it may be desirable to wait a few seconds
#  before returning.  For example, to delay the invocation of following
#  startup scripts.  Setting WAIT_AFTER_STARTUP to a positive number will
#  cause the start command to delay for the indicated period of time
#  (in seconds).
#
WAIT_AFTER_STARTUP=0

# If set, wait for the wrapper to report that the daemon has started
WAIT_FOR_STARTED_STATUS=true
WAIT_FOR_STARTED_TIMEOUT=120

# If set, the status, start_msg and stop_msg commands will print out detailed
#   state information on the Wrapper and Java processes.
#DETAIL_STATUS=true

# By default we show a detailed usage block.  Uncomment to show brief usage.
#BRIEF_USAGE=true

# flag for using upstart when installing (rather than init.d rc.d)
USE_UPSTART=

# Source the environment variables for the locale if $LANG isn't set
# If you want to set custom locale variables for I2P,
# you may comment out this block and set them yourself here.

if [ ! -n $LANG ]; then
        for ENV_FILE in /etc/environment /etc/default/locale; do
                [ -r "$ENV_FILE" ] || continue
                [ -s "$ENV_FILE" ] || continue

                for var in LANG LANGUAGE LC_ALL LC_CTYPE; do
                        value=`egrep "^${var}=" "$ENV_FILE" | tail -n1 | cut -d= -f2`
                        [ -n "$value" ] && eval export $var=$value
                done
        done
fi

# When installing on On Mac OSX platforms, the following domain will be used to
#  prefix the plist file name.
PLIST_DOMAIN=org.tanukisoftware.wrapper

# The following two lines are used by the chkconfig command. Change as is
#  appropriate for your application.  They should remain commented.
# chkconfig: 2345 20 80
# description: I2P Service

# Initialization block for the install_initd and remove_initd scripts used by
#  SUSE linux distributions.
### BEGIN INIT INFO
# Provides: i2p
# Required-Start: $local_fs $network $syslog
# Should-Start:
# Required-Stop:
# Default-Start: 2 3 4 5
# Default-Stop: 0 1 6
# Short-Description: I2P Service
# Description: I2P is a load-balanced unspoofable packet switching network
### END INIT INFO

# Do not modify anything beyond this point
#-----------------------------------------------------------------------------
if [ ! -e "$WRAPPER_CONF" ]; then
       echo "Starting I2P Failed: Unable to find $WRAPPER_CONF"
       exit 1
fi

JAVABINARY=$(awk -F'=' '/^ *wrapper\.java\.command/{print $2}' "$WRAPPER_CONF")

if [ -n "$FIXED_COMMAND" ]
then
    COMMAND="$FIXED_COMMAND"
else
    COMMAND="$1"
fi


# Required for HP-UX Startup
if [ `uname -s` = "HP-UX" -o `uname -s` = "HP-UX64" ] ; then
        PATH=$PATH:/usr/bin
fi

# Get the fully qualified path to the script
case $0 in
    /*)
        SCRIPT="$0"
        ;;
    *)
        PWD=`pwd`
        SCRIPT="$PWD/$0"
        ;;
esac

# Resolve the true real path without any sym links.
CHANGED=true
while [ "X$CHANGED" != "X" ]
do
    # Change spaces to ":" so the tokens can be parsed.
    SAFESCRIPT=`echo $SCRIPT | sed -e 's; ;:;g'`
    # Get the real path to this script, resolving any symbolic links
    TOKENS=`echo $SAFESCRIPT | sed -e 's;/; ;g'`
    REALPATH=
    for C in $TOKENS; do
        # Change any ":" in the token back to a space.
        C=`echo $C | sed -e 's;:; ;g'`
        REALPATH="$REALPATH/$C"
        # If REALPATH is a sym link, resolve it.  Loop for nested links.
        while [ -h "$REALPATH" ] ; do
            LS="`ls -ld "$REALPATH"`"
            LINK="`expr "$LS" : '.*-> \(.*\)$'`"
            if expr "$LINK" : '/.*' > /dev/null; then
                # LINK is absolute.
                REALPATH="$LINK"
            else
                # LINK is relative.
                REALPATH="`dirname "$REALPATH"`""/$LINK"
            fi
        done
    done

    if [ "$REALPATH" = "$SCRIPT" ]
    then
        CHANGED=""
    else
        SCRIPT="$REALPATH"
    fi
done

# Get the location of the script.
REALDIR=`dirname "$REALPATH"`
# Normalize the path
REALDIR=`cd "${REALDIR}"; pwd`

# If the PIDDIR is relative, set its value relative to the full REALPATH to avoid problems if
#  the working directory is later changed.
FIRST_CHAR=`echo $PIDDIR | cut -c1,1`
if [ "$FIRST_CHAR" != "/" ]
then
    PIDDIR=$REALDIR/$PIDDIR
fi
# Same test for WRAPPER_CMD
FIRST_CHAR=`echo $WRAPPER_CMD | cut -c1,1`
if [ "$FIRST_CHAR" != "/" ]
then
    WRAPPER_CMD=$REALDIR/$WRAPPER_CMD
fi
# Same test for WRAPPER_CONF
FIRST_CHAR=`echo $WRAPPER_CONF | cut -c1,1`
if [ "$FIRST_CHAR" != "/" ]
then
    WRAPPER_CONF=$REALDIR/$WRAPPER_CONF
fi

# Process ID
ANCHORFILE="$PIDDIR/$APP_NAME.anchor"
COMMANDFILE="$PIDDIR/$APP_NAME.command"
STATUSFILE="$PIDDIR/$APP_NAME.status"
JAVASTATUSFILE="$PIDDIR/$APP_NAME.java.status"
PIDFILE="$PIDDIR/$APP_NAME.pid"
LOCKDIR="/var/lock/subsys"
LOCKFILE="$LOCKDIR/$APP_NAME"
pid=""

# Resolve the location of the 'ps' command
PSEXE="/usr/ucb/ps"
    if [ ! -x "$PSEXE" ]
    then
        PSEXE="/usr/bin/ps"
        if [ ! -x "$PSEXE" ]
        then
            PSEXE="/bin/ps"
            if [ ! -x "$PSEXE" ]
            then
                echo 'Unable to locate "ps".'
                echo 'Please report this message along with the location of the command on your system.'
                exit 1
            fi
        fi
    fi

TREXE="/usr/bin/tr"
if [ ! -x "$TREXE" ]
then
    TREXE="/bin/tr"
    if [ ! -x "$TREXE" ]
    then
        echo 'Unable to locate "tr".'
        echo 'Please report this message along with the location of the command on your system.'
        exit 1
    fi
fi


# Resolve the os
DIST_OS=`uname -s | $TREXE "[A-Z]" "[a-z]" | $TREXE -d ' '`
case "$DIST_OS" in
    'sunos')
        DIST_OS="solaris"
        ;;
    'hp-ux' | 'hp-ux64')
        # HP-UX needs the XPG4 version of ps (for -o args)
        DIST_OS="hpux"
        UNIX95=""
        export UNIX95
        ;;
    'darwin')
        DIST_OS="macosx"
        ;;
    'unix_sv')
        DIST_OS="unixware"
        ;;
    'gnu/kfreebsd')
        DIST_OS="kfreebsd"
        ;;
    'os/390')
        DIST_OS="zos"
        ;;
esac

# Resolve the architecture
if [ "$DIST_OS" = "macosx" ]
then
    OS_VER=`sw_vers | grep ProductVersion | cut -d: -f2 | sed -e 's/[^0-9]*//'`
    DIST_ARCH="universal"
    if [ $(sysctl -n hw.cpu64bit_capable) -eq 1 ]; then
        DIST_BITS="64"
    else
        DIST_BITS="32"
    fi
    APP_PLIST_BASE=${PLIST_DOMAIN}.${APP_NAME}
    APP_PLIST=${APP_PLIST_BASE}.plist
else
    DIST_ARCH=`uname -m 2>/dev/null | $TREXE "[A-Z]" "[a-z]" | $TREXE -d ' '`
    case "$DIST_ARCH" in
        'athlon' | 'i386' | 'i486' | 'i586' | 'i686')
            DIST_ARCH="x86"
            if [ "${DIST_OS}" = "solaris" ] ; then
                DIST_BITS=`isainfo -b`
            else
                DIST_BITS="32"
            fi
            ;;
        amdfx* | 'amd64' | 'x86_64')
            DIST_ARCH="x86"
            DIST_BITS="64"
            ;;
        'ia32')
            DIST_ARCH="ia"
            DIST_BITS="32"
            ;;
        'ia64' | 'ia64n' | 'ia64w')
            DIST_ARCH="ia"
            DIST_BITS="64"
            ;;
        'ip27')
            DIST_ARCH="mips"
            DIST_BITS="32"
            ;;
        'power' | 'powerpc' | 'power_pc' | 'ppc64')
            if [ "${DIST_ARCH}" = "ppc64" ] ; then
                DIST_BITS="64"
            else
                DIST_BITS="32"
            fi
            DIST_ARCH="ppc"
            if [ "${DIST_OS}" = "aix" ] ; then
                if [ `getconf KERNEL_BITMODE` -eq 64 ]; then
                    DIST_BITS="64"
                else
                    DIST_BITS="32"
                fi
            fi
            ;;
        'pa_risc' | 'pa-risc')
            DIST_ARCH="parisc"
            if [ `getconf KERNEL_BITS` -eq 64 ]; then
                DIST_BITS="64"
            else
                DIST_BITS="32"
            fi
            ;;
        'sun4u' | 'sparcv9' | 'sparc')
            DIST_ARCH="sparc"
            DIST_BITS=`isainfo -b`
            ;;
        '9000/800' | '9000/785')
            DIST_ARCH="parisc"
            if [ `getconf KERNEL_BITS` -eq 64 ]; then
                DIST_BITS="64"
            else
                DIST_BITS="32"
            fi
            ;;
        '2064' | '2066' | '2084' | '2086' | '2094' | '2096' | '2097' | '2098' | '2817')
            DIST_ARCH="390"
            DIST_BITS="64"
            ;;
        armv*)
            if [ -z "`readelf -A /proc/self/exe | grep Tag_ABI_VFP_args`" ] ; then
                DIST_ARCH="armel"
                DIST_BITS="32"
            else
                DIST_ARCH="armhf"
                DIST_BITS="32"
            fi
            ;;
    esac
fi

# OSX always places Java in the same location so we can reliably set JAVA_HOME
if [ "$DIST_OS" = "macosx" ]
then
    if [ -z "$JAVA_HOME" ]; then
        JAVA_HOME="/Library/Java/Home"; export JAVA_HOME
    fi
fi

# Test Echo
ECHOTEST=`echo -n "x"`
if [ "$ECHOTEST" = "x" ]
then
    ECHOOPT="-n "
else
    ECHOOPT=""
fi


gettext() {
    # Call external gettext using our own translation files.
    # Don't attempt to translate via the wrapper,
    # it probably isn't supported in the community edition.
    if [ "X${LANG#en}" = "X$LANG" ] && [ $(which $GETTEXT > /dev/null 2>&1) ] ; then
            TEXTDOMAINDIR=$I2P/locale $GETTEXT -d i2prouter "$1"
            if [ $? != 0 ] ; then
                echo "$1"
            fi
        else
            echo "$1"
        fi
}

outputFile() {
    if [ -f "$1" ]
    then
        echo "  $1  Found but not executable.";
    else
        echo "  $1"
    fi
}

# Decide on the wrapper binary to use.
# If the bits of the OS could be detected, we will try to look for the
#  binary with the correct bits value.  If it doesn't exist, fall back
#  and look for the 32-bit binary.  If that doesn't exist either then
#  look for the default.
WRAPPER_TEST_CMD=""
if [ -f "$WRAPPER_CMD-$DIST_OS-$DIST_ARCH-$DIST_BITS" ]
then
    WRAPPER_TEST_CMD="$WRAPPER_CMD-$DIST_OS-$DIST_ARCH-$DIST_BITS"
    if [ ! -x "$WRAPPER_TEST_CMD" ]
    then
        chmod +x "$WRAPPER_TEST_CMD" 2>/dev/null
    fi
    if [ -x "$WRAPPER_TEST_CMD" ]
    then
        WRAPPER_CMD="$WRAPPER_TEST_CMD"
    else
        outputFile "$WRAPPER_TEST_CMD"
        WRAPPER_TEST_CMD=""
    fi
fi
if [ -f "$WRAPPER_CMD-$DIST_OS-$DIST_ARCH-32" -a -z "$WRAPPER_TEST_CMD" ]
then
    WRAPPER_TEST_CMD="$WRAPPER_CMD-$DIST_OS-$DIST_ARCH-32"
    if [ ! -x "$WRAPPER_TEST_CMD" ]
    then
        chmod +x "$WRAPPER_TEST_CMD" 2>/dev/null
    fi
    if [ -x "$WRAPPER_TEST_CMD" ]
    then
        WRAPPER_CMD="$WRAPPER_TEST_CMD"
    else
        outputFile "$WRAPPER_TEST_CMD"
        WRAPPER_TEST_CMD=""
    fi
fi
if [ -f "$WRAPPER_CMD" -a -z "$WRAPPER_TEST_CMD" ]
then
    WRAPPER_TEST_CMD="$WRAPPER_CMD"
    if [ ! -x "$WRAPPER_TEST_CMD" ]
    then
        chmod +x "$WRAPPER_TEST_CMD" 2>/dev/null
    fi
    if [ -x "$WRAPPER_TEST_CMD" ]
    then
        WRAPPER_CMD="$WRAPPER_TEST_CMD"
    else
        outputFile "$WRAPPER_TEST_CMD"
        WRAPPER_TEST_CMD=""
    fi
fi
if [ -z "$WRAPPER_TEST_CMD" ]
then
    echo 'Unable to locate any of the following binaries:'
    outputFile "$WRAPPER_CMD-$DIST_OS-$DIST_ARCH-$DIST_BITS"
    if [ ! "$DIST_BITS" = "32" ]
    then
        outputFile "$WRAPPER_CMD-$DIST_OS-$DIST_ARCH-32"
    fi
    outputFile "$WRAPPER_CMD"

    exit 1
fi

if [ ! -r "${WRAPPER_CMD}" ]; then
    echo "Unable to locate ${WRAPPER_CMD} in ${I2P}!"
    echo
    unsupported
    echo
    exit 1
fi

if $(which ldd > /dev/null 2>&1); then
    # This should cover every *NIX other than OSX since OSX doesn't have ldd.
    # OSX has otool. Is otool on every OSX installation? Is otool's output the same as ldd's?
    # The wrapper we ship for OSX are for PPC and Intel, so maybe we don't need to worry about OSX?
    if (ldd "$WRAPPER_CMD" |grep -q 'not found') > /dev/null 2>&1 || \
                         ! (ldd "$WRAPPER_CMD" > /dev/null 2>&1); then
        failed
    fi
fi


# Build the nice clause
if [ "X$PRIORITY" = "X" ]
then
    CMDNICE=""
else
    CMDNICE="nice -$PRIORITY"
fi

# Build the anchor file clause.
if [ "X$IGNORE_SIGNALS" = "X" ]
then
   ANCHORPROP=
   IGNOREPROP=
else
   ANCHORPROP=wrapper.anchorfile=\"$ANCHORFILE\"
   IGNOREPROP=wrapper.ignore_signals=TRUE
fi

# Build the status file clause.
if [ "X$DETAIL_STATUS$WAIT_FOR_STARTED_STATUS" = "X" ]
then
   STATUSPROP=
else
   STATUSPROP="wrapper.statusfile=\"$STATUSFILE\" wrapper.java.statusfile=\"$JAVASTATUSFILE\""
fi

# Build the command file clause.
COMMANDPROP=

# Build the log file clause.
LOGPROP="wrapper.logfile=\"$LOGFILE\""

if [ ! -n "$WAIT_FOR_STARTED_STATUS" ]
then
    WAIT_FOR_STARTED_STATUS=true
fi

if [ $WAIT_FOR_STARTED_STATUS = true ] ; then
    DETAIL_STATUS=true
fi


# Build the lock file clause.  Only create a lock file if the lock directory exists on this platform.
LOCKPROP=
if [ -d $LOCKDIR ]
then
    if [ -w $LOCKDIR ]
    then
        LOCKPROP=wrapper.lockfile=\"$LOCKFILE\"
    fi
fi

prepAdditionalParams() {
    ADDITIONAL_PARA=""
    if [ -n "$PASS_THROUGH" ] ; then
        ADDITIONAL_PARA="--"
    fi
    while [ -n "$1" ] ; do
        ADDITIONAL_PARA="$ADDITIONAL_PARA \"$1\""
        shift
    done
}

checkUser() {
    # $1 touchLock flag
    # $2.. [command] args

    # Check the configured user.  If necessary rerun this script as the desired user.
    if [ "X$RUN_AS_USER" != "X" ]
    then

        # Resolve the location of the 'id' command
        IDEXE="/usr/xpg4/bin/id"
        if [ ! -x "$IDEXE" ]
        then
            IDEXE="/usr/bin/id"
            if [ ! -x "$IDEXE" ]
            then
                echo 'Unable to locate "id".'
                echo 'Please report this message along with the location of the command on your system.'
                exit 1
            fi
        fi
        if [ "`$IDEXE -u -n "$RUN_AS_USER" 2>/dev/null`" != "$RUN_AS_USER" ]
        then
            echo "User $RUN_AS_USER does not exist."
            exit 1
        fi

        if [ "`$IDEXE -u -n`" = "$RUN_AS_USER" ]
        then
            # Already running as the configured user.  Avoid password prompts by not calling su.
            RUN_AS_USER=""
        fi
    fi
    if [ "X$RUN_AS_USER" != "X" ]
    then
        # If LOCKPROP and $RUN_AS_USER are defined then the new user will most likely not be
        # able to create the lock file.  The Wrapper will be able to update this file once it
        # is created but will not be able to delete it on shutdown.  If $1 is set then
        # the lock file should be created for the current command
        if [ "X$LOCKPROP" != "X" ]
        then
            if [ "X$1" != "X" ]
            then
                # Resolve the primary group
                RUN_AS_GROUP=`groups $RUN_AS_USER | awk '{print $3}' | tail -1`
                if [ "X$RUN_AS_GROUP" = "X" ]
                then
                    RUN_AS_GROUP=$RUN_AS_USER
                fi
                touch $LOCKFILE
                chown $RUN_AS_USER:$RUN_AS_GROUP $LOCKFILE
            fi
        fi

        # Still want to change users, recurse.  This means that the user will only be
        #  prompted for a password once. Variables shifted by 1
        shift

        # Wrap the parameters so they can be passed.
        ADDITIONAL_PARA=""
        while [ -n "$1" ] ; do
            ADDITIONAL_PARA="$ADDITIONAL_PARA \"$1\""
            shift
        done

        # Use "runuser" if this exists.  runuser should be used on RedHat in preference to su.
        #
        if test -f "/sbin/runuser"
        then
            /sbin/runuser -s /bin/sh - $RUN_AS_USER -c "\"$REALPATH\" $ADDITIONAL_PARA"
        else
            su - $RUN_AS_USER -s /bin/sh -c "\"$REALPATH\" $ADDITIONAL_PARA"
        fi
        RUN_AS_USER_EXITCODE=$?
        # Now that we are the original user again, we may need to clean up the lock file.
        if [ "X$LOCKPROP" != "X" ]
        then
            getpid
            if [ "X$pid" = "X" ]
            then
                # Wrapper is not running so make sure the lock file is deleted.
                if [ -f "$LOCKFILE" ]
                then
                    rm "$LOCKFILE"
                fi
            fi
        fi

        exit $RUN_AS_USER_EXITCODE
    fi
}

getpid() {
    pid=""
    if [ -f "$PIDFILE" ]
    then
        if [ -r "$PIDFILE" ]
        then
            pid=`cat "$PIDFILE"`
            if [ "X$pid" != "X" ]
            then
                # It is possible that 'a' process with the pid exists but that it is not the
                #  correct process.  This can happen in a number of cases, but the most
                #  common is during system startup after an unclean shutdown.
                # The ps statement below looks for the specific wrapper command running as
                #  the pid.  If it is not found then the pid file is considered to be stale.
                case "$DIST_OS" in
                    'freebsd')
                        pidtest=`$PSEXE -p $pid -o args | tail -1`
                        if [ "X$pidtest" = "XCOMMAND" ]
                        then
                            pidtest=""
                        fi
                        ;;
                    'macosx')
                        pidtest=`$PSEXE -ww -p $pid -o command | grep -F "$WRAPPER_CMD" | tail -1`
                        ;;
                    'solaris')
                        if [ -f "/usr/bin/pargs" ]
                        then
                            pidtest=`pargs $pid | fgrep "$WRAPPER_CMD" | tail -1`
                        else
                            case "$PSEXE" in
                            '/usr/ucb/ps')
                                pidtest=`$PSEXE -auxww  $pid | fgrep "$WRAPPER_CMD" | tail -1`
                                ;;
                            '/usr/bin/ps')
                                TRUNCATED_CMD=`$PSEXE -o comm -p $pid | tail -1`
                                COUNT=`echo $TRUNCATED_CMD | wc -m`
                                COUNT=`echo ${COUNT}`
                                COUNT=`expr $COUNT - 1`
                                TRUNCATED_CMD=`echo $WRAPPER_CMD | cut -c1-$COUNT`
                                pidtest=`$PSEXE -o comm -p $pid | fgrep "$TRUNCATED_CMD" | tail -1`
                                ;;
                            '/bin/ps')
                                TRUNCATED_CMD=`$PSEXE -o comm -p $pid | tail -1`
                                COUNT=`echo $TRUNCATED_CMD | wc -m`
                                COUNT=`echo ${COUNT}`
                                COUNT=`expr $COUNT - 1`
                                TRUNCATED_CMD=`echo $WRAPPER_CMD | cut -c1-$COUNT`
                                pidtest=`$PSEXE -o comm -p $pid | fgrep "$TRUNCATED_CMD" | tail -1`
                                ;;
                            *)
                                echo "Unsupported ps command $PSEXE"
                                exit 1
                                ;;
                            esac
                        fi
                        ;;
                    'hpux')
                        pidtest=`$PSEXE -p $pid -x -o args | grep -F "$WRAPPER_CMD" | tail -1`
                        ;;
                    *)
                        pidtest=`$PSEXE -p $pid -o args | grep -F "$WRAPPER_CMD" | tail -1`
                        ;;
                esac

                if [ "X$pidtest" = "X" ]
                then
                    # This is a stale pid file.
                    rm -f "$PIDFILE"
                    echo "Removed stale pid file: $PIDFILE"
                    pid=""
                fi
            fi
        else
            echo "Cannot read $PIDFILE."
            exit 1
        fi
    fi
}

getstatus() {
    STATUS=
    if [ -f "$STATUSFILE" ]
    then
        if [ -r "$STATUSFILE" ]
        then
            STATUS=`cat "$STATUSFILE"`
        fi
    fi
    if [ "X$STATUS" = "X" ]
    then
        STATUS="Unknown"
    fi

    JAVASTATUS=
    if [ -f "$JAVASTATUSFILE" ]
    then
        if [ -r "$JAVASTATUSFILE" ]
        then
            JAVASTATUS=`cat "$JAVASTATUSFILE"`
        fi
    fi
    if [ "X$JAVASTATUS" = "X" ]
    then
        JAVASTATUS="Unknown"
    fi
}

testpid() {
    case "$DIST_OS" in
     'solaris')
        case "$PSEXE" in
        '/usr/ucb/ps')
            pid=`$PSEXE  $pid | grep $pid | grep -v grep | awk '{print $1}' | tail -1`
            ;;
        '/usr/bin/ps')
            pid=`$PSEXE -p $pid | grep $pid | grep -v grep | awk '{print $1}' | tail -1`
            ;;
        '/bin/ps')
            pid=`$PSEXE -p $pid | grep $pid | grep -v grep | awk '{print $1}' | tail -1`
            ;;
        *)
            echo "Unsupported ps command $PSEXE"
            exit 1
            ;;
        esac
        ;;
    *)
        pid=`$PSEXE -p $pid | grep $pid | grep -v grep | awk '{print $1}' | tail -1` 2>/dev/null
        ;;
    esac
    if [ "X$pid" = "X" ]
    then
        # Process is gone so remove the pid file.
        rm -f "$PIDFILE"
        pid=""
    fi
}

launchdtrap() {
    stopit
    exit
}

waitforwrapperstop() {
    getpid
    while [ "X$pid" != "X" ] ; do
        sleep 1
        getpid
    done
}

create_config_dir() {
    if [ ! -d "$I2P_CONFIG_DIR" ]; then
        UMASK=$(awk -F'=' '/^ *wrapper\.umask/{print $2}' $WRAPPER_CONF)
        umask $UMASK
        if ! mkdir -p "$I2P_CONFIG_DIR"; then
            echo "Error creating $I2P_CONFIG_DIR! Edit $0 and set I2P_CONFIG_DIR" >&2
            echo "to the correct location." >&2
            exit 1
        fi
    fi
}

launchdinternal() {
    getpid
    trap launchdtrap TERM
    if [ "X$pid" = "X" ]
    then
        prepAdditionalParams "$@"
        create_config_dir

        # The string passed to eval must handles spaces in paths correctly.
        COMMAND_LINE="$CMDNICE \"$WRAPPER_CMD\" \"$WRAPPER_CONF\" wrapper.syslog.ident=\"$APP_NAME\" wrapper.pidfile=\"$PIDFILE\" wrapper.name=\"$APP_NAME\" wrapper.java.command=\"$JAVABINARY\" wrapper.displayname=\"$APP_LONG_NAME\" wrapper.daemonize=TRUE $ANCHORPROP $IGNOREPROP $STATUSPROP $COMMANDPROP $LOCKPROP $LOGPROP $ADDITIONAL_PARA"
        eval $COMMAND_LINE || failed
    else
        eval echo `gettext '$APP_LONG_NAME is already running.'`
        exit 1
    fi
    # launchd expects that this script stay up and running so we need to do our own monitoring of the Wrapper process.
    if [ $WAIT_FOR_STARTED_STATUS = true ]
    then
        waitforwrapperstop
    fi
}

console() {
    eval echo "`gettext 'Running $APP_LONG_NAME'`..."
    getpid
    if [ "X$pid" = "X" ]
    then
        trap '' 3 2

        prepAdditionalParams "$@"
        create_config_dir

        # The string passed to eval must handles spaces in paths correctly.
        COMMAND_LINE="$CMDNICE \"$WRAPPER_CMD\" \"$WRAPPER_CONF\" wrapper.syslog.ident=\"$APP_NAME\" wrapper.java.command=\"$JAVABINARY\" wrapper.pidfile=\"$PIDFILE\" wrapper.name=\"$APP_NAME\" wrapper.displayname=\"$APP_LONG_NAME\" $ANCHORPROP $STATUSPROP $COMMANDPROP $LOCKPROP $LOGPROP $ADDITIONAL_PARA"
        eval $COMMAND_LINE || failed
    else
        eval echo `gettext '$APP_LONG_NAME is already running.'`
        exit 1
    fi
}

waitforjavastartup() {
    getstatus
    eval echo $ECHOOPT "`gettext 'Waiting for $APP_LONG_NAME'`..."

    # Wait until the timeout or we have something besides Unknown.
    counter=15
    while [ "$JAVASTATUS" = "Unknown" -a $counter -gt 0 -a -n "$JAVASTATUS" ] ; do
        echo $ECHOOPT"."
        sleep 1
        getstatus
        counter=`expr $counter - 1`
    done

    if [ -n "$WAIT_FOR_STARTED_TIMEOUT" ] ; then
        counter=$WAIT_FOR_STARTED_TIMEOUT
    else
        counter=120
    fi
    while [ "$JAVASTATUS" != "STARTED" -a "$JAVASTATUS" != "Unknown" -a $counter -gt 0 -a -n "$JAVASTATUS" ] ; do
        echo $ECHOOPT"."
        sleep 1
        getstatus
        counter=`expr $counter - 1`
    done
    if [ "X$ECHOOPT" != "X" ] ; then
        echo ""
    fi
}

startwait() {
    if [ $WAIT_FOR_STARTED_STATUS = true ]
    then
        waitforjavastartup
    fi
    # Sleep for a few seconds to allow for intialization if required
    #  then test to make sure we're still running.
    #
    i=0
    while [ $i -lt $WAIT_AFTER_STARTUP ]
    do
        sleep 1
        echo $ECHOOPT"."
        i=`expr $i + 1`
    done
    if [ $WAIT_AFTER_STARTUP -gt 0 -o $WAIT_FOR_STARTED_STATUS = true ]
    then
        getpid
        if [ "X$pid" = "X" ]
        then
            eval echo " `gettext 'WARNING: $APP_LONG_NAME may have failed to start.'`"
        else
            eval echo ' running: PID:$pid'
        fi
    else
        echo ""
    fi
}

macosxstart() {
    # The daemon has been installed.
    echo "Starting $APP_LONG_NAME.  Detected Mac OSX and installed launchd daemon."
    if [ `id | sed 's/^uid=//;s/(.*$//'` != "0" ] ; then
        eval echo `gettext 'Must be root to perform this action.'`
        exit 1
    fi

    getpid
    if [ "X$pid" != "X" ] ; then
        eval echo `gettext '$APP_LONG_NAME is already running.'`
        exit 1
    fi

    # If the daemon was just installed, it may not be loaded.
    LOADED_PLIST=`launchctl list | grep ${APP_PLIST_BASE}`
    if [ "X${LOADED_PLIST}" = "X" ] ; then
        launchctl load /Library/LaunchDaemons/${APP_PLIST}
    fi
    # If launchd is set to run the daemon already at Load, we don't need to call start
    getpid
    if [ "X$pid" = "X" ] ; then
        launchctl start ${APP_PLIST_BASE}
    fi

    startwait
}

upstartstart() {
    # The daemon has been installed.
    echo "Starting $APP_LONG_NAME.  Detected Linux and installed upstart."
    if [ `id | sed 's/^uid=//;s/(.*$//'` != "0" ] ; then
        eval echo `gettext 'Must be root to perform this action.'`
        exit 1
    fi

    getpid
    if [ "X$pid" != "X" ] ; then
        eval echo `gettext '$APP_LONG_NAME is already running.'`
        exit 1
    fi

    /sbin/start ${APP_NAME}

    startwait
}

start() {
    eval echo "`gettext 'Starting $APP_LONG_NAME'`..."
    getpid
    if [ "X$pid" = "X" ]
    then
        prepAdditionalParams "$@"
        create_config_dir

        # The string passed to eval must handles spaces in paths correctly.
        COMMAND_LINE="$CMDNICE \"$WRAPPER_CMD\" \"$WRAPPER_CONF\" wrapper.syslog.ident=\"$APP_NAME\" wrapper.java.command=\"$JAVABINARY\" wrapper.pidfile=\"$PIDFILE\" wrapper.name=\"$APP_NAME\" wrapper.displayname=\"$APP_LONG_NAME\" wrapper.daemonize=TRUE $ANCHORPROP $IGNOREPROP $STATUSPROP $COMMANDPROP $LOCKPROP $LOGPROP $ADDITIONAL_PARA"
        eval $COMMAND_LINE || failed
    else
        eval echo `gettext '$APP_LONG_NAME is already running.'`
        exit 1
    fi

    startwait
}


stopit() {
    # $1 exit if down flag

    eval echo "`gettext 'Stopping $APP_LONG_NAME'`..."
    getpid
    if [ "X$pid" = "X" ]
    then
        eval echo `gettext '$APP_LONG_NAME was not running.'`
        if [ "X$1" = "X1" ]
        then
            exit 1
        fi
    else
        if [ "X$IGNORE_SIGNALS" = "X" ]
        then
            # Running so try to stop it.
            kill -TERM $pid
            if [ $? -ne 0 ]
            then
                # An explanation for the failure should have been given
                eval echo `gettext 'Unable to stop $APP_LONG_NAME.'`
                exit 1
            fi
        else
            rm -f "$ANCHORFILE"
            if [ -f "$ANCHORFILE" ]
            then
                # An explanation for the failure should have been given
                eval echo `gettext 'Unable to stop $APP_LONG_NAME.'`
                exit 1
            fi
        fi

        # We can not predict how long it will take for the wrapper to
        #  actually stop as it depends on settings in wrapper.conf.
        #  Loop until it does.
        savepid=$pid
        CNT=0
        TOTCNT=0
        while [ "X$pid" != "X" ]
        do
            # Show a waiting message every 5 seconds.
            if [ "$CNT" -lt "5" ]
            then
                CNT=`expr $CNT + 1`
            else
                eval echo "`gettext 'Waiting for $APP_LONG_NAME to exit'`..."
                CNT=0
            fi
            TOTCNT=`expr $TOTCNT + 1`

            sleep 1

            testpid
        done

        pid=$savepid
        testpid
        if [ "X$pid" != "X" ]
        then
            eval echo `gettext 'Failed to stop $APP_LONG_NAME.'`
            exit 1
        else
            eval echo `gettext 'Stopped $APP_LONG_NAME.'`
        fi
    fi
}

graceful() {
    # $1 exit if down flag

    eval echo "`gettext 'Stopping $APP_LONG_NAME gracefully'`..."
    getpid
    if [ "X$pid" = "X" ]
    then
        eval echo `gettext '$APP_LONG_NAME was not running.'`
        if [ "X$1" = "X1" ]
        then
            exit 1
        fi
    else
        if [ "X$IGNORE_SIGNALS" = "X" ]
        then
            # Running so try to stop it.
            # This sends HUP. router.gracefulHUP must be set in router.config,
            # or else this will do the same as stop.
            kill -HUP $pid
            if [ $? -ne 0 ]
            then
                # An explanation for the failure should have been given
                eval echo `gettext 'Unable to stop $APP_LONG_NAME.'`
                exit 1
            fi
        else
            rm -f "$ANCHORFILE"
            if [ -f "$ANCHORFILE" ]
            then
                # An explanation for the failure should have been given
                eval echo `gettext 'Unable to stop $APP_LONG_NAME.'`
                exit 1
            fi
        fi
    fi
}

pause() {
    echo "Pausing $APP_LONG_NAME."
}

resume() {
    echo "Resuming $APP_LONG_NAME."
}

status() {
    getpid
    if [ "X$pid" = "X" ]
    then
        eval echo `gettext '$APP_LONG_NAME is not running.'`
        exit 1
    else
        if [ "X$DETAIL_STATUS" = "X" ]
        then
            eval echo `gettext '$APP_LONG_NAME is running: PID:$pid'`
        else
            getstatus
            eval echo `gettext '$APP_LONG_NAME is running: PID:$pid, Wrapper:$STATUS, Java:$JAVASTATUS'`
        fi
        exit 0
    fi
}

installUpstart() {
    echo " Installing the $APP_LONG_NAME daemon using upstart.."
    if [ -f "${APP_NAME}.conf" ] ; then
        echo " a custom upstart conf file ${APP_NAME}.conf found"
        cp "${REALDIR}/${APP_NAME}.install" "/etc/init/${APP_NAME}.conf"
    else
        echo ' creating default upstart conf file..'
        echo "# ${APP_NAME} - ${APP_LONG_NAME}" > "/etc/init/${APP_NAME}.conf"
        echo "description \"${APP_LONG_NAME}\"" >> "/etc/init/${APP_NAME}.conf"
        echo "author \"Tanuki Software Ltd. <info@tanukisoftware.com>\"" >> "/etc/init/${APP_NAME}.conf"
        echo "start on runlevel [2345]" >> "/etc/init/${APP_NAME}.conf"
        echo "stop on runlevel [!2345]" >> "/etc/init/${APP_NAME}.conf"
        echo "env LANG=${LANG}" >> "/etc/init/${APP_NAME}.conf"
       echo "exec \"${REALPATH}\" launchdinternal" >> "/etc/init/${APP_NAME}.conf"
    fi
}

installsystemd() {
    if [ -d "/etc/systemd/system/" ]; then
        cat << EOF >> "$SYSTEMD_SERVICE"
[Unit]
Description=$APP_LONG_NAME
After= local-fs.target network.target

[Service]
Type=forking
ExecStart=$I2P/i2prouter start
ExecReload=$I2P/i2prouter restart
ExecStop=$I2P/i2prouter stop
PIDFile=$I2P_CONFIG_DIR/i2p.pid

[Install]
WantedBy=multi-user.target
EOF
    systemctl --system daemon-reload > /dev/null 2>&1
    fi
}

installdaemon() {
    if [ `id | sed 's/^uid=//;s/(.*$//'` != "0" ] ; then
        eval echo `gettext 'Must be root to perform this action.'`
        exit 1
    else
        APP_NAME_LOWER=`echo "$APP_NAME" | $TREXE "[A-Z]" "[a-z]"`
        if [ "$DIST_OS" = "solaris" ] ; then
            echo 'Detected Solaris:'
            if [ -f /etc/init.d/$APP_NAME ] ; then
                eval echo " `gettext 'The $APP_LONG_NAME daemon is already installed.'`"
                exit 1
            else
                eval echo " `gettext 'Installing the $APP_LONG_NAME daemon'`.."
                ln -s "$REALPATH" "/etc/init.d/$APP_NAME"
                ln -s "/etc/init.d/$APP_NAME" "/etc/rc3.d/K20$APP_NAME_LOWER"
                ln -s "/etc/init.d/$APP_NAME" "/etc/rc3.d/S20$APP_NAME_LOWER"
            fi
        elif [ "$DIST_OS" = "linux" ] ; then
            if [ -f /etc/redhat-release -o -f /etc/redhat_version -o -f /etc/fedora-release ]  ; then
                echo 'Detected RHEL or Fedora:'
                if [ -f "/etc/init.d/$APP_NAME" -o -f "/etc/init/${APP_NAME}.conf" ] ; then
                    eval echo " `gettext 'The $APP_LONG_NAME daemon is already installed.'`"
                    exit 1
                else
                    if [ -n "$USE_UPSTART" -a -d "/etc/init" ] ; then
                        installUpstart
                    else
                        eval echo " `gettext 'Installing the $APP_LONG_NAME daemon'`.."
                        ln -s "$REALPATH" "/etc/init.d/$APP_NAME"
                        /sbin/chkconfig --add "$APP_NAME"
                        /sbin/chkconfig "$APP_NAME" on
                    fi
                fi
            elif [ -f /etc/slackware-version ]; then
                echo 'Detected Slackware Linux:'
                if [ -e "/etc/rc.d/rc.i2p" -o -f "/etc/rc.d/rc.i2p.new" ]; then
                    echo "Found initscript from I2P Slackpkg. Aborting." >&2
                    exit 1
                else
                    if grep -q ${APP_NAME}router /etc/rc.d/rc.local > /dev/null 2>&1; then
                        eval echo " `gettext 'The $APP_LONG_NAME daemon is already installed.'`"
                        exit 1
                    else
                        echo "${REALDIR}/${APP_NAME}router start"  >> /etc/rc.d/rc.local
                        if [ ! -e /etc/rc.d/rc.local_shutdown ]; then
                            echo "#!/bin/sh" >> /etc/rc.d/rc.local_shutdown
                        fi
                        echo "${REALDIR}/${APP_NAME}router stop"  >> /etc/rc.d/rc.local_shutdown
                        chmod 755 /etc/rc.d/rc.local_shutdown
                    fi
                fi
            elif [ -f /etc/arch-release ]; then
            echo 'Detected Arch Linux:'
                if [ -f "/etc/rc.d/i2prouter" -o -f "/usr/lib/systemd/system/i2prouter.service" ]; then
                    echo 'AUR package found. Refusing to continue.'
                    exit 1
                elif [ -f /etc/rc.d/i2p -a ! "$USE_SYSTEMD" = "1" ] || [ -f "$SYSTEMD_SERVICE" -a "$USE_SYSTEMD" = "1" ]; then
                    eval echo " `gettext 'The $APP_LONG_NAME daemon is already installed.'`"
                    exit 1
                else
                        if [ ! -f "/etc/init.d/i2p" ]; then
                            if [ "$USE_SYSTEMD" != "1" ]; then
                                echo "#!/bin/bash"  > /etc/rc.d/${APP_NAME}
                                echo   >> /etc/rc.d/${APP_NAME}
                                echo ". /etc/rc.conf"  >> /etc/rc.d/${APP_NAME}
                                echo ". /etc/rc.d/functions"  >> /etc/rc.d/${APP_NAME}
                                echo   >> /etc/rc.d/${APP_NAME}
                                echo "case "\$1" in"  >> /etc/rc.d/${APP_NAME}
                                echo "  start)"  >> /etc/rc.d/${APP_NAME}
                                echo "    stat_busy \"Starting i2p-Router\""  >> /etc/rc.d/${APP_NAME}
                                echo "    ${REALDIR}/${APP_NAME}router start >/dev/null 2>&1"  >> /etc/rc.d/${APP_NAME}
                                echo "    if [ \$? -gt 0 ]; then"  >> /etc/rc.d/${APP_NAME}
                                echo "      stat_fail"  >> /etc/rc.d/${APP_NAME}
                                echo "    else"  >> /etc/rc.d/${APP_NAME}
                                echo "      stat_done"  >> /etc/rc.d/${APP_NAME}
                                echo "      add_daemon i2prouter"  >> /etc/rc.d/${APP_NAME}
                                echo "    fi"  >> /etc/rc.d/${APP_NAME}
                                echo "    ;;"  >> /etc/rc.d/${APP_NAME}
                                echo "  stop)"  >> /etc/rc.d/${APP_NAME}
                                echo "    stat_busy "Stopping i2p-Router""  >> /etc/rc.d/${APP_NAME}
                                echo "    ${REALDIR}/${APP_NAME}router stop > /dev/null 2>&1"  >> /etc/rc.d/${APP_NAME}
                                echo "    if [ \$? -gt 0 ]; then"  >> /etc/rc.d/${APP_NAME}
                                echo "      stat_fail"  >> /etc/rc.d/${APP_NAME}
                                echo "    else"  >> /etc/rc.d/${APP_NAME}
                                echo "      stat_done"  >> /etc/rc.d/${APP_NAME}
                                echo "      rm_daemon i2prouter"  >> /etc/rc.d/${APP_NAME}
                                echo "    fi"  >> /etc/rc.d/${APP_NAME}
                                echo "    ;;"  >> /etc/rc.d/${APP_NAME}
                                echo "  restart)"  >> /etc/rc.d/${APP_NAME}
                                echo "    ${REALDIR}/${APP_NAME}router restart"  >> /etc/rc.d/${APP_NAME}
                                echo "    ;;"  >> /etc/rc.d/${APP_NAME}
                                echo "  console)"  >> /etc/rc.d/${APP_NAME}
                                echo "    ${REALDIR}/${APP_NAME}router console"  >> /etc/rc.d/${APP_NAME}
                                echo "    ;;"  >> /etc/rc.d/${APP_NAME}
                                echo "  status)"  >> /etc/rc.d/${APP_NAME}
                                echo "    ${REALDIR}/${APP_NAME}router status"  >> /etc/rc.d/${APP_NAME}
                                echo "    ;;"  >> /etc/rc.d/${APP_NAME}
                                echo "  dump)"  >> /etc/rc.d/${APP_NAME}
                                echo "    ${REALDIR}/${APP_NAME}router dump"  >> /etc/rc.d/${APP_NAME}
                                echo "    ;;"  >> /etc/rc.d/${APP_NAME}
                                echo "  graceful)"  >> /etc/rc.d/${APP_NAME}
                                echo "    ${REALDIR}/${APP_NAME}router graceful"  >> /etc/rc.d/${APP_NAME}
                                echo "    ;;"  >> /etc/rc.d/${APP_NAME}
                                echo "  *)"  >> /etc/rc.d/${APP_NAME}
                                echo "    echo \"usage: \$0 {start|stop|restart|console|status|dump}\""  >> /etc/rc.d/${APP_NAME}
                                echo "    ;;"  >> /etc/rc.d/${APP_NAME}
                                echo "esac"  >> /etc/rc.d/${APP_NAME}
                                chmod 755 /etc/rc.d/${APP_NAME}
                                chown root:root /etc/rc.d/${APP_NAME}
                                echo " The $APP_LONG_NAME daemon has been installed."
                                echo ' Add \"i2p\" to the DAEMONS variable in /etc/rc.conf to enable.'
                            else
                                # We'll end up here if systemd is enabled.
                                # If systemd is enabled we don't need the initscript
                                rm -f /etc/rc.d/${APP_NAME}
                            fi
                        fi
                        if [ ! -f "${SYSTEMD_SERVICE}" ]; then
                            installsystemd
                        fi
                fi
            elif [ -f /etc/SuSE-release ] ; then
                echo 'Detected SuSE or SLES:'
                 if [ -f /etc/rc.d/${APP_NAME} -a ! "$USE_SYSTEMD" = "1" ] || [ -f "$SYSTEMD_SERVICE" -a "$USE_SYSTEMD" = "1" ]; then
                    eval echo " `gettext 'The $APP_LONG_NAME daemon is already installed.'`"
                    exit 1
                else
                    if [ ! -f "/etc/init.d/$APP_NAME" ]; then
                        if [ "$USE_SYSTEMD" != "1" ]; then
                            eval echo " `gettext 'Installing the $APP_LONG_NAME daemon'`.."
                            ln -s "$REALPATH" "/etc/init.d/$APP_NAME"
                            sed -i "s/Default-Start: 2 3 4 5/Default-Start: 5/" $0
                            insserv "/etc/init.d/$APP_NAME"
                        else
                            rm -f "/etc/init.d/$APP_NAME"
                        fi
                    fi
                    if [ ! -f "${SYSTEMD_SERVICE}" ]; then
                        installsystemd
                    fi
                fi
            elif [ -f /etc/lsb-release -o -f /etc/debian_version ] ; then
                echo 'Detected Debian-based distribution:'
                if [ -f "/etc/init.d/$APP_NAME" -o -f "/etc/init/${APP_NAME}.conf" ] ; then
                    eval echo " `gettext 'The $APP_LONG_NAME daemon is already installed.'`"
                    exit 1
                else
                    if [ -n "$USE_UPSTART" -a -d "/etc/init" ] ; then
                        installUpstart
                    else
                        echo " Installing the $APP_LONG_NAME daemon using init.d.."
                        ln -s "$REALPATH" "/etc/init.d/$APP_NAME"
                        update-rc.d "$APP_NAME" defaults
                    fi
                fi
            else
                echo 'Detected Linux:'
                if [ -f "/etc/init.d/$APP_NAME" ] ; then
                    eval echo " `gettext 'The $APP_LONG_NAME daemon is already installed.'`"
                    exit 1
                else
                    eval echo " `gettext 'Installing the $APP_LONG_NAME daemon'`.."
                    ln -s "$REALPATH" /etc/init.d/$APP_NAME
                    ln -s "/etc/init.d/$APP_NAME" "/etc/rc3.d/K20$APP_NAME_LOWER"
                    ln -s "/etc/init.d/$APP_NAME" "/etc/rc3.d/S20$APP_NAME_LOWER"
                    ln -s "/etc/init.d/$APP_NAME" "/etc/rc5.d/S20$APP_NAME_LOWER"
                    ln -s "/etc/init.d/$APP_NAME" "/etc/rc5.d/K20$APP_NAME_LOWER"
                fi
            fi
        elif [ "$DIST_OS" = "hpux" ] ; then
            echo 'Detected HP-UX:'
            if [ -f "/sbin/init.d/$APP_NAME" ] ; then
                eval echo " `gettext 'The $APP_LONG_NAME daemon is already installed.'`"
                exit 1
            else
                eval echo " `gettext 'Installing the $APP_LONG_NAME daemon'`.."
                ln -s "$REALPATH" "/sbin/init.d/$APP_NAME"
                ln -s "/sbin/init.d/$APP_NAME" "/sbin/rc3.d/K20$APP_NAME_LOWER"
                ln -s "/sbin/init.d/$APP_NAME" "/sbin/rc3.d/S20$APP_NAME_LOWER"
            fi
        elif [ "$DIST_OS" = "aix" ] ; then
            echo 'Detected AIX:'
            if [ -f "/etc/rc.d/init.d/$APP_NAME" ] ; then
                echo " The $APP_LONG_NAME daemon is already installed as rc.d script."
                exit 1
            elif [ -n "`/usr/sbin/lsitab $APP_NAME`" -a -n "`/usr/bin/lssrc -S -s $APP_NAME`" ] ; then
                echo " The $APP_LONG_NAME daemon is already installed as SRC service."
                exit 1
            else
                eval echo " `gettext 'Installing the $APP_LONG_NAME daemon'`.."
                if [ -n "`/usr/sbin/lsitab install_assist`" ] ; then
                    echo ' The task /usr/sbin/install_assist was found in the inittab, this might cause problems for all subsequent tasks to launch at this process is known to block the init task. Please make sure this task is not needed anymore and remove/deactivate it.'
                fi
                /usr/bin/mkssys -s "$APP_NAME" -p "$REALPATH" -a "launchdinternal" -u 0 -f 9 -n 15 -S
                /usr/sbin/mkitab "$APP_NAME":2:once:"/usr/bin/startsrc -s \"${APP_NAME}\" >/dev/console 2>&1"

            fi
        elif [ "$DIST_OS" = "freebsd" ] ; then
            echo 'Detected FreeBSD:'
            if [ -f "/etc/rc.d/$APP_NAME" ] ; then
                eval echo " `gettext 'The $APP_LONG_NAME daemon is already installed.'`"
                exit 1
            else
                eval echo " `gettext 'Installing the $APP_LONG_NAME daemon'`.."
                sed -i .bak "/${APP_NAME}_enable=\"YES\"/d" /etc/rc.conf
                if [ -f "${REALDIR}/${APP_NAME}.install" ] ; then
                    ln -s "${REALDIR}/${APP_NAME}.install" "/etc/rc.d/$APP_NAME"
                else
                    echo '#!/bin/sh' > "/etc/rc.d/$APP_NAME"
                    echo "#" >> "/etc/rc.d/$APP_NAME"
                    echo "# PROVIDE: $APP_NAME" >> "/etc/rc.d/$APP_NAME"
                    echo "# REQUIRE: NETWORKING" >> "/etc/rc.d/$APP_NAME"
                    echo "# KEYWORD: shutdown" >> "/etc/rc.d/$APP_NAME"
                    echo ". /etc/rc.subr" >> "/etc/rc.d/$APP_NAME"
                    echo "name=\"$APP_NAME\"" >> "/etc/rc.d/$APP_NAME"
                    echo "rcvar=\`set_rcvar\`" >> "/etc/rc.d/$APP_NAME"
                    echo "command=\"${REALDIR}/${APP_NAME}router\"" >> "/etc/rc.d/$APP_NAME"
                    echo 'start_cmd="${name}_start"' >> "/etc/rc.d/$APP_NAME"
                    echo 'load_rc_config $name' >> "/etc/rc.d/$APP_NAME"
                    echo 'status_cmd="${name}_status"' >> "/etc/rc.d/$APP_NAME"
                    echo 'stop_cmd="${name}_stop"' >> "/etc/rc.d/$APP_NAME"
                    echo "${APP_NAME}_status() {" >> "/etc/rc.d/$APP_NAME"
                    echo '${command} status' >> "/etc/rc.d/$APP_NAME"
                    echo '}' >> "/etc/rc.d/$APP_NAME"
                    echo "${APP_NAME}_stop() {" >> "/etc/rc.d/$APP_NAME"
                    echo '${command} stop' >> "/etc/rc.d/$APP_NAME"
                    echo '}' >> "/etc/rc.d/$APP_NAME"
                    echo "${APP_NAME}_start() {" >> "/etc/rc.d/$APP_NAME"
                    echo '${command} start' >> "/etc/rc.d/$APP_NAME"
                    echo '}' >> "/etc/rc.d/$APP_NAME"
                    echo 'run_rc_command "$1"' >> "/etc/rc.d/$APP_NAME"
                fi
                echo "${APP_NAME}_enable=\"YES\"" >> /etc/rc.conf
                chmod 555 "/etc/rc.d/$APP_NAME"
            fi
        elif [ "$DIST_OS" = "macosx" ] ; then
            echo 'Detected Mac OSX:'
            if [ -f "/Library/LaunchDaemons/${APP_PLIST}" ] ; then
                eval echo " `gettext 'The $APP_LONG_NAME daemon is already installed.'`"
                exit 1
            else
                eval echo " `gettext 'Installing the $APP_LONG_NAME daemon'`.."
                if [ -f "${REALDIR}/${APP_PLIST}" ] ; then
                    ln -s "${REALDIR}/${APP_PLIST}" "/Library/LaunchDaemons/${APP_PLIST}"
                else
                    echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" > "/Library/LaunchDaemons/${APP_PLIST}"
                    echo "<!DOCTYPE plist PUBLIC \"-//Apple Computer//DTD PLIST 1.0//EN\"" >> "/Library/LaunchDaemons/${APP_PLIST}"
                    echo "\"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">" >> "/Library/LaunchDaemons/${APP_PLIST}"
                    echo "<plist version=\"1.0\">" >> "/Library/LaunchDaemons/${APP_PLIST}"
                    echo "    <dict>" >> "/Library/LaunchDaemons/${APP_PLIST}"
                    echo "        <key>Label</key>" >> "/Library/LaunchDaemons/${APP_PLIST}"
                    echo "        <string>${APP_PLIST_BASE}</string>" >> "/Library/LaunchDaemons/${APP_PLIST}"
                    echo "        <key>ProgramArguments</key>" >> "/Library/LaunchDaemons/${APP_PLIST}"
                    echo "        <array>" >> "/Library/LaunchDaemons/${APP_PLIST}"
                    echo "            <string>${REALDIR}/${APP_NAME}router</string>" >> "/Library/LaunchDaemons/${APP_PLIST}"
                    echo "            <string>launchdinternal</string>" >> "/Library/LaunchDaemons/${APP_PLIST}"
                    echo "        </array>" >> "/Library/LaunchDaemons/${APP_PLIST}"
                    echo "        <key>OnDemand</key>" >> "/Library/LaunchDaemons/${APP_PLIST}"
                    echo "        <true/>" >> "/Library/LaunchDaemons/${APP_PLIST}"
                    echo "        <key>RunAtLoad</key>" >> "/Library/LaunchDaemons/${APP_PLIST}"
                    echo "        <true/>" >> "/Library/LaunchDaemons/${APP_PLIST}"
                    if [ "X$RUN_AS_USER" != "X" ] ; then
                        echo "        <key>UserName</key>" >> "/Library/LaunchDaemons/${APP_PLIST}"
                        echo "        <string>${RUN_AS_USER}</string>" >> "/Library/LaunchDaemons/${APP_PLIST}"
                    fi
                    echo "    </dict>" >> "/Library/LaunchDaemons/${APP_PLIST}"
                    echo "</plist>" >> "/Library/LaunchDaemons/${APP_PLIST}"
                fi
                chmod 555 "/Library/LaunchDaemons/${APP_PLIST}"
            fi
        elif [ "$DIST_OS" = "zos" ] ; then
            echo 'Detected z/OS:'
            if [ -f /etc/rc.bak ] ; then
                eval echo " `gettext 'The $APP_LONG_NAME daemon is already installed.'`"
                exit 1
            else
                eval echo " `gettext 'Installing the $APP_LONG_NAME daemon'`.."
                cp /etc/rc /etc/rc.bak
                sed  "s:echo /etc/rc script executed, \`date\`::g" /etc/rc.bak > /etc/rc
                echo "_BPX_JOBNAME='${APP_NAME}' \"${REALDIR}/${APP_NAME}router\" start" >>/etc/rc
                echo '/etc/rc script executed, `date`' >>/etc/rc
            fi
        else
            eval echo `gettext 'Install not currently supported for $DIST_OS'`
            exit 1
        fi
    fi
}

removedaemon() {
    if [ `id | sed 's/^uid=//;s/(.*$//'` != "0" ] ; then
        eval echo `gettext 'Must be root to perform this action.'`
        exit 1
    else
        stopit "0"
        APP_NAME_LOWER=`echo "$APP_NAME" | $TREXE "[A-Z]" "[a-z]"`
        if [ "$DIST_OS" = "solaris" ] ; then
            echo 'Detected Solaris:'
            if [ -f "/etc/init.d/$APP_NAME" ] ; then
                eval echo " `gettext 'Removing $APP_LONG_NAME daemon'`..."
                for i in "/etc/rc3.d/S20$APP_NAME_LOWER" "/etc/rc3.d/K20$APP_NAME_LOWER" "/etc/init.d/$APP_NAME"
                do
                    rm -f $i
                done
            else
                eval echo " `gettext 'The $APP_LONG_NAME daemon is not currently installed.'`"
                exit 1
            fi
        elif [ "$DIST_OS" = "linux" ] ; then
            if [ -f /etc/redhat-release -o -f /etc/redhat_version -o -f /etc/fedora-release ] ; then
                echo 'Detected RHEL or Fedora:'
                if [ -f "/etc/init.d/$APP_NAME" ] ; then
                    eval echo " `gettext 'Removing $APP_LONG_NAME daemon'`..."
                    /sbin/chkconfig "$APP_NAME" off
                    /sbin/chkconfig --del "$APP_NAME"
                    rm -f "/etc/init.d/$APP_NAME"
                elif [ -f "/etc/init/${APP_NAME}.conf" ] ; then
                    echo " Removing $APP_LONG_NAME daemon from upstart..."
                    rm "/etc/init/${APP_NAME}.conf"
                else
                    eval echo " `gettext 'The $APP_LONG_NAME daemon is not currently installed.'`"
                    exit 1
                fi
            elif [ -f /etc/slackware-version ] ; then
                echo 'Detected Slackware Linux:'
                if grep -q ${APP_NAME}router /etc/rc.d/rc.local > /dev/null 2>&1 ; then
                    eval echo " `gettext 'Removing $APP_LONG_NAME daemon'`..."
                    sed -i "/i2prouter/d" /etc/rc.d/rc.local /etc/rc.d/rc.local_shutdown
                else
                    eval echo " `gettext 'The $APP_LONG_NAME daemon is not currently installed.'`"
                    exit 1
                fi
            elif [ -f /etc/arch-release ] ; then
                echo 'Detected Arch Linux:'
                if [ -f "/etc/rc.d/$APP_NAME" -o -f "$SYSTEMD_SERVICE" ] ; then
                    eval echo "`gettext 'Removing $APP_LONG_NAME daemon'`..."
                    rm -f "/etc/rc.d/$APP_NAME"
                    rm -f "$SYSTEMD_SERVICE"
                else
                    eval echo " `gettext 'The $APP_LONG_NAME daemon is not currently installed.'`"
                    exit 1
                fi
            elif [ -f /etc/SuSE-release ] ; then
                echo 'Detected SuSE or SLES:'
                if [ -f "/etc/init.d/$APP_NAME" -o ${SYSTEMD_SERVICE} ] ; then
                    eval echo " `gettext 'Removing $APP_LONG_NAME daemon'`..."
                    insserv -r "/etc/init.d/$APP_NAME"
                    rm -f "/etc/init.d/$APP_NAME"
                    rm -f "$SYSTEMD_SERVICE"
                else
                    eval echo " `gettext 'The $APP_LONG_NAME daemon is not currently installed.'`"
                    exit 1
                fi
            elif [ -f /etc/lsb-release -o -f /etc/debian_version ] ; then
                echo 'Detected Debian-based distribution:'
                if [ -f "/etc/init.d/$APP_NAME" ] ; then
                    echo " Removing $APP_LONG_NAME daemon from init.d..."
                    update-rc.d -f "$APP_NAME" remove
                    rm -f "/etc/init.d/$APP_NAME"
                elif [ -f "/etc/init/${APP_NAME}.conf" ] ; then
                    echo " Removing $APP_LONG_NAME daemon from upstart..."
                    rm "/etc/init/${APP_NAME}.conf"
                else
                    eval echo " `gettext 'The $APP_LONG_NAME daemon is not currently installed.'`"
                    exit 1
                fi
            else
                echo 'Detected Linux:'
                if [ -f "/etc/init.d/$APP_NAME" ] ; then
                    eval echo " `gettext 'Removing $APP_LONG_NAME daemon'`..."
                    for i in "/etc/rc3.d/K20$APP_NAME_LOWER" "/etc/rc5.d/K20$APP_NAME_LOWER" "/etc/rc3.d/S20$APP_NAME_LOWER" "/etc/init.d/$APP_NAME" "/etc/rc5.d/S20$APP_NAME_LOWER"
                    do
                        rm -f $i
                    done
                else
                    eval echo " `gettext 'The $APP_LONG_NAME daemon is not currently installed.'`"
                    exit 1
                fi
            fi
        elif [ "$DIST_OS" = "hpux" ] ; then
            echo 'Detected HP-UX:'
            if [ -f "/sbin/init.d/$APP_NAME" ] ; then
                eval echo " `gettext 'Removing $APP_LONG_NAME daemon'`..."
                for i in "/sbin/rc3.d/K20$APP_NAME_LOWER" "/sbin/rc3.d/S20$APP_NAME_LOWER" "/sbin/init.d/$APP_NAME"
                do
                    rm -f $i
                done
            else
                eval echo " `gettext 'The $APP_LONG_NAME daemon is not currently installed.'`"
                exit 1
            fi
        elif [ "$DIST_OS" = "aix" ] ; then
            echo 'Detected AIX:'
            if [ -f "/etc/rc.d/init.d/$APP_NAME" -o -n "`/usr/sbin/lsitab $APP_NAME`" -o -n "`/usr/bin/lssrc -S -s $APP_NAME`" ] ; then
                eval echo " `gettext 'Removing $APP_LONG_NAME daemon'`..."
                if [ -f "/etc/rc.d/init.d/$APP_NAME" ] ; then
                    for i in "/etc/rc.d/rc2.d/S20$APP_NAME_LOWER" "/etc/rc.d/rc2.d/K20$APP_NAME_LOWER" "/etc/rc.d/init.d/$APP_NAME"
                    do
                        rm -f $i
                    done
                fi
                if [ -n "`/usr/sbin/lsitab $APP_NAME`" -o -n "`/usr/bin/lssrc -S -s $APP_NAME`" ] ; then
                    /usr/sbin/rmitab $APP_NAME
                    /usr/bin/rmssys -s $APP_NAME
                fi
            else
                eval echo " `gettext 'The $APP_LONG_NAME daemon is not currently installed.'`"
                exit 1
            fi
        elif [ "$DIST_OS" = "freebsd" ] ; then
            echo 'Detected FreeBSD:'
            if [ -f "/etc/rc.d/$APP_NAME" ] ; then
                eval echo " `gettext 'Removing $APP_LONG_NAME daemon'`..."
                for i in "/etc/rc.d/$APP_NAME"
                do
                    rm -f $i
                done
                sed -i .bak "/${APP_NAME}_enable=\"YES\"/d" /etc/rc.conf
            else
                eval echo " `gettext 'The $APP_LONG_NAME daemon is not currently installed.'`"
                exit 1
            fi
        elif [ "$DIST_OS" = "macosx" ] ; then
            echo 'Detected Mac OSX:'
            if [ -f "/Library/LaunchDaemons/${APP_PLIST}" ] ; then
                eval echo " `gettext 'Removing $APP_LONG_NAME daemon'`..."
                # Make sure the plist is installed
                LOADED_PLIST=`launchctl list | grep ${APP_PLIST_BASE}`
                if [ "X${LOADED_PLIST}" != "X" ] ; then
                    launchctl unload "/Library/LaunchDaemons/${APP_PLIST}"
                fi
                rm -f "/Library/LaunchDaemons/${APP_PLIST}"
            else
                eval echo " `gettext 'The $APP_LONG_NAME daemon is not currently installed.'`"
                exit 1
            fi
        elif [ "$DIST_OS" = "zos" ] ; then
            echo 'Detected z/OS:'
            if [ -f /etc/rc.bak ] ; then
                eval echo " `gettext 'Removing $APP_LONG_NAME daemon'`..."
                cp /etc/rc /etc/rc.bak
                sed  "s/_BPX_JOBNAME=\'APP_NAME\'.*//g" /etc/rc.bak > /etc/rc
                rm /etc/rc.bak
            else
                eval echo " `gettext 'The $APP_LONG_NAME daemon is not currently installed.'`"
                exit 1
            fi
        else
            eval echo `gettext 'Remove not currently supported for $DIST_OS'`
            exit 1
        fi
    fi
}

dump() {
    echo "Dumping $APP_LONG_NAME..."
    getpid
    if [ "X$pid" = "X" ]
    then
        eval echo `gettext '$APP_LONG_NAME was not running.'`
    else
        kill -3 $pid

        if [ $? -ne 0 ]
        then
            echo "Failed to dump $APP_LONG_NAME."
            exit 1
        else
            echo "Dumped $APP_LONG_NAME."
        fi
    fi
}

# Used by HP-UX init scripts.
startmsg() {
    getpid
    if [ "X$pid" = "X" ]
    then
        echo "Starting $APP_LONG_NAME...  Wrapper:Stopped"
    else
        if [ "X$DETAIL_STATUS" = "X" ]
        then
            echo "Starting $APP_LONG_NAME...  Wrapper:Running"
        else
            getstatus
            echo "Starting $APP_LONG_NAME...  Wrapper:$STATUS, Java:$JAVASTATUS"
        fi
    fi
}

# Used by HP-UX init scripts.
stopmsg() {
    getpid
    if [ "X$pid" = "X" ]
    then
        echo "Stopping $APP_LONG_NAME...  Wrapper:Stopped"
    else
        if [ "X$DETAIL_STATUS" = "X" ]
        then
            echo "Stopping $APP_LONG_NAME...  Wrapper:Running"
        else
            getstatus
            echo "Stopping $APP_LONG_NAME...  Wrapper:$STATUS, Java:$JAVASTATUS"
        fi
    fi
}

showUsage() {
    # $1 bad command

    if [ -n "$1" ]
    then
        echo "Unexpected command: $1"
        echo "";
    fi

    MSG='Usage: '
    if [ -n "$FIXED_COMMAND" ] ; then
        if [ -n "$PASS_THROUGH" ] ; then
            echo "${MSG} $0 {JavaAppArgs}"
        else
            echo "${MSG} $0"
        fi
    else
            if [ -n "$PASS_THROUGH" ] ; then
                echo "${MSG} $0 [ console {JavaAppArgs} | start {JavaAppArgs} | stop | restart {JavaAppArgs} | condrestart {JavaAppArgs} | status | install | remove | dump ]"
            else
                echo "${MSG} $0 [ console | start | stop | graceful | restart | condrestart | status | install | remove | dump ]"
        fi
    fi

    if [ ! -n "$BRIEF_USAGE" ]
    then
        echo "";
        if [ ! -n "$FIXED_COMMAND" ] ; then
            echo "`gettext 'Commands:'`"
            echo "  console      `gettext 'Launch in the current console.'`"
            echo "  start        `gettext 'Start in the background as a daemon process.'`"
            echo "  stop         `gettext 'Stop if running as a daemon or in another console.'`"
            echo "  graceful     `gettext 'Stop gracefully, may take up to 11 minutes.'`"
            echo "  restart      `gettext 'Stop if running and then start.'`"
            echo "  condrestart  `gettext 'Restart only if already running.'`"
            echo "  status       `gettext 'Query the current status.'`"
            echo "  install      `gettext 'Install to start automatically when system boots.'`"
            echo "  remove       `gettext 'Uninstall.'`"
            echo "  dump         `gettext 'Request a Java thread dump if running.'`"
            echo "";
        fi
        if [ -n "$PASS_THROUGH" ] ; then
            echo "JavaAppArgs: Zero or more arguments which will be passed to the Java application."
            echo "";
        fi
    fi

    exit 1
}

showsetusermesg()  {
    echo "`gettext 'Please edit /etc/default/i2p and set the variable RUN_AS_USER'`."
}

checkifstartingasroot() {
    if [ ! `grep ^RUN_AS_USER $0` ] && [ ! `grep ^ALLOW_ROOT $0` ] && [ `id -ur` = '0' ]; then
        echo "`gettext 'Running I2P as the root user is *not* recommended.'`"
        showsetusermesg
        echo
        echo "`gettext 'To run as root anyway, edit /etc/default/i2p and set ALLOW_ROOT=true.'`"
        exit 1
    fi
}

docommand() {
    case "$COMMAND" in
        'console')
            checkifstartingasroot
            checkUser touchlock "$@"
            if [ ! -n "$FIXED_COMMAND" ] ; then
                shift
            fi
            console "$@"
            ;;

        'start')
            checkifstartingasroot
            if [ "$DIST_OS" = "macosx" -a -f "/Library/LaunchDaemons/${APP_PLIST}" ] ; then
                macosxstart
            elif [ "$DIST_OS" = "linux" -a -f "/etc/init/${APP_NAME}.conf" ] ; then
                checkUser touchlock "$@"
                upstartstart
            else
                checkUser touchlock "$@"
                if [ ! -n "$FIXED_COMMAND" ] ; then
                    shift
                fi
                start "$@"
            fi
            ;;

        'stop')
            checkUser "" "$COMMAND"
            stopit "0"
            ;;

        'graceful')
            checkUser "" "$COMMAND"
            graceful "0"
            ;;

        'restart')
            checkUser touchlock "$COMMAND"
            if [ ! -n "$FIXED_COMMAND" ] ; then
                shift
            fi
            stopit "0"
            start "$@"
            ;;

        'condrestart')
            checkUser touchlock "$COMMAND"
            if [ ! -n "$FIXED_COMMAND" ] ; then
                shift
            fi
            stopit "1"
            start "$@"
            ;;

        'status')
            checkUser "" "$COMMAND"
            status
            ;;

        'install' | 'remove' | 'uninstall')
            echo "Use \"dpkg-reconfigure i2p\" to configure the initscript."
            exit 1
	    ;;

        'dump')
            checkUser "" "$COMMAND"
            dump
            ;;

        'start_msg')
            # Internal command called by launchd on HP-UX.
            checkUser "" "$COMMAND"
            startmsg
            ;;

        'stop_msg')
            # Internal command called by launchd on HP-UX.
            checkUser "" "$COMMAND"
            stopmsg
            ;;

        'launchdinternal')
            # Internal command called by launchd on Max OSX.
            # We do not want to call checkUser here as it is handled in the launchd plist file.  Doing it here would confuse launchd.
            if [ ! -n "$FIXED_COMMAND" ] ; then
                shift
            fi
            launchdinternal "$@"
            ;;

        *)
            showUsage "$COMMAND"
            ;;
    esac
}

docommand "$@"

exit 0

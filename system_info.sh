#!/bin/bash

# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
# 
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# system_info
# Get information about the running OS
# 2015-11-04 / Peter Möller
# Version 0.1.1
# Latest edit: 2016-12-28

# Aim for the script:
# To present basic information regarding the OS you are running
# The listing should not be more than one screen full
# A *full* report is *not* the intention
# This should answer the question: “where have I landed” when you as a sysadmin
# log in to a new computer
#
# Main targets: OS X and Linux. Would like to cover OpenBSD (because I like the system :-) but that comes later
# 
# What to cover in some more detail:
# - OS Release
#   - information if this is a server release
# - OS architecture & bit count
#   - available updates
# - CPU
# - Memory
# - Disk info (not sure about this one; it may be a lot of information!)
# - Security information:
#   - SIP / SELinux
#   - Firewall (if any of the more common ones are present)
# - Extra information:
#   - uptime
#   - logged in users
#   - if the computer is connected to a directory service (could be interesting, but not sure)
#   - running server processes (also interesting, but may be too much)
# 
# One *may* also think about saving “fingerprints” of interesting binaries in a textfile
# as a manual sequrity/change detection, but that is definetley saved for later


function usage()
{
cat << EOF
Usage: $0 options

This script displays basic information about the OS you are running.

OPTIONS:
  -h      Show this message
  -u      Upgrade the script
EOF
}

# Check for update
function CheckForUpdate() {
  NewScriptAvailable=f
  # First, download the script from the server
  /usr/bin/curl -s -f -e "$ScriptName ver:$VER" -o /tmp/"$ScriptName" http://fileadmin.cs.lth.se/cs/Personal/Peter_Moller/scripts/"$ScriptName" 2>/dev/null
  /usr/bin/curl -s -f -e "$ScriptName ver:$VER" -o /tmp/"$ScriptName".sha1 http://fileadmin.cs.lth.se/cs/Personal/Peter_Moller/scripts/"$ScriptName".sha1 2>/dev/null
  ERR=$?
  # Find, and print, errors from curl (we assume both curl's above generate the same errors, if any)
  if [ "$ERR" -ne 0 ] ; then
  	# Get the appropriate error message from the curl man-page
  	# Start with '       43     Internal error. A function was called with a bad parameter.'
  	# end get it down to: ' 43: Internal error.'
  	ErrorMessage="$(MANWIDTH=500 man curl | egrep -o "^\ *${ERR}\ \ *[^.]*." | perl -pe 's/[0-9](?=\ )/$&:/;s/  */ /g')"
    echo $ErrorMessage
    echo "The file \"$ScriptName\" could not be fetched from \"http://fileadmin.cs.lth.se/cs/Personal/Peter_Moller/scripts/$ScriptName\""
  fi
  # See if the downloaded script checks out 
  # Compare the checksum of the script with the fetched sha1-sum
  # If they diff, something went wrong in the download
  # Then, check if the downloaded script differs from the current
  if [ "$(openssl sha1 /tmp/"$ScriptName" | awk '{ print $2 }')" = "$(less /tmp/"$ScriptName".sha1)" ]; then
    if [ -n "$(diff /tmp/"$ScriptName" "$DirName"/"$ScriptName" 2> /dev/null)" ] ; then
      NewScriptAvailable=t
    fi
  else
    CheckSumError=t
  fi
  }


# Update [and quit]
function UpdateScript() {
  CheckForUpdate
  if [ "$CheckSumError" = "t" ]; then
    echo "Checksum of the fetched \"$ScriptName\" does NOT check out. Look into this! No update performed!"
    exit 1
  fi
  # If new script available, update
  if [ "$NewScriptAvailable" = "t" ]; then
    # But only if the script is writable!
    if [ "$Writable" = "yes" ]; then
      /bin/rm -f "$DirName"/"$ScriptName" 2> /dev/null
      /bin/mv /tmp/"$ScriptName" "$DirName"/"$ScriptName"
      chmod 755 "$DirName"/"$ScriptName"
      /bin/rm /tmp/"$ScriptName".sha1 2>/dev/null
      echo "A new version of \"$ScriptName\" was installed successfully!"
      echo "Script updated. Exiting"

      # Send a signal that someone has updated the script
      # This is only to give me feedback that someone is actually using this. I will *not* use the data in any way nor give it away or sell it!
      /usr/bin/curl -s -f -e "$ScriptName ver:$VER" -o /dev/null http://fileadmin.cs.lth.se/cs/Personal/Peter_Moller/scripts/updated 2>/dev/null
      exit 0
    else
      echo "Script cannot be updated!"
      echo "It is located in \"$DirName\" and is owned by \"$ScriptOwner\""
      echo "You need to sort this out yourself!!"
      echo "Exiting..."
      exit 1
    fi
  else
    echo "You already have the latest version of \"$ScriptName\"!"
    exit 0
  fi
  }


##### Done with functions

##### Set basic variables
fetch_new=f
PMSET="/tmp/pmset.txt"
TempFile1="/tmp/sleep_info_temp1.txt"
TempFile2="/tmp/sleep_info_temp2.txt"
TempFile3="/tmp/sleep_info_temp3.txt"
SysLogTemp="/tmp/syslog_temp"
short="f"
VER="0.1"

# Find where the script resides (so updates update the correct version) -- without trailing slash
DirName="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# What is the name of the script? (without any PATH)
ScriptName="$(basename $0)"
# Is the file writable?
if [ -w "${DirName}"/"${ScriptName}" ]; then
  Writable="yes"
else
  Writable="no"
fi
# Who owns the script?
ScriptOwner="$(ls -ls ${DirName}/${ScriptName} | awk '{print $4":"$5}')"

# (Colors can be found at http://en.wikipedia.org/wiki/ANSI_escape_code, http://graphcomp.com/info/specs/ansi_col.html and other sites)
Reset="\e[0m"
ESC="\e["
RES="0"
BoldFace="1"
ItalicFace="3"
UnderlineFace="4"
SlowBlink="5"
BlackBack="40"
RedBack="41"
YellowBack="43"
BlueBack="44"
WhiteBack="47"
BlackFont="30"
RedFont="31"
GreenFont="32"
YellowFont="33"
BlueFont="34"
CyanFont="36"
WhiteFont="37"
Bold="${ESC}${BoldFace}m"

# Reset all colors
BGColor="$RES"
Face="$RES"
FontColor="$RES"

Formatstring="%-18s%-30s"

##### Done setting basic variables


# Read the parameters
while getopts "hu" OPTION
do
    case $OPTION in
        h)  usage
            exit 1;;
        u)  fetch_new=t;;
        *)  usage
            exit;;
    esac
done
# Done with reading parameters

# First: see if we should update the script
[[ "$fetch_new" = "t" ]] && UpdateScript



###########################################
############   BASIC OS-INFO   ############
###########################################

# OS version (either 'Darwin' or 'Linux')
OS="$(uname -s)"
# OS Size ('32' / '64')
OS_size="$(uname -m | sed -e "s/i.86/32/" -e "s/x86_64/64/" -e "s/armv7l/32/")"
# OS Architecture ('x86_64')
OS_arch="$(uname -m | sed -e "s/i386/i686/")"


# Get things that differ

# Linux
if [ -z "${OS/Linux/}" ]; then
	ComputerName="$(uname -n)"
  # ComputerName=vm67.cs.lth.se

	# Find out about SELinux
	[[ -f /etc/selinux/config ]] && Security="SELinux is $(grep "^SELINUX=" /etc/selinux/config | awk -F= '{print $2}')" || Security="SELinux is not present"
  # Security='SELinux is disabled'

  # Find out which Distro
  # Fist: look at the /etc/*-release files
  Distro="$(less $(ls -1 /etc/mageia-release /etc/centos-release /etc/redhat-release /etc/gentoo-release /etc/fedora-release 2>/dev/null | head -1) 2>/dev/null)"
  # Distro='CentOS Linux release 7.2.1511 (Core) '
  # If no such file, look for /etc/os-release
  if [ -z "$Distro" ]; then
    [[ -f /etc/os-release ]] && Distro="$(less /etc/os-release | grep PRETTY_NAME | cut -d\" -f2)"
    # Distro='CentOS Linux 7 (Core)'
  fi
  # If no such file, look for /etc/lsb-release
  if [ -z "$Distro" ]; then
    [[ -f /etc/lsb-release ]] && Distro="$(less /etc/os-release | grep DISTRIB_DESCRIPTION | cut -d\" -f2)"
  fi
  # If no such file, look for /proc/version
  if [ -z "$Distro" ]; then
    [[ -f /proc/version ]] && Distro="$(less /proc/version | cut -d\( -f1)"
    # Distro='Linux version 3.10.0-327.36.3.el7.x86_64 '
  fi
  # OK, so it an unknown system
  if [ -z "$Distro" ]; then
    Distro="Unknown Linux-distro"
  fi

	# Get kernel version
	KernelVer="$(uname -r | cut -d\. -f1,2 2>/dev/null)"
  # KernelVer='3.10'
	
elif [ -z "${OS/Darwin/}" ]; then
	# OK, so it's Darwin
	Distro="$(sw_vers -productName)"
	DistroVer="$(sw_vers -productVersion)"
	ComputerName="$(networksetup -getcomputername)"
	[[ -x /usr/bin/csrutil ]] && Security="SIP is $(csrutil status | cut -d: -f2 | sed -e 's/^\ //g' -e 's/.$//')" || Security="SIP is not present"
	# Find out if it's a server
	# First step: does the name fromsw_vers include "server"?
	if [ -z "$(echo "$SW_VERS" | grep -i server)" ]; then
		# If not, it may still be a server. Beginning with OS X 10.8 all versions include the command serverinfo:
		serverinfo --software 1>/dev/null
		# Exit code 0 = server; 1 = NOT server
		ServSoft=$?
		if [ $ServSoft -eq 0 ]; then
			# Is it configured?
			serverinfo --configured 1>/dev/null
			ServConfigured=$?
			if [ $ServConfigured -eq 0 ]; then
				OSX_server="$(serverinfo --productname) $(serverinfo --shortversion)"
			else
				OSX_server="$(serverinfo --productname) $(serverinfo --shortversion) - unconfigured"
			fi
		fi
	fi
fi

###########################################
##############   CPU INFO   ###############
###########################################

if [ -z "${OS/Linux/}" ]; then
  CPU="$(less /proc/cpuinfo | grep -i "model name" | cut -d: -f2 | sed 's/ //')"
  # Ex: CPU='Intel(R) Xeon(R) CPU E5-2640 v3 @ 2.60GHz'
elif [ -z "${OS/Darwin/}" ]; then
  CPU="$(sysctl -n machdep.cpu.brand_string)"
  # Ex: CPU='Intel(R) Xeon(R) CPU E5-1650 v2 @ 3.50GHz'
  # Ex: CPU='Intel(R) Core(TM)2 Duo CPU     P7350  @ 2.00GHz'
  NrCPU="$(system_profiler SPHardwareDataType | grep Processors | cut -d: -f2 | sed 's/\ *//')"
  # Ex: NrCPU='1'
fi

###########################################
#############   MEMORY INFO   #############
###########################################

if [ -z "${OS/Linux/}" ]; then
  Memory="$(less /proc/meminfo | grep -i MemTotal | cut -d: -f2 | sed 's/ *//')
  # Ex: Memory='8011588 kB'
  Memory="$(dmidecode --type 6,6 | grep "Installed Size" | grep -v "Not Installed" | cut -d: -f2 | sed 's/ *//')"
  # Ex: Memory='8192 MB (Single-bank Connection)'
  ECC="$(dmidecode --type memory | grep -A1 "Enabled Error Correcting Capabilities" | cut -d: -f2)"
  # Ex: ECC='None'
elif [ -z "${OS/Darwin/}" ]; then
  Memory="$(system_profiler SPHardwareDataType | grep Memory | cut -d: -f2 | sed 's/\ *//')"
  # Ex: Memory='32 GB'
  ECC="$(system_profiler SPHardwareDataType SPMemoryDataType | grep "^\ *ECC:" | cut -d: -f2 | sed 's/ *//')"
  # Ex: ECC='Enabled'
fi


###########################################
##############   DISK INFO   ##############
###########################################

if [ -z "${OS/Linux/}" ]; then
  
elif [ -z "${OS/Darwin/}" ]; then
  
fi


###########################################
############   NETWORK INFO   #############
###########################################

if [ -z "${OS/Linux/}" ]; then
  # This doesn't work reliable
  EnabledInterfaces="$(ip link | egrep "state UP|state UNKNOWN" | grep -v "lo:" | cut -d: -f2 | sed -e 's/^ *//')"
  for i in $EnabledInterfaces
  do
    printf "Interface: ${i}\nAddress:\n$(ip address show $i | egrep -o "^\ *inet[6]? [^\ ]*\ ")\n"
  done
elif [ -z "${OS/Darwin/}" ]; then
  # This is a very short version of the 'network_info'-script
  NIfile="/tmp/NetworkInterfaces_$$.txt"
  networksetup -listnetworkserviceorder | egrep "^\([0-9\*]*\)\ " | sed -e 's/^(//g' -e 's/) /:/' > $NIfile
  printf "Interfaces:\n"
  exec 4<"$NIfile"
  while IFS=: read -u 4 IFNum IFName
  do
    Interface="$(networksetup -listallhardwareports 2>/dev/null | grep -A1 "Hardware Port: $IFName" | tail -1 | awk '{print $2}')"
    # Ex: en0
    MediaSpeed="$(networksetup -getMedia "$IFName" 2>/dev/null | grep "^Active" | cut -d: -f2-)"
    # Ex: "1000baseT" or "autoselect"
    IPaddress="$(networksetup -getinfo "$IFName" 2>/dev/null | grep "^IP address" | cut -d: -f2)"
    # Ex: " 130.235.16.211"
    printf "$IFNum" "$IFName" "$Interface" "${IPaddress# }" "${MediaSpeed}" 
  done
fi

###########################################
############   SECURITY INFO   ############
###########################################

if [ -z "${OS/Linux/}" ]; then
  echo ""
elif [ -z "${OS/Darwin/}" ]; then
  echo ""
fi

###########################################
#############   EXTRA INFO   ##############
###########################################

if [ -z "${OS/Linux/}" ]; then
  echo ""
elif [ -z "${OS/Darwin/}" ]; then
  echo ""
fi



###########################################
############   PRINT RESULT    ############
###########################################

printf "${ESC}${BlackBack};${WhiteFont}mOS info for:${Reset}${ESC}${WhiteBack};${BlackFont}m $ComputerName ${Reset}   ${ESC}${BlackBack};${WhiteFont}mDate & time:${ESC}${WhiteBack};${BlackFont}m $(date +%F", "%R) ${Reset}\n"

printf "$Formatstring\n" "Operating System:" "$Distro $DistroVer $([[ -n "$OSX_server" ]] && echo "($OSX_server)")"
[[ -n "$KernelVer" ]] && printf "$Formatstring\n" "Kernel version:" "$KernelVer"
printf "$Formatstring\n" "Architecture:" "${OS_arch} (${OS_size}-bit)"
printf "$Formatstring\n" "Security:" "$Security"

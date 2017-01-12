#!/bin/bash

# Copyright 2016 Peter Möller
# 
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
# Version 0.2
# Latest edit: 2017-01-02

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
# One *may* also think about saving “fingerprints” of interesting binaries in a text file
# as a manual security/change detection, but that is definitely saved for later

# Overall structure of the script:
# - a number of segment, each dealing with one part of the system (OS, CPU, memory and so on)
# - each part prints it's own info (makes for a better, quicker, printout)
#   The “head” is printed before the work is done, though
# - each part deals with the various OS:es (currently OS X and Linux) separatley, but
#   tries to gather the same info so that one may use a single print phase


function usage()
{
cat << EOF
Usage: $0 options

This script displays basic information about the OS you are running.

OPTIONS:
  -h      Show this message
  -u      Upgrade the script
  -i      Print additional information regarding tools to use
EOF
}

function exists()
{
  command -v "$1" >/dev/null 2>&1
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
VER="0.4"

Info=0

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

OSTempFile="/tmp/.${ScriptName}_OS.$$.txt"
CPUTempFile="/tmp/.${ScriptName}_CPU.$$.txt"
MemTempFile="/tmp/.${ScriptName}_Memory.$$.txt"
DiskTempFile="/tmp/.${ScriptName}_Disk.$$.txt"
NetworkTempFile="/tmp/.${ScriptName}_Network.$$.txt"
SecurityTempFile="/tmp/.${ScriptName}_Security.$$.txt"
GraphicsTempFile="/tmp/.${ScriptName}_Graphics.$$.txt"


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

Formatstring="%-18s%-40s%-30s"
# 1 "123456789012345678"
# 2 "1234567890123456789012345678901234567890"
# 3 "123456789012345678901234567890"
# FormatString is intended for:
# "Head" "Value" "Extra information (-i flag)"
# FormatstringNetwork is intended for the network listing
FormatstringNetwork="%-10s%-22s%-15s%-30s"
# FormatstringDisk is intended for the disk listing
FormatstringDisk="%-18s%-10s%-13s%-15s%-6s%-20s"
# 123456789012345678901234567890123456789012345678901234567890
#          1         1         1         1         1         1
# BSD Name         Size      Medium Type   SMART     TRIM  Bus                 
# disk0            500.3 GB  Solid State   Verified  Yes   SATA/SATA Express   
# FormatstringGraphics is intended for graphics info
FormatstringGraphics="%-28s%-20s"

##### Done setting basic variables

function print_warning()
{
  printf "${ESC}${YellowBack};${BlackFont}mWarning: ${1}${Reset}\n" >&2
}

# Read the parameters
while getopts "hui" OPTION
do
    case $OPTION in
        h)  usage
            exit 1;;
        u)  fetch_new=t;;
        i)  Info=1;;
        *)  usage
            exit;;
    esac
done
# Done with reading parameters

# First: see if we should update the script
[[ "$fetch_new" = "t" ]] && UpdateScript



######################################################################################
##########################    B A S I C   O S - I N F O     ##########################
######################################################################################

# OS version (either 'Darwin' or 'Linux')
# See a comprehensive list of uname results: 
# https://en.wikipedia.org/wiki/Uname
OS="$(uname -s 2>/dev/null)"
# OS Size ('32' / '64')
OS_size="$(uname -m 2>/dev/null | sed -e "s/i.86/32/" -e "s/x86_64/64/" -e "s/armv7l/32/")"
# OS Architecture ('x86_64')
OS_arch="$(uname -m 2>/dev/null | sed -e "s/i386/i686/")"


# Check for functions used
if [ -z "${OS/Linux/}" ]; then
  exists dmidecode || print_warning "Command 'dmidecode' not found: some memory-related information will be unavailable!"
fi
echo ""

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

  # Are we running in a VM environment?
  # First, see if PID 1 is not 'init'
  if [ ! "$(ps -p 1 -o comm 2>/dev/null | grep -v COMMAND)" = "init" ]; then
    if [ -z "${USER/root/}" -o -z "${UID/0/}" ]; then
      VMenv="$(dmidecode -s system-product-name 2>/dev/null)"
      # Ex: VMenv='VMware Virtual Platform'
      if [ -z "$VMenv" ]; then
        VMenv="$(virt-what 2>/dev/null)"
        # Ex: VMenv='vmware'
      fi
    fi
    if [ -z "$VMenv" ]; then
      VMenv="$(dmesg 2>/dev/null | grep -i " Hypervisor detected: " 2>/dev/null | cut -d: -f2 | sed 's/^ *//')"
      # Ex: VMenv='VMware'
    fi
    if [ -z "$VMenv" ]; then
      VMenv="$(if [ -n "$(grep "^flags.*\ hypervisor\ " /proc/cpuinfo)" ]; then echo "VM environment detected"; fi)"
      # Ex: VMenv='VM environment detected'
    fi
  fi


elif [ -z "${OS/Darwin/}" ]; then
  # OK, so it's Darwin
  Distro="$(sw_vers -productName 2>/dev/null)"
  DistroVer="$(sw_vers -productVersion 2>/dev/null)"
  ComputerName="$(networksetup -getcomputername 2>/dev/null)"
  # Get basic Mac info for later usage:
  system_profiler SPHardwareDataType 2>/dev/null > "$OSTempFile"
  # This produces a file like this:
  # Hardware:
  #
  #    Hardware Overview:
  #
  #      Model Name: Mac Pro
  #      Model Identifier: MacPro5,1
  #      Processor Name: 6-Core Intel Xeon
  #      Processor Speed: 2.93 GHz
  #      Number of Processors: 2
  #      Total Number of Cores: 12
  #      L2 Cache (per Core): 256 KB
  #      L3 Cache (per Processor): 12 MB
  #      Memory: 24 GB
  #      Processor Interconnect Speed: 6.4 GT/s
  #      Boot ROM Version: MP51.007F.B03
  #      SMC Version (system): 1.39f11
  #      SMC Version (processor tray): 1.39f11
  #      Serial Number (system): CK0XXXXXXXX
  #      Serial Number (processor tray): J5031XXXXXXXX     
  #      Hardware UUID: XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
  # 
  # Using 'Model Identifier', one can identify a Mac at these sites:
  # MacBook Pro: https://support.apple.com/en-us/HT201300
  # iMac:        https://support.apple.com/en-us/HT201634
  # Mac Pro:     https://support.apple.com/en-us/HT202888
  # Mac mini:    http://www.unionrepair.com/how-to-identify-mac-mini-models/
  
  # What Mac model is it?
  ModelIdentifier="$(egrep "^\s*Model Identifier:" $OSTempFile | cut -d: -f2 | sed 's/^ //')"
  # Get the long name for it
  ModelIdentifierName="$(grep "$ModelIdentifier" "$ScriptName" | cut -d: -f1 | sed 's/#/- /')"
  # If the first three letters of $ModelIdentifier doesn't include 'Mac' och 'iMa', we are probably running inside a VM
  if [ ! "$(echo $ModelIdentifier | cut -c1-5)" = "- Mac" -a ! "$(echo $ModelIdentifier | cut -c1-3)" = "- iMa" ]; then
    VMenv="$ModelIdentifier"
    ModelIdentifier="Virtual Mac"
    ModelIdentifierName=" "
  fi

  # Are we bound to AD?
  # See: https://www.jamf.com/jamf-nation/discussions/7039/how-to-check-if-a-computer-is-actually-bound-to-the-ad for details
  ADDomain="$(dsconfigad -show 2>/dev/null | grep "Active Directory Domain" | cut -d= -f2 | sed 's/^ *//')"
  # Ex: ADDomain='uw.lu.se'
  
  # Find out about Profiles (MCX -- Apples managed profiles)
  if [ -z "${USER/root/}" -o -z "${UID/0/}" ]; then
    # See: http://krypted.com/mac-security/manage-profiles-from-the-command-line-in-os-x-10-9/ for details
    Profiles="$(/usr/bin/profiles -P 2>/dev/null)"
    # Ex: MCX='There are no configuration profiles installed'
    # In fact, I have no machines with MCX on to try...
  fi

  # I would also like to find out about various management services, such as Casper.
  # However, this may quickly be a kludge since there are som many management services!
  # Proceed with caution!

  # Find out if it's a server
  # First step: does the name fromsw_vers include "server"?
  # Find out if it's a server and if it's configured or not
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
        OSX_server="$(serverinfo --productname 2>/dev/null) $(serverinfo --shortversion)"
      else
        OSX_server="$(serverinfo --productname 2>/dev/null) $(serverinfo --shortversion) - unconfigured"
      fi
    fi
  fi
fi

### PRINT THE RESULT
printf "${ESC}${BlackBack};${WhiteFont}mSystem info for:${Reset} ${ESC}${WhiteBack};${BlackFont}m$ComputerName${Reset}   ${ESC}${BlackBack};${WhiteFont}mDate & time:${Reset} ${ESC}${WhiteBack};${BlackFont}m$(date +%F", "%R)${Reset}\n"

printf "\n${ESC}${WhiteBack};${BlackFont};${BoldFace}mOperating System:                                 ${Reset}\n"


printf "$Formatstring\n" "Operating System:" "$Distro $DistroVer $([[ -n "$OSX_server" ]] && echo "($OSX_server)")" ""
[[ -n "$KernelVer" ]] && printf "$Formatstring\n" "Kernel version:" "$KernelVer" ""
printf "$Formatstring\n" "Architecture:" "${OS_arch} (${OS_size}-bit)"
printf "$Formatstring\n" "Virtual env.:" "${VMenv:-No VM environment detected}" ""
if [ $Info -eq 1 -a -z "${OS/Darwin/}" ]; then Information="(Use \"system_profiler SPHardwareDataType\" to see hardware details)"; fi
if [ -n "$ModelIdentifier" ]; then
  printf "$Formatstring\n" "Model Identifier:" "$ModelIdentifier ${ModelIdentifierName:-Unknown Mac-model}" "${Information}"
fi
if [ $Info -eq 1 -a -z "${OS/Darwin/}" ]; then Information="(Use \"dsconfigad -show\" to see AD-connection details)"; fi
printf "$Formatstring\n" "Active Directory:" "${ADDomain:-Not bound}" "${Information}"
if [ $Info -eq 1 -a -z "${OS/Darwin/}" ]; then Information="(Use \"profiles -P\" to see details about installed Profiles)"; fi
printf "$Formatstring\n" "Managed profiles:" "${Profiles:-No information}" "${Information}"


######################################################################################
###############################    C P U   I N F O    ################################
######################################################################################

printf "\n${ESC}${WhiteBack};${BlackFont};${BoldFace}mCPU info:                                         ${Reset}\n"

if [ -z "${OS/Linux/}" ]; then
  # /proc/cpuinfo is used. It consists of a number of specifications like this, each specifying a computational
  # unit (a “real” core or a HyperThreaded “core” of which there usually are two per physical, “real”, core):
  # processor       : 0
  # vendor_id       : GenuineIntel
  # cpu family      : 6
  # model           : 45
  # model name      : Intel(R) Xeon(R) CPU E5-2620 0 @ 2.00GHz
  # stepping        : 7
  # microcode       : 0x70d
  # cpu MHz         : 1200.000
  # cache size      : 15360 KB
  # physical id     : 0
  # siblings        : 12
  # core id         : 0
  # cpu cores       : 6
  # apicid          : 0
  # initial apicid  : 0
  # fpu             : yes
  # fpu_exception   : yes
  # cpuid level     : 13
  # wp              : yes
  # flags           : fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx pdpe1gb rdtscp lm constant_tsc arch_perfmon pebs bts rep_good nopl xtopology nonstop_tsc aperfmperf eagerfpu pni pclmulqdq dtes64 monitor ds_cpl vmx smx est tm2 ssse3 cx16 xtpr pdcm pcid dca sse4_1 sse4_2 x2apic popcnt tsc_deadline_timer aes xsave avx lahf_lm ida arat epb xsaveopt pln pts dtherm tpr_shadow vnmi flexpriority ept vpid
  # bogomips        : 3990.25
  # clflush size    : 64
  # cache_alignment : 64
  # address sizes   : 46 bits physical, 48 bits virtual
  # power management:
  # 
  # Out of this, the following is used:
  # * Model name: name of the CPU
  # * siblings:   number of HyperThreaded cores on the physical CPU
  # * cpu cores:  number of “real” cores on the physical CPU

  CPU="$(less /proc/cpuinfo | grep -i "model name" | cut -d: -f2 | sed 's/ //' | sort -u)"
  # Ex: CPU='Intel(R) Xeon(R) CPU E5-2640 v3 @ 2.60GHz'
  #CoresTotal="$(grep "cpu cores" /proc/cpuinfo | sort -u | cut -d: -f2)"
  NbrCPUs=$(echo "$(grep "^processor" /proc/cpuinfo | wc -l) / $(grep "^siblings" /proc/cpuinfo | sort -u | cut -d: -f2)" | bc)
  NbrCoresEachCPU=$(grep "cpu cores" /proc/cpuinfo | sort -u | cut -d: -f2 | sed 's/^ //')
elif [ -z "${OS/Darwin/}" ]; then
  CPU="$(sysctl -n machdep.cpu.brand_string)"
  # Ex: CPU='Intel(R) Xeon(R) CPU E5-1650 v2 @ 3.50GHz'
  # Ex: CPU='Intel(R) Core(TM)2 Duo CPU     P7350  @ 2.00GHz'
  NbrCPUs=$(grep "Number of Processors:" $OSTempFile | cut -d: -f2 | sed 's/\ *//')
  # Alternate method: NbrCPU="$(sysctl -n hw.packages)"
  CoresTotal=$(grep "Total Number of Cores:" $OSTempFile | cut -d: -f2 | sed 's/\ *//')
  NbrCoresEachCPU=$(echo " $CoresTotal / $NbrCPUs" | bc)
fi

#printf "$Formatstring\n" "CPU:" "${CPU//(R)/®}"
printf "$Formatstring\n" "CPU:" "$(echo $CPU | sed -E -e 's/\(R\)/®/g' -e 's/\(TM\)/™/g')" ""
printf "$Formatstring\n" "Number of CPUs:" "${NbrCPUs}" ""
printf "$Formatstring\n" "Cores/CPU:" "${NbrCoresEachCPU}" ""


######################################################################################
############################    M E M O R Y   I N F O    #############################
######################################################################################

printf "\n${ESC}${WhiteBack};${BlackFont};${BoldFace}mMemory info:                                      ${Reset}\n"

if [ -z "${OS/Linux/}" ]; then
  # This uses /proc/meminfo which is supposed to look like this:
  # MemTotal:       264056956 kB
  # MemFree:        225391912 kB
  # Buffers:          918352 kB
  # Cached:         27491600 kB
  # SwapCached:            0 kB
  # Active:         10859348 kB
  # Inactive:       24936760 kB
  # Active(anon):    7387320 kB
  # Inactive(anon):   513520 kB
  # Active(file):    3472028 kB
  # Inactive(file): 24423240 kB
  # Unevictable:          48 kB
  # Mlocked:              48 kB
  # SwapTotal:       1971196 kB
  # SwapFree:        1971196 kB
  # Dirty:               132 kB
  # Writeback:             0 kB
  # AnonPages:       7386064 kB
  # Mapped:           845992 kB
  # Shmem:            514684 kB
  # Slab:             984336 kB
  # SReclaimable:     829524 kB
  # SUnreclaim:       154812 kB
  # KernelStack:       15192 kB
  # PageTables:        74108 kB
  # NFS_Unstable:          0 kB
  # Bounce:                0 kB
  # WritebackTmp:          0 kB
  # CommitLimit:    133999672 kB
  # Committed_AS:   18338764 kB
  # VmallocTotal:   34359738367 kB
  # VmallocUsed:      776292 kB
  # VmallocChunk:   34224659660 kB
  # HardwareCorrupted:     0 kB
  # AnonHugePages:   5292032 kB
  # HugePages_Total:       0
  # HugePages_Free:        0
  # HugePages_Rsvd:        0
  # HugePages_Surp:        0
  # Hugepagesize:       2048 kB
  # DirectMap4k:      708724 kB
  # DirectMap2M:    18087936 kB
  # DirectMap1G:    251658240 kB
  # 
  
  # Also, 'dmidecode --type 17' is used. This creates a list like this:
  # # dmidecode 2.12
  # SMBIOS 2.6 present.
  # 
  # Handle 0x0040, DMI type 17, 28 bytes
  # Memory Device
  # 	Array Handle: 0x003E
  # 	Error Information Handle: Not Provided
  # 	Total Width: 72 bits
  # 	Data Width: 64 bits
  # 	Size: 16384 MB
  # 	Form Factor: DIMM
  # 	Set: None
  # 	Locator: DIMM_A1
  # 	Bank Locator: NODE 0 CHANNEL 0 DIMM 0
  # 	Type: DDR3
  # 	Type Detail: Synchronous
  # 	Speed: 1600 MHz
  # 	Manufacturer: Samsung         
  # 	Serial Number: 13A941EC  
  # 	Asset Tag: Unknown         
  # 	Part Number: M393B2G70BH0-CK0  
  # 	Rank: 2

  if [ -z "${USER/root/}" -o -z "${UID/0/}" ]; then
    Memory="$(dmidecode --type 6,6 2>/dev/null | grep "Installed Size" | grep -v "Not Installed" | cut -d: -f2 | sed 's/ *//')"
    # Ex: Memory='8192 MB (Single-bank Connection)'
    if [ -z "$Memory" ]; then
      Memory="$(less /proc/meminfo 2>/dev/null | grep -i MemTotal | cut -d: -f2 | sed 's/ *//')"
    # Ex: Memory='8011588 kB'
    fi
    ECC="$(dmidecode --type memory 2>/dev/null | grep -A1 "Enabled Error Correcting Capabilities" | cut -d: -f2)"
    if [ -z "${ECC}" ]; then
      ECC="$(dmidecode --type memory 2>/dev/null | grep "Error Correction Type" | cut -d: -f2 | sed 's/ *//' | sort -u)"
    fi
    if [ -z "${ECC}" ]; then
      ECC='No information provided'
    fi
    # Ex: ECC='None'
    # Number of DIMMs
    NbrDIMMs=$(dmidecode --type 17 2>/dev/null | egrep "^\sSize:" | cut -d: -f2 | wc -l | sed 's/^ //')
    NbrDIMMsInstalled=$(dmidecode --type 17 2>/dev/null | egrep "^\sSize:" | cut -d: -f2 | sed 's/^ //' | grep -i "[0-9]" | wc -l | sed 's/^ //')
    MemorySpeed="$(dmidecode --type 17 2>/dev/null | egrep "^\sSpeed:" | cut -d: -f2 | sort -u | sed 's/^ //' | grep -v 'Unknown')"
    MemoryType="$(dmidecode --type 17 2>/dev/null | egrep "^\sType:" | cut -d: -f2 | sort -u | sed 's/^ //' | grep -v 'Unknown')"
  else
    print_warning "You are not running as \"root\": memory reporting will not work!"
  fi
elif [ -z "${OS/Darwin/}" ]; then
  # This writes the following to $MemTempFile:
  # Memory:
  # 
  #     Memory Slots:
  # 
  #       ECC: Enabled
  #       Upgradeable Memory: Yes
  # 
  #         DIMM 1:
  # 
  #           Size: 4 GB
  #           Type: DDR3 ECC
  #           Speed: 1333 MHz
  #           Status: OK
  #           Manufacturer: 0x0198
  #           Part Number: 0x393936353532352D3033332E4130304C4620
  #           Serial Number: 0xD614209B
  # And so on with one part per DIMM
  # The line with the DIMM spec may also look like this:
  #         BANK 0/DIMM0:
  # or
  #         DIMM Riser B/DIMM 2:
  # An empty slot is marked with:
  #           Size: Empty

  Memory="$(grep Memory $OSTempFile | cut -d: -f2 | sed 's/\ *//')"
  # Ex: Memory='32 GB'
  # Save memory information to file (for performance):
  system_profiler SPMemoryDataType >> $MemTempFile
  MemorySpeed="$(grep "^\ *Speed:" $MemTempFile | sort -u | grep -v Empty | cut -d: -f2 | sed 's/ *//')"
  MemoryType="$(grep "^\ *Type:" $MemTempFile | sort -u | grep -v Empty | cut -d: -f2 | sed 's/ *//')"
  ECC="$(grep "^\ *ECC:" $MemTempFile | cut -d: -f2 | sed 's/ *//')"
  # Ex: ECC='Enabled'
  NbrDIMMs=$(egrep "DIMM.*:" $MemTempFile | wc -l | sed 's/^ *//')
  NbrDIMMsInstalled=$(egrep "Size:" $MemTempFile | cut -d: -f2 | sed 's/^ //' | grep -i "[0-9]" | wc -l | sed 's/^ *//')
fi

printf "$Formatstring\n" "Memory size:" "${Memory} (ECC: $ECC)" ""
printf "$Formatstring\n" "Memory type:" "${MemoryType:-No information available}" ""
printf "$Formatstring\n" "Memory Speed:" "${MemorySpeed:-No information available}" ""
printf "$Formatstring\n" "Number of DIMMs:" "${NbrDIMMs:-No information available} (${NbrDIMMsInstalled} filled)" ""


######################################################################################
#############################     D I S K   I N F O     ##############################
######################################################################################

printf "\n${ESC}${WhiteBack};${BlackFont};${BoldFace}mDisk info:                                        ${Reset}\n"

if [ -z "${OS/Linux/}" ]; then
  echo ""
elif [ -z "${OS/Darwin/}" ]; then
  system_profiler -detailLevel mini SPUSBDataType SPSerialATADataType SPSASDataType 2>/dev/null | egrep ":$|BSD Name:|Medium Type:|Physical Interconnect:|S.M.A.R.T. status:|TRIM Support:" > $DiskTempFile
  # This will produce a list of disks, like this:
  # USB:
  #  USB 3.0 Bus:
  #      USB3.0 Hub             :
  #          My Book 1144:
  #            Media:
  #              My Book 1144:
  #                BSD Name: disk1
  #      BRCM20702 Hub:
  #          Bluetooth USB Host Controller:
  #      FaceTime HD Camera (Built-in):
  #      Apple USB SuperDrive:
  #      USB2.0 Hub             :
  #          USB Mouse:
  #          Keyboard Hub:
  #              Apple Keyboard:
  #      EPSON Epson Stylus SX440 Series:
  # SATA/SATA Express:
  #     Apple SSD Controller:
  #       Physical Interconnect: PCI
  #         APPLE SSD SM0512F:
  #           BSD Name: disk0
  #           Medium Type: Solid State
  #           TRIM Support: Yes
  #           S.M.A.R.T. status: Verified
  #     Intel 8 Series Chipset:
  # ----
  # SAS:
  #     SAS Domain 0:
  #         SCSI Target Device @ 0:
  #             SCSI Logical Unit @ 0:
  #               BSD Name: disk3
  #               S.M.A.R.T. status: Not Supported
  #         SCSI Target Device @ 127:
  #             SCSI Logical Unit @ 0:
  # ----
  # SATA/SATA Express:
  #     Intel 6 Series Chipset:
  #       Physical Interconnect: SATA
  #         WDC WD5000BTKT-40MD3T0:
  #           BSD Name: disk0
  #           Medium Type: Rotational
  #           S.M.A.R.T. status: Verified
  #     Intel 6 Series Chipset:
  #       Physical Interconnect: SATA
  #         WDC WD5000BTKT-40MD3T0:
  #           BSD Name: disk1
  #           Medium Type: Rotational
  #           S.M.A.R.T. status: Verified
  
  # Print head of disk list
  printf "${ESC}${UnderlineFace}m${FormatstringDisk}${Reset}\n" "BSD Name"  "Size" "Medium Type" "S.M.A.R.T." "TRIM" "Bus"
  # Iterate through the list of disks:
  for i in $(diskutil list 2>/dev/null | egrep "^\/dev" | sed 's;/dev/;;' | egrep -v "virtual|disk image" | awk '{print $1}')
  do
    # First: it may be a Core Storage volume (FileVault2 or the like)
    if [ -z "$(grep $i $DiskTempFile)" ]; then
      # Look for 'Logical Volume'
      if [ -n "$(diskutil cs list | grep -B2 $i | grep "Logical Volume")" ]; then
        Bus=""
        SMART=""
        MediumType="Core Storage"
        TRIM=""
        Size="$(diskutil list | grep -v "/dev/$i" | grep "${i}$" | cut -c58-67)"
      fi
    else
      Bus="$(egrep "^[A-Z].*:$| $i" $DiskTempFile | grep -B1 $i | head -1 | cut -d: -f1)"
      # Ex: Bus='SATA/SATA Express'
      SMART="$(egrep -B3 -A3 "$i" $DiskTempFile | grep "S.M.A.R.T. status:" | cut -d: -f2 | sed 's/^ //')"
      # Ex: SMART='Verified'
      TRIM="$(egrep -B3 -A3 "$i" $DiskTempFile | grep "TRIM Support:" | cut -d: -f2 | sed 's/^ //')"
      # Ex: TRIM='Yes'
      MediumType="$(egrep -B3 -A3 "$i" $DiskTempFile | grep "Medium Type:" | cut -d: -f2 | sed 's/^ //')"
      # Ex: MediumType='Solid State'
      Size="$(diskutil list | grep -v "/dev/$i" | grep "${i}$" | awk '{print $3" "$4}' | sed 's/*//')"
      # Ex: Size='500.3 GB'
    fi
    printf "$FormatstringDisk\n" "$i" "$Size" "${MediumType:---}" "${SMART:---}" "${TRIM:---}" "$Bus"
  done
  [[ $Info -eq 1 ]] &&  echo "(Use \"diskutil\" and \"system_profiler -detailLevel mini SPUSBDataType SPSerialATADataType SPSASDataType\" to see details about your disks)"
fi


######################################################################################
###########################    N E T W O R K   I N F O    ############################
######################################################################################

printf "\n${ESC}${WhiteBack};${BlackFont};${BoldFace}mNetwork info:                                     ${Reset}\n"

#printf "Active interfaces:\n"
printf "${ESC}${UnderlineFace}m$FormatstringNetwork${Reset}\n" "Interface" "Interface name" "IP-address" "Media Speed"

if [ -z "${OS/Linux/}" ]; then
  # This doesn't work reliable
  EnabledInterfaces="$(ip link 2>/dev/null | egrep "state UP|state UNKNOWN" | grep -v "lo:" | cut -d: -f2 | sed -e 's/^ *//')"
  for i in $EnabledInterfaces
  do
    printf "  Interface: \"${i}\" has addresses:\n$(ip address show $i | egrep -o "^\ *inet[6]? [^\ ]*\ ")\n"
  done
elif [ -z "${OS/Darwin/}" ]; then
  # This is a very short version of the 'network_info'-script
  networksetup -listnetworkserviceorder 2>/dev/null | egrep "^\([0-9\*]*\)\ " | sed -e 's/^(//g' -e 's/) /:/' > $NetworkTempFile
  exec 4<"$NetworkTempFile"
  while IFS=: read -u 4 IFNum IFName
  do
    Interface="$(networksetup -listallhardwareports 2>/dev/null | grep -A1 "Hardware Port: $IFName" | tail -1 | awk '{print $2}' | sed -e 's/^ *//')"
    # Ex: en0
    MediaSpeed="$(networksetup -getMedia "$IFName" 2>/dev/null | grep "^Active" | cut -d: -f2- | sed -e 's/^ *//')"
    # Ex: "1000baseT" or "autoselect"
    IPaddress="$(networksetup -getinfo "$IFName" 2>/dev/null | grep "^IP address" | cut -d: -f2 | sed -e 's/^ *//')"
    # Ex: " 130.235.16.211"
    if [ -n "$MediaSpeed" -a ! "$MediaSpeed" = " none" -a -n "$IPaddress" ]; then
      #echo "  Interface: \"$Interface\"  Name: \"$IFName\"  IP-address: \"${IPaddress# }\"  Media Speed: \"${MediaSpeed}\"" 
      printf "$FormatstringNetwork\n" "$Interface" "$IFName" "$IPaddress" "$MediaSpeed"
    fi
  done
  [[ $Info -eq 1 ]] &&  echo "(Use \"ifconfig\" and \"networksetup\" to see network details)"
fi


######################################################################################
##########################    S E C U R I T Y   I N F O    ###########################
######################################################################################

printf "\n${ESC}${WhiteBack};${BlackFont};${BoldFace}mSecurity info:                                    ${Reset}\n"

if [ -z "${OS/Linux/}" ]; then
  echo ""
elif [ -z "${OS/Darwin/}" ]; then
  
  # Firmware password. This requires root level access
  # Note that this adds some 10 seconds to the execution time
  [[ $Info -eq 1 ]] &&  Information="(use \"setregproptool\" for manipulating the firmware lock)" || Information=""
  if [ -z "${USER/root/}" ]; then
    # But only if there actually *is* a recovery HD
    if [ -n "$(diskutil list 2>/dev/null | grep "Recovery HD")" ]; then
      /usr/sbin/diskutil mount Recovery\ HD 1>/dev/null  2>/dev/null
      printf "Looking for firmware password (this will take a few seconds)..."
      /usr/bin/hdiutil attach /Volumes/Recovery\ HD/com.apple.recovery.boot/BaseSystem.dmg -nobrowse -quiet
      /Volumes/OS\ X\ Base\ System/Applications/Utilities/Firmware\ Password\ Utility.app/Contents/Resources/setregproptool -c
      if [ $? -eq 0 ]; then
        FirmwareLockMsg="Firmware password is set"
      else
        FirmwareLockMsg="Firmware password is NOT set"
      fi
      /usr/sbin/diskutil unmount force /Volumes/Recovery\ HD 1>/dev/null  2>/dev/null
    fi
  else
    FirmwareLockMsg="\"root\" needed for firmware lock status!"
  fi
  printf "${ESC}1K${Reset}"
  printf "${ESC}100D${Reset}"
  printf "$Formatstring\n" "Firmware-lock:" "${FirmwareLockMsg}" "${Information}"

  # ALF -- Application Level Firewall
  [[ $Info -eq 1 ]] &&  Information="(use \"socketfilterfw\" to manipulate Application Level Firewall)" || Information=""
  printf "$Formatstring\n" "ALF:" "$(/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate | cut -d\. -f1 | awk '{print $NF}')" "${Information}"

  # PF firewall
  # To see anything interesting, you need to be root!
  [[ $Info -eq 1 ]] &&  Information="(use \"pfctl\" to manipulate the PF-firewall)" || Information=""
  if [ -z "${USER/root/}" ]; then
    PFMsg="$(pfctl -sa 2>/dev/null | grep ^Status: | awk '{print $2}')"
  else
    PFMsg="\"root\" needed for Firewall status!"
  fi
  printf "$Formatstring\n" "PF-firewall:" "${PFMsg}" "${Information}"

  # SIP
  [[ $Info -eq 1 ]] &&  Information="(use \"csrutil\" to manipulate System Integrity Protection)" || Information=""
  [[ -x /usr/bin/csrutil ]] && Security="$(csrutil status 2>/dev/null | cut -d: -f2 | sed -e 's/^\ //g' -e 's/.$//')" || Security="System Integrity Protection is not present"
  printf "$Formatstring\n" "SIP:" "${Security}" "${Information}"
  
  # GateKeeper
  [[ $Info -eq 1 ]] &&  Information="(use \"spctl\" to manipulate the GateKeeper application launch protection system)" || Information=""
  printf "$Formatstring\n" "GateKeeper:" "$(spctl --status 2>/dev/null | awk '{print $2}')" "${Information}"

    # Little Snitch
  # If it's running, it should be a "/Library/Little Snitch/Little Snitch Daemon.bundle/Contents/MacOS/Little Snitch Daemon" running
  if [ -n "$(pgrep -fl "Little Snitch Daemon")" ]; then
    # LittleSnitchVer is an *awful* kludge, but something went bonkers the “normal” (sed) way...
    LittleSnitchVer="$(defaults read "$(dirname "$(pgrep -fl "Little Snitch Daemon" | sed 's/^[0-9]* //')" | sed 's/MacOS/Info.plist/')" CFBundleShortVersionString)"
    LittleSnitch="Installed and running (ver: $LittleSnitchVer)"
    [[ $Info -eq 1 ]] &&  Information="(Little Snitch is only manipulated through the GUI)" || Information=""
  else
    LittleSnitch="Not detected"
    [[ $Info -eq 1 ]] &&  Information="(Little Snitch is a third party firewall that you can find at https://www.obdev.at/products/littlesnitch/index.html)" || Information=""
  fi
  printf "$Formatstring\n" "Little Snitch:" "${LittleSnitch}" "${Information}"

fi




######################################################################################
##########################    G R A P H I C S   I N F O    ###########################
######################################################################################

printf "\n${ESC}${WhiteBack};${BlackFont};${BoldFace}mGraphics info:                                    ${Reset}\n"

if [ -z "${OS/Linux/}" ]; then
  echo ""
elif [ -z "${OS/Darwin/}" ]; then
  system_profiler -xml SPDisplaysDataType 2>/dev/null > "$GraphicsTempFile"
  # Get info about Graphics Card
  GraphicsCardData="$(xmllint --xpath '//dict/key[text()="sppci_model" or text()="spdisplays_vram" or text()="sppci_model"]/following-sibling::string[1]' $GraphicsTempFile)"
  # Ex, iMac:        GraphicsCardData='<string>4096 MB</string><string>NVIDIA GeForce GTX 780M</string>'
  # Ex, Mac Pro:     GraphicsCardData='<string>3072 MB</string><string>AMD FirePro D500</string><string>3072 MB</string><string>AMD FirePro D500</string>'
  # Ex, MacBook Pro: GraphicsCardData='<string>Intel HD Graphics 4000</string><string>1024 MB</string><string>NVIDIA GeForce GT 650M</string>'
  # Ex, Mac mini:    GraphicsCardData='<string>Intel Iris</string>'

  # Dig the graphics cards and their memory from $GraphicsTempFile. Replace ' ' with '_' to make the array work
  array=($(xmllint --xpath '//dict/key[text()="sppci_model" or text()="spdisplays_vram" or text()="sppci_model"]/following-sibling::string[1]' $GraphicsTempFile | sed -e 's/ /_/g' -e 's/\<string\>//g' -e 's/\<\/string\>/ /g'))
  # Ex: ${array[@]}='4096_MB NVIDIA_GeForce_GTX_780M'
  # Ex: ${array[@]}='Intel_HD_Graphics_4000 1024_MB NVIDIA_GeForce_GT_650M'
  # Ex: ${array[@]}='3072_MB AMD_FirePro_D500 3072_MB AMD_FirePro_D500'
  # The array consists of:
  # - a single element:   an integrated graphics card name (and no memory info since it's shared)
  # - a pair of elements: amount of VRAM and graphics card name (for “real” GPU:s)
  # Thus we need to traverse the array accordingly

  # Cycle through the array and print it
  printf "${ESC}${UnderlineFace}m${FormatstringGraphics}${Reset}\n" "Graphics Card"  "Graphics memory"
  i=0
  while [ $i -lt $(echo "${#array[@]} / 2 + 1" | bc) ]; do
    if [ -n "$(echo ${array[$i]} | grep -o "^[A-Z]")" ]; then
      # If the pair starts with text (instead of a number), it denotes an integrated graphics card
      printf "$FormatstringGraphics\n" "${array[$i]//_/ }:" "no dedicated graphics memory"
      i=$((i+1))
    else
      # Else it's a “real” GPU with a memory specification
      printf "$FormatstringGraphics\n" "${array[$i+1]//_/ }:" "${array[$i]//_/ }"
      # Increment by teo to get right for the next pair
      i=$((i+2))
    fi
  done
  [[ $Info -eq 1 ]] &&  echo "(use \"system_profiler SPDisplaysDataType\" to get info about graphics cards and displays)"
fi


######################################################################################
#############################    E X T R A   I N F O    ##############################
######################################################################################

if [ -z "${OS/Linux/}" ]; then
  echo ""
elif [ -z "${OS/Darwin/}" ]; then
  echo ""
fi

# Remove the temp file for Mac
rm $OSTempFile 2>/dev/null
rm $CPUTempFile 2>/dev/null
rm $MemTempFile 2>/dev/null
rm $DiskTempFile 2>/dev/null
rm $NetworkTempFile 2>/dev/null
rm $SecurityTempFile 2>/dev/null



######################################################################################
### Listing of Mac models

# Mac mini
#Mac mini (Late 2014):Macmini7,1
#Mac mini (Late 2012):Macmini6,2
#Mac mini (Mid 2011):Macmini5,1
#Mac mini (Mid 2011):Macmini5,2
#Mac mini (Mid 2011):Macmini5,3
#Mac mini (Mid 2010):Macmini4,1
#Mac mini (Late 2009):Macmini3,1
#Mac mini (Early 2009):Macmini3,1

# MacBook Pro, 13"
#MacBook Pro (13-inch, Late 2016, Four Thunderbolt 3 ports):MacBookPro13,2
#MacBook Pro (13-inch, Late 2016, Two Thunderbolt 3 ports):MacBookPro13,1
#MacBook Pro (Retina, 13-inch, Early 2015):MacbookPro12,1 
#MacBook Pro (Retina, 13-inch, Mid 2014):MacBookPro11,1
#MacBook Pro (Retina, 13-inch, Late 2013):MacBookPro11,1
#MacBook Pro (Retina, 13-inch, Early 2013):MacBookPro10,2
#MacBook Pro (Retina, 13-inch, Late 2012):MacBookPro10,2
#MacBook Pro (13-inch, Mid 2012):MacBookPro9,2
#MacBook Pro (13-inch, Late 2011):MacBookPro8,1
#MacBook Pro (13-inch, Early 2011):MacBookPro8,1
#MacBook Pro (13-inch, Mid 2010):MacBookPro7,1
#MacBook Pro (13-inch, Mid 2009):MacBookPro5,5

# MacBook Pro, 15"
#MacBook Pro (15-inch, Late 2016):MacBookPro13,3
#MacBook Pro (Retina, 15-inch, Mid 2015):MacbookPro 11,4
#MacBook Pro (Retina, 15-inch, Mid 2015):MacbookPro 11,5
#MacBook Pro (Retina, 15-inch, Mid 2014 or Late 2013):MacBook Pro11,2
#MacBook Pro (Retina, 15-inch, Mid 2014 or Late 2013):MacBook Pro11,3
#MacBook Pro (Retina, 15-inch, Early 2013 or Mid 2012):MacBookPro10,1
#MacBook Pro (15-inch, Mid 2012):MacBookPro9,1
#MacBook Pro (15-inch, Late 2011 or Early 2011):MacBookPro8,2
#MacBook Pro (15-inch, Mid 2010):MacBookPro6,2
#MacBook Pro (15-inch, Mid 2009):MacBookPro5,3
#MacBook Pro (15-inch, Late 2008):MacBookPro5,1
#MacBook Pro (15-inch, Early 2008):MacBookPro4,1

# MacBook Pro, 17"
#MacBook Pro (17-inch, Late 2011):MacBookPro8,3
#MacBook Pro (17-inch, Early 2011):MacBookPro8,3
#MacBook Pro (17-inch, Mid 2010):MacBookPro6,1
#MacBook Pro (17-inch, Mid or Early 2009):MacBookPro5,2
#MacBook Pro (17-inch, Late 2008):MacBookPro5,1

# iMac
#iMac (Retina 4K, 21.5-inch, Late 2015):iMac16,2
#iMac (21.5-inch, Late 2015):iMac16,1
#iMac (Retina 5K, 27-inch, Late 2015):iMac17,1
#iMac (Retina 5K, 27-inch, Late 2014 or Mid 2015):iMac15,1
#iMac (21.5-inch, Mid 2014):iMac14,4
#iMac (21.5-inch, Late 2013):iMac14,1
#iMac (27-inch, Late 2013):iMac14,2
#iMac (21.5-inch, Late 2012):iMac13,1
#iMac (27-inch, Late 2012):iMac13,2
#iMac (21.5-inch, Mid 2011):iMac12,1
#iMac (27-inch, Mid 2011):iMac12,2
#iMac (21.5-inch, Mid 2010):iMac11,2
#iMac (27-inch, Mid 2010):iMac11,3
#iMac (21.5-inch, Late 2009 or 27-inch, Late 2009):iMac10,1
#iMac (20-inch, Early 2009 or 24-inch, Early 2009):iMac9,1
#iMac (20-inch, Early 2008 or 24-inch, Early 2008):iMac8,1

# Mac Pro
#Mac Pro (Late 2013):MacPro6,1
#Mac Pro (Mid 2012) or Mac Pro (Mid 2010):MacPro5,1
#Mac Pro (Early 2009):MacPro4,1
#Mac Pro (Early 2008):MacPro3,1
#Mac Pro (8-core):MacPro2,1
#Mac Pro:MacPro1,1

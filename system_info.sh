#!/bin/bash

# Copyright 2016 Peter Möller, Pierre Moreau
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
VER="0.9"

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

# Color for the information texts:
InfoColor="${ESC}${GreenFont}m"

Formatstring="%-20s%-40s${InfoColor}%-30s${Reset}"
# FormatString is intended for:
# "Head" "Value" "Extra information (-i flag)"

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
####################    Source the various parts of the script   #####################
######################################################################################
source ${DirName}/_basic_info
source ${DirName}/_cpu_info
source ${DirName}/_memory_info
source ${DirName}/_disk_info
source ${DirName}/_network_info
source ${DirName}/_security_info
source ${DirName}/_graphics_info
source ${DirName}/_extra_info


# Remove the temp files
rm $OSTempFile 2>/dev/null



######################################################################################
### Listing of PCI Vendors (for graphics cards)

#121A:3dfx Interactive Inc
#1002:Advanced Micro Devices, Inc.
#A0A0:Aopen Inc.
#1B21:Asustek - ASMedia Technology Inc.
#1565:Biostar Microtech Intl Corp
#1092:Diamond Computer Systems
#1695:EPoX Computer Co., Ltd.
#10B0:Gainward GmbH
#1458:Giga-Byte Technologies
#17AF:Hightech Information Systems, Ltd.
#8087:Intel
#8086:Intel Corporation
#107D:Leadtek Research
#102B:Matrox Electronic Systems Ltd.
#1462:Micro-Star International Co Ltd
#1414:Microsoft Corporation
#10DE:NVIDIA Corporation
#1569:Palit Microsystems Inc
#5333:S3 Graphics Co., Ltd
#14CD:Universal Scientific Ind.
#15AD:VMware Inc.

######################################################################################
### Listing of Mac models

# Mac mini
# https://support.apple.com/en-us/HT201894
# http://www.unionrepair.com/how-to-identify-mac-mini-models/
# -----------------------------------------------------
#Mac mini (Late 2014):Macmini7,1
#Mac mini (Late 2012):Macmini6,2
#Mac mini (Late 2012):Macmini6,1
#Mac mini (Mid 2011):Macmini5,1
#Mac mini (Mid 2011):Macmini5,2
#Mac mini (Mid 2011):Macmini5,3
#Mac mini (Mid 2010):Macmini4,1
#Mac mini (Late 2009):Macmini3,1
#Mac mini (Early 2009):Macmini3,1

# MacBook Air
# https://support.apple.com/en-us/HT201862
# -----------------------------------------------------
#MacBook Air (13-inch, Early 2015):MacBookAir7,2
#MacBook Air (11-inch, Early 2015):MacBookAir7,1
#MacBook Air (13-inch, Early 2014):MacBookAir6,2
#MacBook Air (11-inch, Early 2014):MacBookAir6,1
#MacBook Air (13-inch, Mid 2013):MacBookAir6,2
#MacBook Air (11-inch, Mid 2013):MacBookAir6,1
#MacBook Air (13-inch, Mid 2012):MacBookAir5,2
#MacBook Air (11-inch, Mid 2012):MacBookAir5,1
#MacBook Air (13-inch, Mid 2011):MacBookAir4,2
#MacBook Air (11-inch, Mid 2011):MacBookAir4,1
#MacBook Air (13-inch, Late 2010):MacBookAir3,2
#MacBook Air (11-inch, Late 2010):MacBookAir3,1
#MacBook Air (Mid 2009):MacBookAir2,1
#MacBook Air (Late 2008):MacBookAir2,1
#MacBook Air:MacBookAir1,1

# MacBook
# https://support.apple.com/en-us/HT201608
# -----------------------------------------------------
#MacBook (Retina, 12-inch, Early 2016):MacBook9,1
#MacBook (Retina, 12-inch, Early 2015):MacBook8,1
#MacBook (13-inch, Mid 2010):MacBook7,1
#MacBook (13-inch, Late 2009):MacBook 6,1
#MacBook (13-inch, Mid 2009):MacBook5,2
#MacBook (13-inch, Early 2009):MacBook5,2
#MacBook (13-inch, Aluminum, Late 2008):MacBook5,1
#MacBook (13-inch, Late 2008):MacBook4,1
#MacBook (13-inch, Early 2008):MacBook4,1
#MacBook (13-inch, Late 2007):MacBook3,1
#MacBook (13-inch, Mid 2007):MacBook2,1
#MacBook (Late 2006):MacBook2,1
#MacBook:MacBook1,1

# MacBook Pro, 13"
# https://support.apple.com/en-us/HT201300
# -----------------------------------------------------
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
# https://support.apple.com/en-us/HT201300
# -----------------------------------------------------
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
# https://support.apple.com/en-us/HT201300
# -----------------------------------------------------
#MacBook Pro (17-inch, Late 2011):MacBookPro8,3
#MacBook Pro (17-inch, Early 2011):MacBookPro8,3
#MacBook Pro (17-inch, Mid 2010):MacBookPro6,1
#MacBook Pro (17-inch, Mid or Early 2009):MacBookPro5,2
#MacBook Pro (17-inch, Late 2008):MacBookPro5,1

# iMac
# https://support.apple.com/en-us/HT201634
# -----------------------------------------------------
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
# https://support.apple.com/en-us/HT202888
# -----------------------------------------------------
#Mac Pro (Late 2013):MacPro6,1
#Mac Pro (Mid 2012) or Mac Pro (Mid 2010):MacPro5,1
#Mac Pro (Early 2009):MacPro4,1
#Mac Pro (Early 2008):MacPro3,1
#Mac Pro (8-core):MacPro2,1
#Mac Pro:MacPro1,1

# Xserve
#Xserve Xeon 2.0/2.66/3.0 "Quad Core" (Late 2006):Xserve1,1
#Xserve Xeon 2.8 "Quad Core" or 2.8/3.0 "Eight Core" (Early 2008):Xserve2,1
#Xserve Xeon Nehalem 2.26 "Quad Core" or 2.26/2.66/2.93 "Eight Core":Xserve3,1
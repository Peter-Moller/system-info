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



##### Set basic variables
fetch_new=f
VER="0.95"

Info=0
# Find where the script resides (so updates update the correct version) -- without trailing slash
DirName="$(dirname ${BASH_SOURCE[0]})"
# What is the name of the script? (without any PATH)
ScriptName="$(basename ${BASH_SOURCE[0]})"
# Is it a link? In that case, get the real DirName
if [ -L "${BASH_SOURCE[0]}" ]; then
  DirName="$(dirname $(readlink ${BASH_SOURCE[0]}))"
fi

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

# Set an error file for the error trap
ErrorFile="system_info-ERROR_$(date +%F"_"%T).txt"

Formatstring="%-20s%-40s${InfoColor}%-30s${Reset}"
# FormatString is intended for:
# "Head" "Value" "Extra information (-i flag)"

##### Done setting basic variables


# Functions

# How should the script be used?
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


# Determine if a command exists
function exists()
{
  command -v "$1" >/dev/null 2>&1
}


# Function to catch an error
function error()
{
  local parent_lineno="$1"
  local message="$2"
  local code="${3:-1}"
  # If there is no error file, give it a basic info about what machine we're on
  if [ ! -f "$ErrorFile" ]; then
    echo "Operating System: $(uname -s)" > "$ErrorFile"
    echo "Computer Name:  $(uname -n)" >> "$ErrorFile"
  fi
  echo "$Section" >> "$ErrorFile"
  if [[ -n "$message" ]] ; then
    echo "Error on or near line ${parent_lineno}: ${message}; exiting with status ${code}" >> "$ErrorFile"
  else
    echo "Error on or near line ${parent_lineno}; exiting with status ${code}" >> "$ErrorFile"
  fi
  # Also, echo environment to the log file (minus all UPPER CASE vars that are considered to be system only)
  echo "Environment:" >> "$ErrorFile"
  ( set -o posix ; set ) | egrep "[a-z]=" | egrep -v "Back=|Font=|Face=|Soft=|Blink=|Reset=|^Formatstring|^Font" >> "$ErrorFile"
  echo "" >> "$ErrorFile"
  #exit "${code}"
}

# When ERR, execute the 'error' function through trap
#trap 'error ${LINENO}' ERR


# Genral print warnings
function print_warning()
{
  printf "${ESC}${YellowBack};${BlackFont}mWarning: ${1}${Reset}\n" >&2
}

# Function to get configs from a Linux machine
function is_kernel_config_set()
{
  if [ ! -z "${OS/Linux/}" ]; then
    return 1
  fi

  [[ $(uname -m 2>/dev/null) == "x86_64" ]] && Arch='amd64'
  #[[ -f '/proc/config.gz' ]] && ConfigPath='/proc/config.gz' || ([[ -f '/proc/config' ]] && ConfigPath='/proc/config' || ([[ -f "/boot/config-${KernelVer}-${Arch}" ]] && ConfigPath="/boot/config-${KernelVer}-${Arch}" || return 1))
  if [[ -f '/proc/config.gz' ]]; then
    ConfigPath='/proc/config.gz'
  elif [[ -f '/proc/config' ]]; then
    ConfigPath='/proc/config'
  elif [[ -f "/boot/config-${KernelVer}-${Arch}" ]]; then
    ConfigPath="/boot/config-${KernelVer}-${Arch}"
  else
    return 1
  fi
  GzFile=$(echo "${ConfigPath}" | grep '.gz')
  [[ ! -z "${GzFile}" ]] && Value="$(zcat ${ConfigPath} 2>/dev/null | grep "^CONFIG_${1}")" || Value="$(cat ${ConfigPath} 2>/dev/null | grep "^CONFIG_${1}")"
  [[ -z "${Value}" ]] && return 1 || return 0
}

##### Done with functions



# Read the parameters
while getopts "hi" OPTION
do
    case $OPTION in
        h)  usage
            exit 1;;
        i)  Info=1;;
        *)  usage
            exit;;
    esac
done
# Done with reading parameters




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

ls /bananer 2>/dev/null

# Remove the temp files
rm $OSTempFile 2>/dev/null

# Last: chech if "$ErrorFile" exists: if so, some error occured and we need to tell the user
if [ -f "$ErrorFile" ]; then
  printf "\n$ESC${RedFont};${BoldFace}mSome error occurred during the run of the script${Reset}\n"
  printf "$ESC${RedFont};${BoldFace}mAn error file, \"$ErrorFile\", har been created${Reset}\n"
  printf "$ESC${RedFont};${BoldFace}mYou may want to communicate it to the authors of the script${Reset}\n"
fi
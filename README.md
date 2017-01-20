# system-info
Script to give overview of an Operating System

Aim for the script:
To present basic information regarding the OS you are running
The listing should not be more than one screen full
A *full* report is *not* the intention
This should answer the question: “where have I landed” when you as a sysadmin log in to a new computer

Main targets: OS X and Linux. Would like to cover OpenBSD (because I like the system :-) and other Unix systems, but that comes later.

What to cover in some detail:

* OS Release
	* information if this is a server release
* OS architecture & bit count
	* available updates
* Virtual environment (if any)
* Connection to Active Directory
* If the computer is managed by any of the major management tools
* CPU
* Memory
* Disk info
* Network info
* Security information:
	* SIP / SELinux
	* Firewall (if any of the more common ones are present)
* Graphics info
* Extra information (currently not implemented):
	* uptime
	* logged in users
	* if the computer is connected to a directory service (could be interesting, but not sure)
	* running server processes (also interesting, but may be too much)

One *may* also think about saving “fingerprints” of interesting binaries in a text file
as a manual security/change detection, but that is definitely saved for later

-----

**Requirements:**

* Generally, the script is written using only standard bash tools available on both macOS and Linux
* However, on Linux, `dmidecode` (http://savannah.nongnu.org/projects/dmidecode/) is used for many things. If you don't have it your distro, memory reporting will be omitted [on Linux]
* If you are not running the script as `root`, the following information will be detected:
	* (Linux): some details about virtual environment (i.e. `dmidecode`)
	* (Linux): memory type, speed and number of DIMMs (i.e. `dmidecode`)
	* (macOS): presence of firmware password
	* (macOS): status of the packetfiler firewall
	* (macOS): whether Profiles are enabled of not

-----

**Options:**

* `-i` gives you information about commands that will allow you to dig deeper yourself :-)

-----


![](system_info (macOS) 2017-01-20.png)

# system-info
Script to give overview of an Operating System

Aim for the script:
To present basic information regarding the OS you are running
The listing should not be more than one screen full
A *full* report is *not* the intention
This should answer the question: “where have I landed” when you as a sysadmin
log in to a new computer

Main targets: OS X and Linux. Would like to cover OpenBSD (because I like the system :-) but that comes later.

What to cover in some more detail:

* OS Release 
	* information if this is a server release 
* OS architecture & bit count 
	* available updates 
* CPU 
* Memory 
* Disk info (not sure about this one; it may be a lot of information!) 
* Network info
* Security information: 
	* SIP / SELinux 
	* Firewall (if any of the more common ones are present) 
* Graphics info
* Extra information: 
	* uptime 
	* logged in users 
	* if the computer is connected to a directory service (could be interesting, but not sure) 
	* running server processes (also interesting, but may be too much) 

One *may* also think about saving “fingerprints” of interesting binaries in a textfile
as a manual sequrity/change detection, but that is definetley saved for later


-----


	System info for: Peter Möllers Mac Pro   Date & time: 2017-01-04, 18:23
	
	Operating System:                                 
	Operating System: Mac OS X 10.12.2                                                      
	Architecture:     x86_64 (64-bit)                                                       
	Model Identifier: MacPro6,1 ("Mac Pro (Late 2013)")                                     
	
	CPU info:                                         
	CPU:              Intel® Xeon® CPU E5-1650 v2 @ 3.50GHz                               
	Number of CPUs:   1                                                                     
	Cores/CPU:        6                                                                     
	
	Memory info:                                      
	Memory size:      32 GB (ECC: Enabled)                                                  
	Memory type:      DDR3 ECC                                                              
	Memory Speed:     1866 MHz                                                              
	Number of DIMMs:  4 (4 filled)                                                          
	
	Disk info:                                        
	BSD Name          Size      Medium Type  SMART     TRIM  Bus                 
	disk0             500.3 GB  Solid State  Verified  Yes   SATA/SATA Express   
	disk1             2.0 TB    --           --        --    USB                 
	
	Network info:                                     
	Active interfaces:
	- Ethernet 1      en0       130.235.16.211 1000baseT <full-duplex flow-control>
	- Wi-Fi           en2       10.0.1.11      autoselect                    
	
	Security info:                                    
	Firmware-lock:    Firmware password is set                                              
	ALF:              disabled                                                              
	PF-firewall:      Disabled                                                              
	SIP:              enabled                                                               
	GateKeeper:       enabled                                                               
	Little Snitch:    Installed and running (ver: 3.7.1)                                    
	
	Graphics info:                                    
	Graphics Card               Graphics memory     
	AMD FirePro D500:           3072 MB             
	AMD FirePro D500:           3072 MB             

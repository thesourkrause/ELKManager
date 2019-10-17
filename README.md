# ELKManager
Powershell Script to Manage Deployment of ELK Agents on Windows Based Systems. 

## Requirements
* Powershell Remoting Enabled
* Access to enumerate active directory containers (for Get-ELKManagedComputerStatus)
* Local Administrator Privileges on managed machines, or ability to start/stop services, write to Program Files, and create/remove services. 
* Valid agents within the current working directory (as subdirectories, e.g. ./winlogbeat/)
* Patience

## Functions
### _Get-ELKManagedComputerStatus_
This function queries the computers in a given container and validates whether the captures the current state of the service and install.

This function returns an array called _AgentInformation_ with three keys: _SystemName,ServiceStatus,Installed_

###### Switches:
* _OrganizationalUnit_ - the full distinquished name you would like to search through (no default. required)
* _Credentials_ - pass through credentials captured with (Get-Credential), (Default, prompt for credentials)
* _Controller_ - the name of the Domain Controller you will connect to, will be removed in the future. (No default, required)
* _Service_ - the name of the agent you are querying for information about (Default, winlogbeat


### Get-



### Examples
##### Example 1
###### Get the WinLogBeat Status, Install Missing Agents, and Restart Stalled Agents
```
#Get Managed Computer WinLogBeat Agent Status
$Status = Get-ELKManagedComputerStatus -OrganizationalUnit "DC=contoso,DC=local" -Controller CONTOSDC01

# Filter those without the agent
$NotInstalled = (Status.SystemName | Where {$_.Installed -eq $false})

# Filter those with the agent not running
$NotRunning = (Status.SystemName | Where {$_.ServiceStatus -eq "Stopped"})

# Install WinLogBeat on computers where it is not installed
Install-ELKAgent -ComputerList $NotInstalled 

# Restart the WinLogBeat agent on computers where the service is stoped
Start-ELKAgent -ComputerList $NotRunning

#Export the complete list for reporting purposes
$Status | Export-CSV "$PWD\AgentStatus-WinLogBeat.csv" -NoTypeInformation

```


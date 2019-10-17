# ELKManager
Powershell Script to Manage Deployment of ELK Agents on Windows Based Systems. 

## Requirements
* Powershell Remoting Enabled
* Access to enumerate active directory containers (for Get-ELKManagedComputerStatus)
* Local Administrator Privileges on managed machines, or ability to start/stop services, write to Program Files, and create/remove services. 
* Valid agents within the current working directory (as subdirectories, e.g. ./winlogbeat/)
* Patience

## Function Outputs
### _Get-ELKManagedComputerStatus_
This function queries the computers in a given container and validates whether the captures the current state of the service and install.

This function returns an array called _AgentInformation_ with three keys: _SystemName,ServiceStatus,Installed_

###### Examples


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


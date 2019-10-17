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

###### Use Cases:

* Piping information to antoher function such as Install-ELKAgent, Start-ELKAgent, etc based off of Installed,ServiceStatus

e.g.

`$Status = Get-ELKManagedComputerStatus -OrganizationalUnit "DC=contoso,DC=local" -Controller CONTOSDC01`

`$NotInstalled = (Status.SystemName | Where {$_.Installed -eq $false})`

`$NotRunning = (Status.SystemName | Where {$_.ServiceStatus -eq "Stopped"})`

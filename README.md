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
* _DomainCredentials_ - pass through credentials captured with (Get-Credential), (Default, prompt for credentials)
* _Controller_ - the name of the Domain Controller you will connect to, will be removed in the future. (No default, required)
* _Service_ - the name of the agent you are querying for information about (Default, winlogbeat


### Start-ELKAgent 
This function restarts the service on the speicified machine(s). You have the ability to select from winlogbeat, metricbeat, and filebeat.

###### Switches:
* _ComputerList_ - the computer names that you wish to restart the agent on, can be one or many
* _DomainCredentials_ - pass through credentials captured with (Get-Credential), (Default, prompt for credentials)
* _Service_ - choose the agent you want to restart, defaults to winlogbeat.

### Stop-ELKAgent 
This function stops the service on the speicified machine(s). You have the ability to select from winlogbeat, metricbeat, and filebeat.

###### Switches:
* _ComputerList_ - the computer names that you wish to stop the agent on, can be one or many
* _DomainCredentials_ - pass through credentials captured with (Get-Credential), (Default, prompt for credentials)
* _Service_ - choose the agent you want to stop, defaults to winlogbeat.

### Install-ELKAgent 
This function installs an agent on the speicified machine(s). You have the ability to select from winlogbeat, metricbeat, and filebeat.

###### Switches:
* _ComputerList_ - the computer names that you wish to install the agent on, can be one or many
* _DomainCredentials_ - pass through credentials captured with (Get-Credential), (Default, prompt for credentials)
* _FilePath_ - specify a different directory for your agents installation files (defaults to current working directory
* _Agent_ - choose the agent you want to install, defaults to winlogbeat.

### Remove-ELKAgent 
This function uninstalls an agent on the speicified machine(s). You have the ability to select from winlogbeat, metricbeat, and filebeat.

###### Switches:
* _ComputerList_ - the computer names that you wish to remove the agent from, can be one or many
* _DomainCredentials_ - pass through credentials captured with (Get-Credential), (Default, prompt for credentials)
* _Agent_ - choose the agent you want to remove, defaults to winlogbeat.


### Update-ELKConfiguration
This function updates the agents yml configuration file and restarts the services. This allows you to make quick changes to the information being logged and collected.

###### Switches:
* _ComputerList_ - the computer names that you wish to update the configuration on, can be one or many
* _DomainCredentials_ - pass through credentials captured with (Get-Credential), (Default, prompt for credentials)
* _Agent_ - choose the agent you want to update, defaults to winlogbeat.
* _Config_ - specify the directory where your <agent-name>.yml file can be found. (Defaults to PWD/Agent-Name/AgentName.yml)


### Update-ELKModule
This function updates the agents loaded modules.Modules are what allows the agents (such as metricbeat) to communicate with advanced services like MSSQL, etc.

###### Switches:
* _ComputerList_ - the computer names that you wish to update the configuration on, can be one or many
* _DomainCredentials_ - pass through credentials captured with (Get-Credential), (Default, prompt for credentials)
* _Agent_ - choose the agent you want to update, defaults to winlogbeat.
* _Module_ - choose the module you would like to update
* _Config_ - specify the directory where your <module-name>.yml file can be found. (Defaults to PWD/Agent-Name/modules/name/modulename.yml)
* _Disable_ - using this switch will disable the specified module. 


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


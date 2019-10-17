$ErrorActionPreference = "Continue"


<#

#>
function Get-ELKManagedComputerStatus{
    Param(
        [Parameter(Mandatory=$true, HelpMessage = "Enter the full DN of the OU or container your would like to search")]
        $OrganizationalUnit,
        [Parameter(HelpMessage = "Bind existing credentials from (Get-Credential)")]
        $DomainCredentials = (Get-Credential),
        [Parameter(Mandatory=$true, HelpMessage = "Enter the Domain Controller Name to connect to")]
        $Controller,
        [Parameter(HelpMessage = "Enter the service name you want to check status of, default is winlogbeat")]
        [ValidateSet('metricbeat','winlogbeat','filebeat')]
        $Service = "winlogbeat"
    )
    $AgentInformation = @()
    $IsActiveDirectoryEnabled = Get-Module -Name ActiveDirectory
    if( -not $IsActiveDirectoryEnabled){
        $ADPSSession = New-PSSession -ComputerName $Controller -Credential $DomainCredentials
        $ManagedSystems = Invoke-Command -Session $ADPSSession -ScriptBlock {
            Param($SearchBase)
            Get-ADComputer -Filter * -SearchBase $SearchBase
         } -ArgumentList $OrganizationalUnit
         $ADPSSession | Remove-PSSession
    }else{
        $ManagedSystems = Get-ADComputer -Filter * -SearchBase $OrganizationalUnit
    }
    $ManagedSystemCount = $ManagedSystems.count
    $Iterations = 0
    foreach($ManagedComputer in $ManagedSystems){
        Write-Progress -Activity "Gathering Service Information for $ManagedSystemCount Machines" -PercentComplete (($Iterations/$ManagedSystemCount)*100)
        $ManagedComputerName = $ManagedComputer.Name
        $ManagedComputerDNSName = $ManagedComputer.DNSHostName
        if((Test-Connection $ManagedComputerDNSName -Count 3 -WarningAction SilentlyContinue -ErrorAction SilentlyContinue).PingSucceeded){
            $Session = New-PSSession -ComputerName $ManagedComputerName -Credential $DomainCredentials -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
            if($Session){
                $ManagedComputerInformation = Invoke-Command -Session $Session -ScriptBlock {(Get-Service $Using:Service -ErrorAction SilentlyContinue)}
                $InstallStatus = Invoke-Command -Session $Session -ScriptBlock {Test-Path "C:\Program Files\$Using:Service" -ErrorAction SilentlyContinue}
                $Session | Remove-PSSession
                $winlogServiceStatus = $ManagedComputerInformation.Status
                if($InstallStatus -eq $false){
                    $winlogServiceStatus = "Not installed"
                }
            }else{
                Write-Warning "Could not connect to $ManagedComputerName for Remote Powershell Session"
                $winlogServiceStatus = "NoPSSession"
                $InstallStatus = "NoPSSession"
            }
            $Information = New-Object -TypeName psobject -Property @{
                SystemName = $ManagedComputerName
                ServiceStatus = $winlogServiceStatus
                Installed = $InstallStatus
            }
            $AgentInformation+=$Information
            
        }else{
            Write-Warning "Unable to contact $ManagedComputerName via ICMP, test not complete."
            $Information = New-Object -TypeName psobject -Property @{
                SystemName = $ManagedComputerName
                ServiceStatus = "NoConnection"
                Installed = "NoConnection"
            }
            $AgentInformation+=$Information
        }
        $Iterations++
    }
    return $AgentInformation | Select SystemName,ServiceStatus,Installed 
}


function Start-ELKAgent{
    Param(
        [Parameter(Mandatory=$true,HelpMessage = "Passthrough the lists of machines to restart the agent on")]
        $ComputerList,
        [Parameter(HelpMessage = "Enter the domain credentials, or credentials with Local admin privileges")]
        $DomainCredentials = (Get-Credential),
        [Parameter(HelpMessage = "Enter the service name you want to start, default is winlogbeat")]
        [ValidateSet('metricbeat','winlogbeat','filebeat')]
        $Service = "winlogbeat"
    )
    if(($ComputerList.Count) -gt 1){
        Foreach($ComputerName in $ComputerList){
            $Session = New-PSSession -ComputerName $ComputerName -Credential $DomainCredentials 
            Invoke-Command -Session $Session -ScriptBlock {
                Get-Service "$Using:Agent" | Start-Service
            }
        }
    }
    else{
        Invoke-Command -ComputerName $ComputerList -Credential $DomainCredentials -ScriptBlock { Get-Service "$Using:Agent" | Start-Service }
    }
}

function Stop-ELKAgent{
    Param(
        [Parameter(Mandatory=$true,HelpMessage = "Passthrough the lists of machines to stop the agent on")]
        $ComputerList,
        [Parameter(HelpMessage = "Enter the domain credentials, or credentials with Local admin privileges")]
        $DomainCredentials = (Get-Credential),
        [Parameter(HelpMessage = "Enter the service name you want to stop, default is winlogbeat")]
        [ValidateSet('metricbeat','winlogbeat','filebeat')]
        $Service = "winlogbeat"
    )
    if(($ComputerList.Count) -gt 1){
        Foreach($ComputerName in $ComputerList){
            $Session = New-PSSession -ComputerName $ComputerName -Credential $DomainCredentials 
            Invoke-Command -Session $Session -ScriptBlock {
                Get-Service "$Using:Agent" | Stop-Service
            }
        }
    }
    else{
        Invoke-Command -ComputerName $ComputerList -Credential $DomainCredentials -ScriptBlock { Get-Service "$Using:Agent" | Stop-Service }
    }
}

function Install-ELKAgent{
    Param(
        [Parameter(Mandatory=$true,HelpMessage = "Passthrough the lists of machines to restart the agent on")]
        $ComputerList,
        [Parameter(HelpMessage = "Enter the domain credentials, or credentials with Local admin privileges")]
        $DomainCredentials = (Get-Credential),
        [Parameter(HelpMessage = "Enter the location of the agent default install, assumes working directory")]
        $FilePath = "$PWD",
        [Parameter(HelpMessage = "Enter the type of agent you would like to install, assumes winlogbeat")]
        [ValidateSet('metricbeat','winlogbeat','filebeat')]
        $Agent = "winlogbeat"
    )
    $FolderPath = "$FilePath\$Agent"
    if(-not (Test-Path $FolderPath)){
        Write-Warning "Unable to locate the agent directory, exiting install"
        Return $false
    }
    $RemoteDestination = "C:\Program Files\$Agent"
    if(($ComputerList.Count) -gt 1){
        Foreach($ComputerName in $ComputerList){
            $Session = New-PSSession -ComputerName $ComputerName -Credential $DomainCredentials
            Copy-Item -Path "$FolderPath\*" -Recurse -Destination $RemoteDestination -ToSession $Session
            Invoke-Command -Session $Session -ScriptBlock {
               Param(
                $WinLogDir
               )
               if (Get-Service $Using:Agent -ErrorAction SilentlyContinue) {
                  $winlogService = Get-WmiObject -Class Win32_Service -Filter "name='$Using:Agent'"
                  $winlogService.StopService()
                  Start-Sleep -s 1
                  $winlogService.delete()
                }
                New-Service -name $Using:Agent `
                  -displayName $Using:Agent `
                  -binaryPathName "`"$WinLogDir\$Using:Agent.exe`" -c `"$WinLogDir\$Using:Agent.yml`" -path.home `"$WinLogDir`" -path.data `"C:\ProgramData\$Using:Agent`" -path.logs `"C:\ProgramData\$Using:Agent\logs`""
                Try{
                    Start-Process -FilePath sc.exe -ArgumentList "config $Using:Agent start=delayed-auto"
                }Catch{
                    Write-Warning "An error occured setting the service to delayed start."
                }
                Try{ 
                    Get-Service "$Using:Agent" | Start-Service
                }Catch{
                    Write-Warning "Unable to start the service."
                }
            } -ArgumentList $RemoteDestination
        }
    }
    else{
        $Session = New-PSSession -ComputerName $ComputerList -Credential $DomainCredentials
        Copy-Item -Path "$FolderPath\*" -Recurse -Destination $RemoteDestination -ToSession $Session
        Invoke-Command -Session $Session -ScriptBlock {
           Param(
            $WinLogDir
           )
           if (Get-Service $Using:Agent -ErrorAction SilentlyContinue) {
              $winlogService = Get-WmiObject -Class Win32_Service -Filter "name='$Using:Agent'"
              $winlogService.StopService()
              Start-Sleep -s 1
              $winlogService.delete()
            }
            New-Service -name $Using:Agent `
              -displayName $Using:Agent `
              -binaryPathName "`"$WinLogDir\$Using:Agent.exe`" -c `"$WinLogDir\$Using:Agent.yml`" -path.home `"$WinLogDir`" -path.data `"C:\ProgramData\$Using:Agent`" -path.logs `"C:\ProgramData\$Using:Agent\logs`""
            Try{
                Start-Process -FilePath sc.exe -ArgumentList "config $Using:Agent start=delayed-auto"
            }Catch{
                Write-Warning "An error occured setting the service to delayed start."
            }
            Try{ 
                Get-Service "$Using:Agent" | Start-Service
            }Catch{
                Write-Warning "Unable to start the service."
            }
        } -ArgumentList $RemoteDestination
    }
}

function Update-ELKConfiguration{}
function Update-ELKModule{}
function Remove-ELKAgent{}
configuration HomeConfig 
{
   param 
   ( 
        [Parameter(Mandatory)]
        [String]$filesUrl,
        [Parameter(Mandatory)]
        [String]$DomainName,
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$Admincreds
    )
  
  Add-Content -Path "C:\Windows\Temp\jah-dsc-log.txt" -Value "[Start] Got FileURL: $filesUrl"
  [System.Management.Automation.PSCredential ]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($Admincreds.UserName)", $Admincreds.Password)
  Import-DscResource -ModuleName xSystemSecurity -Name xIEEsc
  Import-DscResource -ModuleName xComputerManagement -Name xScheduledTask
  Import-DscResource -ModuleName PSDesiredStateConfiguration, cChoco, xTimeZone
  Import-DscResource -ModuleName xWinEventLog

  Node localhost 
  {
    WindowsFeature ADTools
    {
        Ensure = "Present" 
        Name = "RSAT-AD-Tools"
    }
    WindowsFeature ADAdminCenter
    {
        Ensure = "Present" 
        Name = "RSAT-AD-AdminCenter"
    }
    WindowsFeature ADDSTools
    {
        Ensure = "Present" 
        Name = "RSAT-ADDS-Tools"
    }
    WindowsFeature ADPowerShell
    {
        Ensure = "Present" 
        Name = "RSAT-AD-PowerShell"
    }
    WindowsFeature RSATDNS
    {
        Ensure = "Present" 
        Name = "RSAT-DNS-Server"
    }
    WindowsFeature RSATFileServices
    {
        Ensure = "Present" 
        Name = "RSAT-File-Services"
    }
    WindowsFeature GPMC
    {
        Ensure = "Present" 
        Name = "GPMC"
    }
    xIEEsc DisableIEEscAdmin
    {
        IsEnabled = $false
        UserRole  = "Administrators"
    }
    xIEEsc DisableIEEscUser
    {
        IsEnabled = $false
        UserRole  = "Users"
    }
    Group AddLocalAdminsGroup
    {
        GroupName='Administrators'   
        Ensure= 'Present'             
        MembersToInclude= "$DomainName\LocalAdmins"
        Credential = $DomainCreds    
        PsDscRunAsCredential = $DomainCreds
    }
    Script DisableFirewall
    {
        SetScript =  { 
            Add-Content -Path "C:\Windows\Temp\jah-dsc-log.txt" -Value "[DisableFirewall] Running.."
            Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False
        }
        GetScript =  { @{} }
        TestScript = { $false }
    }
    Script DownloadClassFiles
    {
        SetScript =  { 
            $file = $using:filesUrl + 'class.zip'
            Add-Content -Path "C:\Windows\Temp\jah-dsc-log.txt" -Value "[DownloadClassFiles] Downloading $file"
            Invoke-WebRequest -Uri $file -OutFile C:\Windows\Temp\Class.zip
        }
        GetScript =  { @{} }
        TestScript = { 
            Test-Path C:\Windows\Temp\class.zip
         }
    }
    Script DisableServerManager
    {
        SetScript =  { 
            Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask
        }
        GetScript =  { @{} }
        TestScript = { $false }
    }
    Archive UnzipClassFiles
    {
        Ensure = "Present"
        Destination = "C:\Class"
        Path = "C:\Windows\Temp\Class.zip"
        Force = $true
        DependsOn = "[Script]DownloadClassFiles"
    }
    cChocoInstaller installChoco
    {
        InstallDir = "c:\choco"
    }
    cChocoPackageInstaller installChrome
    {
      Name        = "googlechrome"
      DependsOn   = "[cChocoInstaller]installChoco"
      AutoUpgrade = $True
    }
    cChocoPackageInstaller installVSCode
    {
      Name        = "visualstudiocode"
      DependsOn   = "[cChocoInstaller]installChoco"
      AutoUpgrade = $True
    }
    cChocoPackageInstaller installVSCodePowerShell
    {
      Name        = "vscode-powershell"
      DependsOn   = "[cChocoInstaller]installChoco"
      AutoUpgrade = $True
    }
    cChocoPackageInstaller installVSCodeCSharp
    {
      Name        = "vscode-csharp"
      DependsOn   = "[cChocoInstaller]installChoco"
      AutoUpgrade = $True
    }
    cChocoPackageInstaller installPutty
    {
      Name        = "putty.install"
      DependsOn   = "[cChocoInstaller]installChoco"
      AutoUpgrade = $True
    } 
    cChocoPackageInstaller install7zip
    {
      Name        = "7zip.install"
      DependsOn   = "[cChocoInstaller]installChoco"
      AutoUpgrade = $True
    } 
    cChocoPackageInstaller installSysinternals
    {
      Name        = "sysinternals"
      DependsOn   = "[cChocoInstaller]installChoco"
      AutoUpgrade = $True
    }
    cChocoPackageInstaller installFirefox
    {
      Name        = "firefox"
      DependsOn   = "[cChocoInstaller]installChoco"
      AutoUpgrade = $True
    }
    xTimeZone setTimeZone
    {
        IsSingleInstance = 'Yes'
        TimeZone         = 'Central Standard Time'
    }
    xWinEventLog EventLogPowerShellOperational
    {
        LogName            = "Microsoft-Windows-PowerShell/Operational"
        IsEnabled          = $true
        LogMode            = "Circular"
        MaximumSizeInBytes = 600mb
    }
    xWinEventLog EventLogPowerShelAdmin
    {
        LogName            = "Microsoft-Windows-PowerShell/Admin"
        IsEnabled          = $true
        LogMode            = "Circular"
        MaximumSizeInBytes = 600mb
    }
    LocalConfigurationManager 
    {
        ConfigurationMode = 'ApplyOnly'
        RebootNodeIfNeeded = $true
    }
  }
}
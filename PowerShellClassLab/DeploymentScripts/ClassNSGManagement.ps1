function Add-ClassAccessRule {
  [cmdletbinding()]
  param(
    [Parameter(Mandatory=$True)]
    [pscredential]$Credentials,

    [Parameter(Mandatory=$True)]
    [string]$SourceIpAddress,
    
    [int]$Port=3389,
    
    [string]$ResourceGroup="evil.training-master"
  )

  $NetworkSecurityGroups = (
    'evil.training-nsg-northcentralus',
    'evil.training-nsg-southcentralus',
    'evil.training-nsg-centralus',
    'evil.training-nsg-eastus2',
    'evil.training-nsg-westcentralus',
    'evil.training-nsg-westus2'
  )
  # Check if logged in to Azure
  if ((Get-AzureRmContext).Account -eq $null) {
    Connect-AzureRmAccount -Credential $Credentials
  }

  forEach ($nsgName in $NetworkSecurityGroups) {
    Write-Output "[*] Getting NSG: $nsgName"
    try {
      $nsg = Get-AzureRmNetworkSecurityGroup -Name $nsgName -ResourceGroupName $ResourceGroup -OutVariable $null
      $priorties = $nsg.SecurityRules.Priority
      if ($priorties) {
        $priority = $priorties[-1] + 1
      }
      else {
        $priority = 101
      }
      
    }
    catch {
      Write-Warning "Error Getting NSG: $nsgName"
      Write-Output $error[0]
      break
    }

    Write-Output "[*] New rule priority: $priority"
    Write-Output "[*] Adding rule to $nsgName"
    try {
      if ($nsgName -eq 'chat-nsg') {
        $port = 443
        $ruleName = "HTTPS-$Priority"
      }
      else {
        $port = 3389
        $ruleName = "RDP-$Priority"
      }
      Start-Job -ScriptBlock {Add-AzureRmNetworkSecurityRuleConfig -NetworkSecurityGroup $nsg -Name $ruleName -Direction Inbound `
          -Access Allow -SourceAddressPrefix $SourceIPAddress -SourcePortRange '*' -DestinationAddressPrefix '*' `
          -DestinationPortRange $Port -Protocol TCP -Priority $priority | Set-AzureRmNetworkSecurityGroup}
    }
    
    catch {
      Write-Warning "Error adding rule to $nsgName"
      Write-Output $error[0]
    }
  }
}

function Remove-ClassAccessRule {
  [cmdletbinding()]
  param(
    [Parameter(Mandatory=$True)]
    [pscredential]$Credentials,
    [string]$ResourceGroup="evil.training-master"
  )

  $NetworkSecurityGroups = (
    'evil.training-nsg-northcentralus',
    'evil.training-nsg-southcentralus',
    'evil.training-nsg-centralus',
    'evil.training-nsg-eastus2',
    'evil.training-nsg-westcentralus',
    'evil.training-nsg-westus2'
  )
  # Check if logged in to Azure
  if ((Get-AzureRmContext).Account -eq $null) {
    Connect-AzureRmAccount -Credential $Credentials
  }

  forEach ($nsgName in $NetworkSecurityGroups) {
    Write-Output "[*] Getting NSG: $nsgName"
    try {
      $nsg = Get-AzureRmNetworkSecurityGroup -Name $nsgName -ResourceGroupName $ResourceGroup -OutVariable $null
    }
    catch {
      Write-Warning "Error Getting NSG: $nsgName"
      Write-Output $error[0]
      break
    }

    Write-Output "[*] Rules count: $($nsg.SecurityRules.Count)"
    while ($nsg.SecurityRules.Count -gt 0) {
      $rule = $nsg.SecurityRules[0]
      Write-Output "[*] Removing $($rule.Name)"
      try {
        Remove-AzureRmNetworkSecurityRuleConfig -NetworkSecurityGroup $nsg -Name $rule.Name | Out-Null
      }
      catch {
        Write-Warning "Error removing rule from $nsgName"
        Write-Output $error[0]
        break
      }
    }
    Write-Output "[*] Setting $nsgName"
    try {
      Set-AzureRmNetworkSecurityGroup -NetworkSecurityGroup $nsg | Out-Null
    }
    catch {
      Write-Warning "Error setting $nsgName"
      Write-Output $error[0]
      break
    }
  }
}
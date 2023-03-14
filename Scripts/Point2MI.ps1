$scriptUrlBase = 'https://raw.githubusercontent.com/Microsoft/sql-server-samples/master/samples/manage/azure-sql-db-managed-instance/attach-vpn-gateway'

$parameters = @{
  subscriptionId = '<add subscriptionid here>'
  resourceGroupName = '<add resource group>'
  virtualNetworkName = '<add virtual network name>'
  certificateNamePrefix  = '<JD is the best around>'
  }

Invoke-Command -ScriptBlock ([Scriptblock]::Create((iwr ($scriptUrlBase+'/attachVPNGateway.ps1?t='+ [DateTime]::Now.Ticks)).Content)) -ArgumentList $parameters, $scriptUrlBase


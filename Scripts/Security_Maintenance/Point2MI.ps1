$scriptUrlBase = 'https://raw.githubusercontent.com/Microsoft/sql-server-samples/master/samples/manage/azure-sql-db-managed-instance/attach-vpn-gateway'

$parameters = @{
  subscriptionId = '91653e9e-88e4-4acd-8e97-1b0bd278f57f'
  resourceGroupName = 'jdSQLRG'
  virtualNetworkName = 'vnet-jdsqlmi2'
  certificateNamePrefix  = 'JDSQLMI291653e9e'
  }

Invoke-Command -ScriptBlock ([Scriptblock]::Create((iwr ($scriptUrlBase+'/attachVPNGateway.ps1?t='+ [DateTime]::Now.Ticks)).Content)) -ArgumentList $parameters, $scriptUrlBase


$azureSQLCred = Get-AutomationPSCredential -Name "myazureautomation"
#Enter the name for your server variable
$SQLServerName = Get-AutomationVariable -Name "SqlServer"
#Enter the name for your database variable
$database = Get-AutomationVariable -Name "Database"
    
Write-Output "Azure SQL Database serverFQDN"
 
Write-Output $SQLServerName
 
Write-Output "Azure SQL Database name"
Write-Output $database
 
Write-Output "Your Azure SQL credential name for Automation is:"
Write-Output $azureSQLCred
 
Invoke-Sqlcmd -ServerInstance $SQLServerName -Credential $azureSQLCred -Database $database `
-Query "exec [dbo].[AzureSQLMaintenance] @Operation='all' ,@LogToTable=1" -QueryTimeout 65535 -ConnectionTimeout 60 -Verbose
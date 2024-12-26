param
(
    [Parameter (Mandatory=$false)]
    [object] $WebhookData
)

#Boolean flags
$ScaleOnlyUp = $false
$ScaleOnlyDown = $false
$ScaleUpAndDown = $true

# If there is webhook data coming from an Azure Alert, go into the workflow.
if ($WebhookData){
    # Get the data object from WebhookData
    $WebhookBody = (ConvertFrom-Json -InputObject $WebhookData.RequestBody)

    # Get the info needed to identify the SQL database (depends on the payload schema)
    $schemaId = $WebhookBody.schemaId
    Write-Verbose "schemaId: $schemaId" -Verbose
    if ($schemaId -eq "azureMonitorCommonAlertSchema") {
        # This is the common Metric Alert schema (released March 2019)
        $Essentials = [object] ($WebhookBody.data).essentials
        Write-Output $Essentials
        # Get the first target only as this script doesn't handle multiple
        $alertTargetIdArray = (($Essentials.alertTargetIds)[0]).Split("/")
        $SubId = ($alertTargetIdArray)[2]
        $ResourceGroupName = ($alertTargetIdArray)[4]
        $ResourceType = ($alertTargetIdArray)[6] + "/" + ($alertTargetIdArray)[7]
        $ServerName = ($alertTargetIdArray)[8]
        $DatabaseName = ($alertTargetIdArray)[-1]
        $status = $Essentials.monitorCondition
    }
    else{
        # Schema not supported
        Write-Error "The alert data schema - $schemaId - is not supported."
    }

    # Ensures you do not inherit an AzContext in your runbook
    Disable-AzContextAutosave -Scope Process | Out-Null

    # Connect using a Managed Service Identity
    try {
            $AzureContext = (Connect-AzAccount -Identity).context
        }
    catch{
            Write-Output "There is no system-assigned user identity. Aborting."; 
            exit
        }

    # set and store context
    $AzureContext = Set-AzContext -SubscriptionName $AzureContext.Subscription `
        -DefaultProfile $AzureContext

    Write-Output "Using system-assigned managed identity"

    # Because Azure SQL tiers cannot be obtained programatically, we need to hardcode them as below.
    # The 3 arrays below make this runbook support the DTU tier and the provisioned compute tiers, on Generation 4 and 5 and
    # for both General Purpose and Business Critical tiers.

    $DtuTiers = @('Basic','S0','S1','S2','S3','S4','S6','S7','S9','S12','P1','P2','P4','P6','P11','P15')
    $Gen5Cores = @('2','4','6','8','10','12','14','16','18','20','24','32','40','80','128')
        
    # If the alert that triggered the runbook is Activated or Fired, it means we want to autoscale the database.
    # When the alert gets resolved, the runbook will be triggered again but because the status will be Resolved, no autoscaling will happen.
    if (($status -eq "Activated") -or ($status -eq "Fired") -And ($ScaleOnlyUp -or $ScaleUpAndDown))
    {
        Write-Output "resourceType: $ResourceType"
        Write-Output "resourceName: $DatabaseName"
        Write-Output "serverName: $ServerName"
        Write-Output "resourceGroupName: $ResourceGroupName"
        Write-Output "subscriptionId: $SubId"

        # Gets the current database details, from where we'll capture the Edition and the current service objective.
        # With this information, the below if/else will determine the next tier that the database should be scaled to.
        # Example: if DTU database is S6, this script will scale it to S7. This ensures the script continues to scale up the DB in case CPU keeps reaching 100%.

        $currentDatabaseDetails = Get-AzSqlDatabase -ResourceGroupName $ResourceGroupName -DatabaseName $DatabaseName -ServerName $ServerName

        if (($currentDatabaseDetails.Edition -eq "Basic") -Or ($currentDatabaseDetails.Edition -eq "Standard") -Or ($currentDatabaseDetails.Edition -eq "Premium"))
        {
            Write-Output "Database is DTU model."
            if ($currentDatabaseDetails.CurrentServiceObjectiveName -eq "P15") {
                Write-Output "DTU database is already at highest tier (P15). Suggestion is to move to Business Critical vCore model with 32+ vCores."
            } else {
                for ($i=0; $i -lt $DtuTiers.length; $i++) {
                    if ($DtuTiers[$i].equals($currentDatabaseDetails.CurrentServiceObjectiveName)) {
                        Set-AzSqlDatabase -ResourceGroupName $ResourceGroupName -DatabaseName $DatabaseName -ServerName $ServerName -RequestedServiceObjectiveName $DtuTiers[$i+1]
                        New-AzAutomationVariable -AutomationAccountName "jucalder" -Name "PreviousSloValue" -Encrypted $False -Value $currentDatabaseDetails.CurrentServiceObjectiveName -ResourceGroupName $ResourceGroupName
                        break
                    }
                }
            }
        } else {
            Write-Output "Database is vCore model."

            $currentVcores = ""
            $currentTier = $currentDatabaseDetails.CurrentServiceObjectiveName.SubString(0,8)
            $coresArrayToBeUsed = $Gen5Cores
            try {
                $currentVcores = $currentDatabaseDetails.CurrentServiceObjectiveName.SubString(8,3)
            } catch {
                try {
                    $currentVcores = $currentDatabaseDetails.CurrentServiceObjectiveName.SubString(8,2)
                } catch {
                    $currentVcores = $currentDatabaseDetails.CurrentServiceObjectiveName.SubString(8,1)
                }
            }

            if ($currentVcores -eq $coresArrayToBeUsed[$coresArrayToBeUsed.length]) {
                Write-Output "vCore database is already at highest number of cores. Suggestion is to optimize workload."
            } else {
                for ($i=0; $i -lt $coresArrayToBeUsed.length; $i++) {
                    if ($coresArrayToBeUsed[$i] -eq $currentVcores) {
                        $newvCoreCount = $coresArrayToBeUsed[$i+1]
                        Set-AzSqlDatabase -ResourceGroupName $ResourceGroupName -DatabaseName $DatabaseName -ServerName $ServerName -RequestedServiceObjectiveName "$currentTier$newvCoreCount"
                        New-AzAutomationVariable -AutomationAccountName "jucalder" -Name "PreviousSloValue" -Encrypted $False -Value "$currentTier$currentVcores" -ResourceGroupName $ResourceGroupName
                        break
                    }
                }
            }
        }
    } else {
        if ($ScaleOnlyDown -or $ScaleUpAndDown) {
            # The delay below helps in case its desired to NOT scale down the runbook inmediatly
            # after the alert is marked as Resolved (condition is no longer met i.e. CPU is no longer over X%)
            # see more details on general guidelines section of the document.

            Start-Sleep -Seconds 30

            <#$currentDatabaseDetails = Get-AzSqlDatabase -ResourceGroupName $ResourceGroupName -DatabaseName $DatabaseName -ServerName $ServerName

            if (($currentDatabaseDetails.Edition -eq "Basic") -Or ($currentDatabaseDetails.Edition -eq "Standard") -Or ($currentDatabaseDetails.Edition -eq "Premium"))
            {
                Write-Output "Database is DTU model."
                if ($currentDatabaseDetails.CurrentServiceObjectiveName -eq "S0") {
                    Write-Output "DTU database is already at lowest tier."
                } else {
                    for ($i = ($DtuTiers.length - 1); $i -gt 1; $i--) {
                        if ($DtuTiers[$i].equals($currentDatabaseDetails.CurrentServiceObjectiveName)) {
                            Set-AzSqlDatabase -ResourceGroupName $ResourceGroupName -DatabaseName $DatabaseName -ServerName $ServerName -RequestedServiceObjectiveName $DtuTiers[$i-1]
                            break
                        }
                    }
                }
            } else {
                Write-Output "Database is vCore model."

                $currentVcores = ""
                $currentTier = $currentDatabaseDetails.CurrentServiceObjectiveName.SubString(0,8)
                $coresArrayToBeUsed = $Gen5Cores
                
                try {
                    $currentVcores = $currentDatabaseDetails.CurrentServiceObjectiveName.SubString(8,2)
                } catch {
                    $currentVcores = $currentDatabaseDetails.CurrentServiceObjectiveName.SubString(8,1)
                }

                if ($currentVcores -eq $coresArrayToBeUsed[0]) {
                    Write-Output "vCore database is already at lowest number of vCores."
                } else {
                    for ($i = ($Gen5Cores.length - 1); $i -gt 1; $i--) {
                        if ($coresArrayToBeUsed[$i] -eq $currentVcores) {
                            $newvCoreCount = $coresArrayToBeUsed[$i-1]
                            Set-AzSqlDatabase -ResourceGroupName $ResourceGroupName -DatabaseName $DatabaseName -ServerName $ServerName -RequestedServiceObjectiveName "$currentTier$newvCoreCount"
                            break
                        }
                    }
                }
            }#>

            $Variable = Get-AzAutomationVariable -AutomationAccountName "jdAutomation" -Name "PreviousSloValue" -ResourceGroupName $ResourceGroupName
            Set-AzSqlDatabase -ResourceGroupName $ResourceGroupName -DatabaseName $DatabaseName -ServerName $ServerName -RequestedServiceObjectiveName $Variable.value
            Remove-AzAutomationVariable -AutomationAccountName "jdAutomation" -Name "PreviousSloValue" -ResourceGroupName $ResourceGroupName
        }
    }
}


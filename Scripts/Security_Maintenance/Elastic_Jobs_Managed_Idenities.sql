-- Demonstration : Create an Elastic Database Job with Managed Identity

-- Create a JobsDB and PerfResults database
-- The JobsDB must be at least Standard with 20 DTUs (S1 Tier)
-- https://learn.microsoft.com/en-us/azure/azure-sql/database/single-database-create-quickstart?view=azuresql&tabs=azure-portal

-- Create Elastic Agent Service 
-- https://learn.microsoft.com/en-us/azure/azure-sql/database/elastic-jobs-tutorial?view=azuresql

-- Create a firewall rule for the service on the logical server

-- We can write maintenance scripts to perform index and statistic maintenance.
-- This demonstration is using the AzureSQLMaintenance custom stored procedure
-- developed by Microsoft’s Yochanan Rachamim. It is suitable for Azure SQL and
-- compatible with its supported features. 

-- To create and use this stored procedure.
-- Open the following link and copy all the procedure code. (CTRL + A)
-- Open a new query window and connect to your Azure SQL database.
-- Paste the procedure code and Execute.
-- You will need to perform this on each user database.
-- https://raw.githubusercontent.com/yochananrachamim/AzureSQL/master/AzureSQLMaintenance.txt

-- Create a Managed Identity named [SQLAgentService]
-- This is not needed if you are using SQL Authentication,
-- https://learn.microsoft.com/en-us/entra/identity/managed-identities-azure-resources/how-manage-user-assigned-managed-identities?pivots=identity-mi-methods-azp

--Add Managed Identity to Agent Job Service.

-- Create logins in the master database for the Managed Identity
CREATE LOGIN [SQLAgentService] FROM EXTERNAL PROVIDER; 

-- Create a database user in every database where you want to execute the job.
-- Create the database user  [SQLAgentService]
CREATE USER [SQLAgentService] FROM EXTERNAL PROVIDER;
ALTER ROLE db_owner ADD MEMBER [SQLAgentService]

-- Configure a Target Group
-- The job is going to be executed against all the databases in a logical server.
-- We need to create a target group and add a server member to the group.

-- Connect to the JobsDB database
-- Execute the following command to add a new Target Group
EXEC jobs.sp_add_target_group 'ServerGroup1'

-- Execute the following command to add a server target member to the target group.
-- Make sure you change the <Your logical server name> before you execute the script
EXEC jobs.sp_add_target_group_member 'ServerGroup1',
@target_type = 'SqlServer',
@server_name='msopen-sql.database.windows.net' --change logical server name

-- View the recently created target group and target group members
SELECT * FROM jobs.target_groups WHERE target_group_name='ServerGroup1';
SELECT * FROM jobs.target_group_members WHERE target_group_name='ServerGroup1';

-- Add a new job -- Connect to the JobsDB database
-- Execute the following statement to add a new job that will be scheduled for 
-- every 15 minutes to tune indexes and statistics. Do not use 15 minute intervals
-- in a real world scenario.
EXEC jobs.sp_add_job @job_name ='Index_Stats_Maintenance', 
@description='Perform index and statisics maintenance',
@schedule_interval_type='Minutes',
@schedule_interval_count = 5

-- Add a job step -- Connect to the JobsDB database.
-- Make sure to modify the <Your Logical Server Name>.
-- The stored procedure outputs results to a table on each database.
EXEC jobs.sp_add_jobstep
@job_name='Index_Stats_Maintenance',
@command= N'EXECUTE dbo.AzureSQLMaintenance "all", @LogToTable=1;',
@target_group_name='ServerGroup1'

-- Execute the job
-- Open a new query window and connect to the jobdatabase database
-- Execute the following statements to start the job manually
EXEC jobs.sp_start_job 'Index_Stats_Maintenance'

-- Connect to the JobsDB database
-- Execute the following statements to view the execution status for all jobs

-- View top-level execution status for the job named 'Index_Stats_Maintenance'
SELECT * FROM jobs.job_executions 
WHERE job_name = 'Index_Stats_Maintenance' and step_id IS NULL
ORDER BY start_time DESC

-- View error or success messages
-- Error message could occur if a database does not have
-- the AzureSQLMaintenance Stored Procedure.
SELECT last_message FROM jobs.job_executions 
WHERE job_name = 'Index_Stats_Maintenance' and step_name <> 'NULL'

-- View all top-level execution status for all jobs
SELECT * FROM jobs.job_executions WHERE step_id IS NULL
ORDER BY start_time DESC

-- Review index and statistics maintenance results.
-- Switch to the user database that has the AzureSQL Maintenance Store Procedure.
SELECT * FROM [dbo].[AzureSQLMaintenanceLog]

-- Switch back to Jobs database
-- Copy Job_Execution_ID
SELECT * FROM jobs.job_executions 
WHERE is_active = 1
ORDER BY start_time DESC

-- Stop the script from running
-- Paste Job_Execution_ID
EXEC jobs.sp_stop_job '95025816-E4D6-45CB-9E9F-212B36BC789A' -- This ID changes each demonstration.

-- Be sure to return to the Job Agent Service in the Azure Portal to demonstrate
-- Jobs Definitions, Job Executions, and Target Groups.

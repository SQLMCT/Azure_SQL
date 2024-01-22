-- Demonstration 1: Setup Elastic Agent Service, JobsDB and PerfResults database, and Logins for SQL Authencation Accounts. (Managed Identities will be covered in Demonstration 3. 

-- Create a JobsDB and PerfResults database
-- The JobsDB must be at least Standard with 20 DTUs (S1 Tier)
-- https://learn.microsoft.com/en-us/azure/azure-sql/database/single-database-create-quickstart?view=azuresql&tabs=azure-portal

-- Create Elastic Agent Service -- Do not create a Managed Identity yet.
-- https://learn.microsoft.com/en-us/azure/azure-sql/database/elastic-jobs-tutorial?view=azuresql

-- Create a firewall rule for the service on the logical server

-- Create logins in the master database for SQL Server Authenticion
CREATE LOGIN mastercred WITH PASSWORD='ReallyD1ff1cultP@ssw0rd!'
CREATE USER mastercred FROM LOGIN mastercred
CREATE LOGIN jobcred WITH PASSWORD='ReallyD1ff1cultP@ssw0rd!'

-- Create a database user in every database where you want to execute the job.
-- Make sure to run on all user databases on the logical server.
-- Create the database user jobcred
CREATE USER jobcred FROM LOGIN jobcred
ALTER ROLE db_owner ADD MEMBER jobcred

-- Connect to JobsDB database
-- Create a database master key if one does not already exist,
CREATE MASTER KEY ENCRYPTION BY PASSWORD='ReallyD1ff1cultP@ssw0rd!';

-- Stay connected to the JobsDB database
-- Create a database scoped credential for the SQL accounts
-- This is not needed for Managed Identities
CREATE DATABASE SCOPED CREDENTIAL myjobcred WITH IDENTITY = 'jobcred',
    SECRET = 'ReallyD1ff1cultP@ssw0rd!';

-- Stay connected to the JobsDB database
-- Create a database scoped credential to be used by the master database
-- This is not needed for Managed Identities
CREATE DATABASE SCOPED CREDENTIAL mymastercred WITH IDENTITY = 'mastercred',
    SECRET = 'ReallyD1ff1cultP@ssw0rd!'; 

-- Demonstration 2: Create Jobs with SQL Server Authentication

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
@refresh_credential_name='mymastercred', 
@server_name='jdsqlcentral.database.windows.net'

-- View the recently created target group and target group members
SELECT * FROM jobs.target_groups WHERE target_group_name='ServerGroup1';
SELECT * FROM jobs.target_group_members WHERE target_group_name='ServerGroup1';

-- Create a new job -- Connect to the JobsDB database
-- Execute the following statement to add a new job that will be scheduled every minute to collect the performance data of all the databases
EXEC jobs.sp_add_job @job_name ='ResultsJob',
		@description='Collection Performance data from all databases',
@schedule_interval_type='Minutes',
@schedule_interval_count = 5

-- Add a job step -- Connect to the JobsDB database
-- Execute the following statement to add a new job step. 
-- The job step will capture performance data of every database 
-- and store it into a table.

-- Make sure to  modify the <Your Logical Server Name>
-- There is no need to create the ResourceStats table in advance. 
-- If the table doesn’t exist, it will be created automatically.
EXEC jobs.sp_add_jobstep
@job_name='ResultsJob',
@command= N'SELECT DB_NAME() DatabaseName,  $(job_execution_id) AS job_execution_id,end_time,avg_cpu_percent,avg_data_io_percent,avg_log_write_percent,
avg_memory_usage_percent,xtp_storage_percent,max_worker_percent,max_session_percent,dtu_limit int,cpu_limit FROM sys.dm_db_resource_stats 
WHERE end_time > DATEADD(mi, -20, GETDATE());',
@credential_name='myjobcred',
@target_group_name='ServerGroup1',
@output_type='SqlDatabase',
@output_credential_name='myjobcred',
@output_server_name='jdsqlcentral.database.windows.net',
@output_database_name='PerfResults',
@output_table_name='ResourceStats'

-- Connect to the JobsDB database
-- Execute the following statements to start the job manually
EXEC jobs.sp_start_job 'ResultsJob'

-- Connect to the JobsDB database
-- View top-level execution status for the job named ‘ResultsJob’
SELECT * FROM jobs.job_executions 
WHERE job_name = 'ResultsJob' and step_id IS NULL
ORDER BY start_time DESC

-- View error or success messages
SELECT last_message FROM jobs.job_executions 
WHERE job_name = 'ResultsJob' and step_name <> 'NULL'

-- View all top-level execution status for all jobs
SELECT * FROM jobs.job_executions WHERE step_id IS NULL
ORDER BY start_time DESC

-- Switch to PerfResults database
-- Review Resource Output from job steps.
SELECT * FROM [dbo].[ResourceStats]

-- Switch back to JobsDB database
-- View all active executions
-- Copy Job_Execution_ID
SELECT * FROM jobs.job_executions 
WHERE is_active = 1
ORDER BY start_time DESC

-- Stop the script from running
-- Paste Job_Execution_ID
EXEC jobs.sp_stop_job '84FF8771-0F3C-4D48-B59C-48F58BACE9A5'

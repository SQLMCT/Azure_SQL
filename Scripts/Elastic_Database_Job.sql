--Exercise 2: Create an Elastic Database Job
--2.	Create a database master key
--Create a database master key if one does not already exist, using your own password. You can use the statement below
CREATE MASTER KEY ENCRYPTION BY PASSWORD='ReallyD1ff1cultP@ssw0rd!';

--3.	Create a database scoped credential
--Create a database scoped credential. You can use the statement below
CREATE DATABASE SCOPED CREDENTIAL myjobcred WITH IDENTITY = 'jobcred',
    SECRET = 'ReallyD1ff1cultP@ssw0rd!';

--4.	Create a database scoped credential for the master database
--Open a new query window and connect to the jobdatabase database
--Create a database scoped credential. You can use the statement below
CREATE DATABASE SCOPED CREDENTIAL mymastercred WITH IDENTITY = 'mastercred',
    SECRET = 'ReallyD1ff1cultP@ssw0rd!'; 

--5.	Create logins in the master database
--Open a new query window and connect to the master database
--Create the following logins
CREATE LOGIN mastercred WITH PASSWORD='ReallyD1ff1cultP@ssw0rd!'
CREATE USER mastercred FROM LOGIN mastercred
CREATE LOGIN jobcred WITH PASSWORD='ReallyD1ff1cultP@ssw0rd!'

--6.	Create a database user in every database where you want to execute the job
--Open a new query window and connect to the salesdb database
--Create the database user jobcred
CREATE USER jobcred FROM LOGIN jobcred
ALTER ROLE db_owner ADD MEMBER jobcred

--7.	Configure a Target Group
--The job is going to be executed against all the databases in a logical server. We need to create a target group and add a server member to the group.
--Open a new query window and connect to the jobdatabase database
--Execute the following command to add a new Target Group
EXEC jobs.sp_add_target_group 'ServerGroup1'
--Execute the following command to add a server target member to the target group. Make sure you change the <Your logical server name> before you execute the script
EXEC jobs.sp_add_target_group_member
'ServerGroup1',
@target_type = 'SqlServer',
@refresh_credential_name='mymastercred', --credential required to refresh the databases in server
@server_name='jdtestserver.database.windows.net'

--8.	Add a job
--Open a new query window and connect to the jobdatabase database
--Execute the following statement to add a new job that will be schedule every minute to collect the performance data of all the databases
EXEC jobs.sp_add_job @job_name ='ResultsJob', @description='Collection Performance data from all databases',
@schedule_interval_type='Minutes',
@schedule_interval_count=15

--9. Add a job step
--Open a new query window and connect to the jobdatabase database
--Execute the following statement to add a new job step. The job step will capture all the performance data of every database and store it into a table.
--Make sure you modify the <Your Logical Server Name> into the correct server name before you execute the script.
--There is no need to create the ResourceStats table in advance. If the table doesn’t exist, it will be created automatically.
EXEC jobs.sp_add_jobstep
@job_name='ResultsJob',
@command= N'SELECT DB_NAME() DatabaseName,  $(job_execution_id) AS job_execution_id,end_time,avg_cpu_percent,avg_data_io_percent,avg_log_write_percent,
avg_memory_usage_percent,xtp_storage_percent,max_worker_percent,max_session_percent,dtu_limit int,cpu_limit FROM sys.dm_db_resource_stats 
WHERE end_time > DATEADD(mi, -20, GETDATE());',
@credential_name='myjobcred',
@target_group_name='ServerGroup1',
@output_type='SqlDatabase',
@output_credential_name='myjobcred',
@output_server_name='jdtestserver.database.windows.net',
@output_database_name='PerfResults',
@output_table_name='ResourceStats'

--10.	Execute the job
--Open a new query window and connect to the jobdatabase database
--Execute the following statements to start the job manually
EXEC jobs.sp_start_job 'ResultsJob'

--11.	Monitor job execution status
--Open a new query window and connect to the jobdatabase database
--Execute the following statements to view the execution status for all jobs
--Connect to the job database specified when creating the job agent

--View top-level execution status for the job named ‘ResultsJob’
SELECT * FROM jobs.job_executions 
WHERE job_name = 'ResultsJob' and step_id IS NULL
ORDER BY start_time DESC

--View all top-level execution status for all jobs
SELECT * FROM jobs.job_executions WHERE step_id IS NULL
ORDER BY start_time DESC

--View all execution statuses for job named ‘ResultsPoolsJob’
SELECT * FROM jobs.job_executions 
WHERE job_name = 'Results	Job' 
ORDER BY start_time DESC

-- View all active executions
SELECT * FROM jobs.job_executions 
WHERE is_active = 1
ORDER BY start_time DESC




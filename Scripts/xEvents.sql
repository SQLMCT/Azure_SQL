---- Transact-SQL code for Event File target on Azure SQL Database.


--Switch to SalesDB
USE jdsqldb --Error in Azure SQLDB
GO

SET NOCOUNT ON;
GO


----  Step 1.  Establish one little table, and  ---------
----  insert one row of data.


IF EXISTS
    (SELECT * FROM sys.objects
        WHERE type = 'U' and name = 'jdTabEmployee')
BEGIN
    DROP TABLE JDTabEmployee;
END
GO


CREATE TABLE JDTabEmployee
(
    EmployeeGuid         uniqueIdentifier   not null  default newid()  primary key,
    EmployeeId           int                not null  identity(1,1),
    EmployeeKudosCount   int                not null  default 0,
    EmployeeDesc        nvarchar(256)          null
);
GO


INSERT INTO JDTabEmployee ( EmployeeDesc )
    VALUES ( 'Jane Doe' );
GO


------  Step 2.  Create key, and  ------------
------  Create credential (your Azure Storage container must already exist).


IF NOT EXISTS
    (SELECT * FROM sys.symmetric_keys
        WHERE symmetric_key_id = 101)
BEGIN
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = '0C34C960-6621-4682-A123-C7EA08E3FC46' -- Or any newid().
END
GO


IF EXISTS
    (SELECT * FROM sys.database_scoped_credentials
        -- TODO: Assign AzureStorageAccount name, and the associated Container name.
        WHERE name = 'https://xeventstorage.blob.core.windows.net/xevents')
BEGIN
    DROP DATABASE SCOPED CREDENTIAL
        -- TODO: Assign AzureStorageAccount name, and the associated Container name.
        [https://xeventstorage.blob.core.windows.net/xevents] ;
END
GO


CREATE DATABASE SCOPED CREDENTIAL
     [https://xeventstorage.blob.core.windows.net/xevents]
    WITH    IDENTITY = 'SHARED ACCESS SIGNATURE',  -- "SAS" token.
-- Paste in the long SasToken string here for Secret, but exclude any leading '?'.
    SECRET = 'sv=2021-10-04&ss=btqf&srt=sco&st=2023-05-17T14%3A53%3A35Z&se=2023-05-18T14%3A53%3A35Z&sp=rwdxftlacup&sig=YbLUkfHD2NCsYqj4JfCwzLpPDB3Em4a5rs5UVl2D9%2Bk%3D'
    ;
GO


------  Step 3.  Create (define) an event session.  --------
------  The event session has an event with an action,
------  and a has a target.

IF EXISTS
    (SELECT * from sys.database_event_sessions
        WHERE name = 'JDeventsessionname')
BEGIN
    DROP
        EVENT SESSION
            JDeventsessionname
        ON DATABASE;
END
GO


CREATE EVENT SESSION JDeventsessionname
    ON DATABASE

    ADD EVENT
        sqlserver.sql_statement_starting
            (
            ACTION (sqlserver.sql_text)
            --WHERE statement LIKE 'UPDATE JDTabEmployee%'
            )
    ADD TARGET
        package0.event_file
            (
            -- TODO: Assign AzureStorageAccount name, and the associated Container name.
            -- Also, tweak the .xel file name at end, if you like.
            SET filename =
                'https://xeventstorage.blob.core.windows.net/xevents/jdxevents.xel'
            )
    WITH
        (MAX_MEMORY = 10 MB,
        MAX_DISPATCH_LATENCY = 3 SECONDS)
    ;
GO


------  Step 4.  Start the event session.  ----------------
------  Issue the SQL Update statements that will be traced.
------  Then stop the session.

------  Note: If the target fails to attach,
------  the session must be stopped and restarted.

ALTER EVENT SESSION
        JDeventSessionName
    ON DATABASE
    STATE = START;
GO


SELECT 'BEFORE_Updates', EmployeeKudosCount, * FROM JDTabEmployee;

UPDATE JDTabEmployee
    SET EmployeeKudosCount = EmployeeKudosCount + 2
    WHERE EmployeeDesc = 'Jane Doe';

UPDATE JDTabEmployee
    SET EmployeeKudosCount = EmployeeKudosCount + 13
    WHERE EmployeeDesc = 'Jane Doe';

SELECT 'AFTER__Updates', EmployeeKudosCount, * FROM JDTabEmployee;
GO


ALTER
    EVENT SESSION
         JDeventSessionName
    ON DATABASE
    STATE = STOP;
GO


-------------- Step 5.  Select the results. ----------

SELECT
        *, 'CLICK_NEXT_CELL_TO_BROWSE_ITS_RESULTS!' as [CLICK_NEXT_CELL_TO_BROWSE_ITS_RESULTS],
        CAST(event_data AS XML) AS [event_data_XML]  -- TODO: In ssms.exe results grid, double-click this cell!
    FROM
        sys.fn_xe_file_target_read_file
            (
                -- TODO: Fill in Storage Account name, and the associated Container name.
                'https://xeventstorage.blob.core.windows.net/xevents/jdxevents',
                null, null, null
            );
GO


-------------- Step 6.  Clean up. ----------

--DROP
--    EVENT SESSION
--         JDeventSessionName
--    ON DATABASE;
--GO

--DROP DATABASE SCOPED CREDENTIAL
--    -- TODO: Assign AzureStorageAccount name, and the associated Container name.
--    [https://xeventstorage.blob.core.windows.net/xevents]
--    ;
--GO

--DROP TABLE JDTabEmployee;
--GO

--PRINT 'Use PowerShell Remove-AzureStorageAccount to delete your Azure Storage account!';
--GO
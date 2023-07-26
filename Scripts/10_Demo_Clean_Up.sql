-- To clean up demonstration
-- Turn off TDE (Make sure you are back on JDSQL01)
USE master;
GO
ALTER DATABASE AdventureWorks2016 SET ENCRYPTION OFF;
GO
-- Wait a minute for Encryption to turn off
-- Remove Encryption Key from Database 

USE AdventureWorks2016;
GO
DROP DATABASE ENCRYPTION KEY;
GO



--Cleanup
USE MASTER
GO
DROP Certificate BackupCert
DROP Certificate TDECert
DROP Database IF EXISTS ADWorks2
DROP DATABASE IF EXISTS RLS_DEMO

--Make sure to clean up D:\Backups folder
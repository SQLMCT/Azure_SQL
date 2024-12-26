

SELECT *
FROM SalesLT.Customer
WHERE LastName LIKE 'S%' or 1=1


/** SQL Injection Demo
--DROP DATABASE InjectionDemo
**/

CREATE USER Jack WITHOUT LOGIN
CREATE USER Diane WITHOUT LOGIN
GO

--We are going to create a stored procedure that accepts input from the user:
CREATE PROCEDURE sp_demo_injection01 
(@name sysname)
AS
  EXEC ('SELECT * FROM sys.database_principals
		WHERE name = ''' + @name + '''')
GO

--This is how it was intended to be used
DECLARE @var AS sysname
SET @var = 'Diane'
EXEC sp_demo_injection01 @var
GO

--Show database permissions first
--Now we are going to show how this can be abused by an attacker:

DECLARE @var sysname
Set @var = 'Jack''; 
Grant control to [Diane]; 
Print ''Game Over! Diane owned you!'
-- Diane can now control the database!!!
EXEC sp_demo_injection01 @var
GO


--   So how do we prevent this???
-- Clear Control permissions first
CREATE PROC [sp_demo_injection02]
(@name sysname )
AS
  declare @cmd nvarchar(max)
  declare @parameters nvarchar(max)

  set @cmd = N'SELECT * FROM sys.database_principals WHERE name = @name'
  set @parameters = '@name sysname'
  EXEC sp_executesql @cmd, @parameters, @name = @name
GO

--This is how it was intended to be used
DECLARE @var AS sysname
SET @var = 'Jack'
EXEC sp_demo_injection02 @var
GO

--Now we are going to show how this prevents the attack.

DECLARE @var sysname
Set @var = 'Jack''; 
Grant control to [Diane]; 
Print ''Game Over! Diane owned you!'
-- Diane can now control the database!!!
EXEC sp_demo_injection02 @var
GO



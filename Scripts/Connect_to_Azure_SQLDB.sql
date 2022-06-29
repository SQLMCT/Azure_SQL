--1.	Using SQL Login + SQL user (the most common and familiar option)
/*1: Create SQL Login on master database (connect with admin account to master database)*/
CREATE LOGIN MaryLogin WITH PASSWORD = 'P@$$w0rd1';

/*2: Create SQL user on the master database (this is necessary for login attempt to the <default> database, as with Azure SQL you cannot set the DEFAULT_DATABASE property of the login so it always will be [master] database.)*/
CREATE USER MaryUser FROM LOGIN MaryLogin;

ALTER ROLE dbmanager ADD MEMBER MaryUser; 

/*3: Create SQL User on the user database (connect with admin account to user database)*/

CREATE USER MaryUser FROM LOGIN MaryLogin;

/*4. Grant permissions to the user by assign him to a database role*/
ALTER ROLE db_datareader ADD MEMBER MaryUser;

--2.	Using contained database user (SQL User with password, no login is involved)
/*1: Create SQL user with password on the user database (connect with admin account to user database)*/
CREATE USER KennyUser WITH PASSWORD = 'P@$$w0rd1';

/*2: Grant permissions to the user by assign him to a database role*/
ALTER ROLE db_datareader ADD MEMBER KennyUser;

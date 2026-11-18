-- STEP 6 | Run on: sql1 (primary)
-- A database can only join an AG if it is in FULL recovery and has had a full backup
-- (the backup starts the log chain that the AG replicates).
:on error exit
SET NOCOUNT ON;
USE master;

IF DB_ID('SalesDB') IS NULL
BEGIN
    CREATE DATABASE SalesDB;
    ALTER DATABASE SalesDB SET RECOVERY FULL;
END
GO

USE SalesDB;
IF OBJECT_ID('dbo.Orders') IS NULL
BEGIN
    CREATE TABLE dbo.Orders (
        OrderId      int IDENTITY(1,1) PRIMARY KEY,
        CustomerName nvarchar(100) NOT NULL,
        Amount       decimal(10,2) NOT NULL,
        WrittenOn    sysname       NOT NULL DEFAULT (@@SERVERNAME),  -- which replica was primary
        CreatedAt    datetime2(3)  NOT NULL DEFAULT (SYSUTCDATETIME())
    );

    INSERT dbo.Orders (CustomerName, Amount)
    VALUES (N'Alice', 120.50), (N'Bob', 75.00), (N'Chen', 310.99), (N'Dana', 42.10), (N'Emil', 99.95);
END
GO

USE master;
BACKUP DATABASE SalesDB TO DISK = N'/var/opt/mssql/data/SalesDB_full.bak' WITH INIT, COMPRESSION;

IF NOT EXISTS (SELECT 1 FROM sys.availability_databases_cluster WHERE database_name = 'SalesDB')
    ALTER AVAILABILITY GROUP [ag1] ADD DATABASE SalesDB;

PRINT CONCAT(@@SERVERNAME, ': SalesDB added to ag1, automatic seeding started');

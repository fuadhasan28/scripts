-- Query to find table sizes in MSSQL database
-- This query shows the space used by each table, ordered by total space descending

SELECT 
    t.NAME AS TableName,
    s.Name AS SchemaName,
    p.rows AS RowCounts,
    SUM(a.total_pages) * 8 AS TotalSpaceKB, 
    CAST(ROUND(((SUM(a.total_pages) * 8) / 1024.00), 2) AS NUMERIC(36, 2)) AS TotalSpaceMB,
    SUM(a.used_pages) * 8 AS UsedSpaceKB, 
    CAST(ROUND(((SUM(a.used_pages) * 8) / 1024.00), 2) AS NUMERIC(36, 2)) AS UsedSpaceMB,
    (SUM(a.total_pages) - SUM(a.used_pages)) * 8 AS UnusedSpaceKB
FROM 
    sys.tables t
INNER JOIN      
    sys.indexes i ON t.OBJECT_ID = i.object_id
INNER JOIN 
    sys.partitions p ON i.object_id = p.OBJECT_ID AND i.index_id = p.index_id
INNER JOIN 
    sys.allocation_units a ON p.partition_id = a.container_id
LEFT OUTER JOIN 
    sys.schemas s ON t.schema_id = s.schema_id
WHERE 
    t.NAME NOT LIKE 'dt%' 
    AND t.is_ms_shipped = 0
    AND i.OBJECT_ID > 255 
GROUP BY 
    t.Name, s.Name, p.Rows
ORDER BY 
    TotalSpaceMB DESC, t.Name;


Go

-- Query to find database sizes and free space across all databases
-- This query shows the data size, log size, and free space for each database, ordered by total size descending

SELECT 
    DB_NAME(mf.database_id) AS DatabaseName,
    SUM(CASE WHEN mf.type = 0 THEN (mf.size*8)/1024 ELSE 0 END) AS DataSizeMB,
    SUM(CASE WHEN mf.type = 1 THEN (mf.size*8)/1024 ELSE 0 END) AS LogSizeMB,
    SUM(CASE WHEN mf.type = 0 THEN (mf.size*8 - CAST(FILEPROPERTY(mf.name, 'SpaceUsed') AS int)*8)/1024 ELSE 0 END) AS FreeDataSpaceMB
FROM sys.master_files mf
GROUP BY mf.database_id
ORDER BY SUM(CASE WHEN mf.type = 0 THEN (mf.size*8)/1024 ELSE 0 END) + SUM(CASE WHEN mf.type = 1 THEN (mf.size*8)/1024 ELSE 0 END) DESC;

-- Script to shrink transaction log files for a specific database
-- WARNING: Shrinking log files can cause performance issues and fragmentation.
-- It's better to manage logs with regular backups rather than frequent shrinking.
-- Replace 'YourDatabaseName' with the actual database name.

-- Step 1: Check recovery model
SELECT name, recovery_model_desc FROM sys.databases WHERE name = 'YourDatabaseName';

-- Step 2: If recovery model is FULL or BULK_LOGGED, backup the log first
-- BACKUP LOG YourDatabaseName TO DISK = 'C:\Backup\YourDatabaseName_Log.bak';

-- Step 3: Find the log file name
SELECT name AS LogFileName FROM sys.master_files 
WHERE database_id = DB_ID('YourDatabaseName') AND type = 1;

-- Step 4: Shrink the log file (replace 'LogFileName' with the actual name from step 3)
-- DBCC SHRINKFILE (LogFileName, 1024);  -- Target size in MB, adjust as needed

-- Example for DrinkSpot_Stage_470 (assuming log file name is something like DrinkSpot_Stage_470_log)
-- First, check recovery model:
-- SELECT name, recovery_model_desc FROM sys.databases WHERE name = 'DrinkSpot_Stage_470';
-- If FULL, backup: BACKUP LOG DrinkSpot_Stage_470 TO DISK = 'C:\Backup\DrinkSpot_Stage_470_Log.bak';
-- Find log name: SELECT name FROM sys.master_files WHERE database_id = DB_ID('DrinkSpot_Stage_470') AND type = 1;
-- Then shrink: DBCC SHRINKFILE ('DrinkSpot_Stage_470_log', 1024);

-- Dynamic script to force shrink log files by temporarily changing recovery model
-- WARNING: This changes recovery model to SIMPLE, shrinks, then changes back to FULL.
-- This can break log backup chains. Use only if you understand the risks!
-- Adjust the threshold as needed.

DECLARE @DatabaseName NVARCHAR(128);
DECLARE @LogFileName NVARCHAR(128);
DECLARE @Command NVARCHAR(MAX);
DECLARE @OriginalRecovery INT;

-- Cursor to loop through databases with large logs
DECLARE db_cursor CURSOR FOR
SELECT DatabaseName, LogFileName
FROM (
    SELECT database_id, DB_NAME(database_id) AS DatabaseName, SUM((size*8)/1024) AS LogSizeMB
    FROM sys.master_files
    WHERE type = 1
    GROUP BY database_id
    HAVING SUM((size*8)/1024) > 10000  -- Log size > 10GB
) AS db_list
CROSS APPLY (
    SELECT TOP 1 name FROM sys.master_files WHERE database_id = db_list.database_id AND type = 1 ORDER BY file_id
) AS log_file(LogFileName)
ORDER BY LogSizeMB DESC;

OPEN db_cursor;
FETCH NEXT FROM db_cursor INTO @DatabaseName, @LogFileName;

WHILE @@FETCH_STATUS = 0
BEGIN
    PRINT 'Processing database: ' + @DatabaseName;
    
    -- Get current recovery model
    SET @Command = 'SELECT @Recovery = recovery_model FROM sys.databases WHERE name = ''' + @DatabaseName + ''';';
    EXEC sp_executesql @Command, N'@Recovery INT OUTPUT', @OriginalRecovery OUTPUT;
    
    PRINT 'Original recovery model: ' + CAST(@OriginalRecovery AS NVARCHAR(10));
    
    -- Change to SIMPLE if not already
    IF @OriginalRecovery != 3  -- 3 = SIMPLE
    BEGIN
        SET @Command = 'ALTER DATABASE ' + QUOTENAME(@DatabaseName) + ' SET RECOVERY SIMPLE;';
        EXEC(@Command);
        PRINT 'Changed to SIMPLE recovery';
    END
    
    -- Run checkpoint to clear log
    SET @Command = 'USE ' + QUOTENAME(@DatabaseName) + '; CHECKPOINT;';
    EXEC(@Command);
    PRINT 'Checkpoint executed';
    
    -- Shrink the log
    SET @Command = 'USE ' + QUOTENAME(@DatabaseName) + '; DBCC SHRINKFILE (' + QUOTENAME(@LogFileName, '''') + ', 1024);';
    EXEC(@Command);
    PRINT 'Shrink executed';
    
    -- Change back to original recovery model
    IF @OriginalRecovery != 3
    BEGIN
        SET @Command = 'ALTER DATABASE ' + QUOTENAME(@DatabaseName) + ' SET RECOVERY ' + 
                       CASE @OriginalRecovery 
                           WHEN 1 THEN 'FULL'
                           WHEN 2 THEN 'BULK_LOGGED'
                           ELSE 'FULL'
                       END + ';';
        EXEC(@Command);
        PRINT 'Changed back to original recovery model';
    END
    
    PRINT 'Completed processing for: ' + @DatabaseName;
    PRINT '---';
    
    FETCH NEXT FROM db_cursor INTO @DatabaseName, @LogFileName;
END

CLOSE db_cursor;
DEALLOCATE db_cursor;

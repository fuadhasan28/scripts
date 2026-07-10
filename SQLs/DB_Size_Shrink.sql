USE master;
GO

SET NOCOUNT ON;

DECLARE @Execute BIT = 0;                    -- 0 = preview only, 1 = execute
DECLARE @ThresholdMB DECIMAL(18,2) = 1024;   -- only DBs larger than 1 GB
DECLARE @SizeMode VARCHAR(10) = 'TOTAL';     -- TOTAL, DATA, LOG

DECLARE @TruncateCleanupTables BIT = 1;      -- truncate [Log] and [QueuedEmail]
DECLARE @FallbackDeleteIfTruncateFails BIT = 0; -- keep 0 unless you are 100% sure

DECLARE @ShrinkLogFiles BIT = 1;
DECLARE @TargetLogSizeMB INT = 512;

DECLARE @ShrinkDataFiles BIT = 1;
DECLARE @DataFileBufferMB INT = 256;         -- MDF target = used space + this buffer
DECLARE @MinDataFileSizeMB INT = 512;        -- never shrink MDF below this

DECLARE @Targets TABLE
(
    DatabaseName SYSNAME PRIMARY KEY,
    BeforeDataMB DECIMAL(18,2),
    BeforeLogMB DECIMAL(18,2),
    BeforeTotalMB DECIMAL(18,2)
);

DECLARE @Results TABLE
(
    DatabaseName SYSNAME,
    BeforeDataMB DECIMAL(18,2),
    BeforeLogMB DECIMAL(18,2),
    BeforeTotalMB DECIMAL(18,2),
    AfterDataMB DECIMAL(18,2) NULL,
    AfterLogMB DECIMAL(18,2) NULL,
    AfterTotalMB DECIMAL(18,2) NULL,
    SavedMB DECIMAL(18,2) NULL,
    Status NVARCHAR(50),
    Message NVARCHAR(MAX) NULL,
    CompletedAt DATETIME2 DEFAULT SYSDATETIME()
);

------------------------------------------------------------
-- Dynamically select target databases
------------------------------------------------------------

INSERT INTO @Targets
(
    DatabaseName,
    BeforeDataMB,
    BeforeLogMB,
    BeforeTotalMB
)
SELECT
    d.name AS DatabaseName,
    CAST(SUM(CASE WHEN mf.type_desc = 'ROWS' THEN mf.size ELSE 0 END) * 8.0 / 1024 AS DECIMAL(18,2)) AS BeforeDataMB,
    CAST(SUM(CASE WHEN mf.type_desc = 'LOG' THEN mf.size ELSE 0 END) * 8.0 / 1024 AS DECIMAL(18,2)) AS BeforeLogMB,
    CAST(SUM(mf.size) * 8.0 / 1024 AS DECIMAL(18,2)) AS BeforeTotalMB
FROM sys.databases d
JOIN sys.master_files mf
    ON d.database_id = mf.database_id
WHERE d.database_id > 4
  AND d.state_desc = 'ONLINE'
  AND d.is_read_only = 0
  AND d.source_database_id IS NULL
GROUP BY
    d.name
HAVING
    CASE
        WHEN UPPER(@SizeMode) = 'DATA'
            THEN SUM(CASE WHEN mf.type_desc = 'ROWS' THEN mf.size ELSE 0 END)
        WHEN UPPER(@SizeMode) = 'LOG'
            THEN SUM(CASE WHEN mf.type_desc = 'LOG' THEN mf.size ELSE 0 END)
        ELSE SUM(mf.size)
    END * 8.0 / 1024 > @ThresholdMB;

------------------------------------------------------------
-- Preview target databases
------------------------------------------------------------

SELECT
    t.DatabaseName,
    d.recovery_model_desc AS RecoveryModel,
    d.log_reuse_wait_desc AS LogReuseWait,
    t.BeforeDataMB,
    t.BeforeLogMB,
    t.BeforeTotalMB
FROM @Targets t
JOIN sys.databases d
    ON d.name = t.DatabaseName
ORDER BY
    t.BeforeTotalMB DESC;

IF @Execute = 0
BEGIN
    PRINT 'PREVIEW ONLY. Review the databases above. Change @Execute to 1 to execute.';
    RETURN;
END;

------------------------------------------------------------
-- Execute cleanup
------------------------------------------------------------

DECLARE
    @DbName SYSNAME,
    @Sql NVARCHAR(MAX),
    @BeforeDataMB DECIMAL(18,2),
    @BeforeLogMB DECIMAL(18,2),
    @BeforeTotalMB DECIMAL(18,2),
    @AfterDataMB DECIMAL(18,2),
    @AfterLogMB DECIMAL(18,2),
    @AfterTotalMB DECIMAL(18,2),
    @ErrorMessage NVARCHAR(MAX);

DECLARE db_cursor CURSOR LOCAL FAST_FORWARD FOR
SELECT
    DatabaseName,
    BeforeDataMB,
    BeforeLogMB,
    BeforeTotalMB
FROM @Targets
ORDER BY BeforeTotalMB DESC;

OPEN db_cursor;

FETCH NEXT FROM db_cursor
INTO @DbName, @BeforeDataMB, @BeforeLogMB, @BeforeTotalMB;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @AfterDataMB = NULL;
    SET @AfterLogMB = NULL;
    SET @AfterTotalMB = NULL;
    SET @ErrorMessage = NULL;

    BEGIN TRY
        PRINT 'Cleaning database: ' + @DbName;

        SET @Sql = N'
USE master;

ALTER DATABASE ' + QUOTENAME(@DbName) + N' SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
ALTER DATABASE ' + QUOTENAME(@DbName) + N' SET RECOVERY SIMPLE;

USE ' + QUOTENAME(@DbName) + N';

DECLARE
    @Cmd NVARCHAR(MAX),
    @SchemaName SYSNAME,
    @TableName SYSNAME,
    @FullTableName NVARCHAR(600),
    @FileId INT,
    @LogicalFileName SYSNAME,
    @UsedMB INT,
    @TargetSizeMB INT;

------------------------------------------------------------
-- 1. Truncate cleanup tables
------------------------------------------------------------

IF @ParamTruncateCleanupTables = 1
BEGIN
    DECLARE table_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT
        s.name,
        t.name
    FROM sys.tables t
    JOIN sys.schemas s
        ON s.schema_id = t.schema_id
    WHERE t.name IN (N''Log'', N''QueuedEmail'');

    OPEN table_cursor;
    FETCH NEXT FROM table_cursor INTO @SchemaName, @TableName;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @FullTableName = QUOTENAME(@SchemaName) + N''.'' + QUOTENAME(@TableName);

        BEGIN TRY
            SET @Cmd = N''TRUNCATE TABLE '' + @FullTableName + N'';'';
            EXEC sys.sp_executesql @Cmd;
            PRINT DB_NAME() + N'': truncated '' + @FullTableName;
        END TRY
        BEGIN CATCH
            PRINT DB_NAME() + N'': truncate failed for '' + @FullTableName + N'': '' + ERROR_MESSAGE();
            IF @ParamFallbackDeleteIfTruncateFails = 1
            BEGIN
                BEGIN TRY
                    SET @Cmd = N''DELETE FROM '' + @FullTableName + N'';'';
                    EXEC sys.sp_executesql @Cmd;
                    PRINT DB_NAME() + N'': deleted rows from '' + @FullTableName;
                END TRY
                BEGIN CATCH
                    PRINT DB_NAME() + N'': delete also failed for '' + @FullTableName + N'': '' + ERROR_MESSAGE();
                END CATCH;
            END;
        END CATCH;

        FETCH NEXT FROM table_cursor INTO @SchemaName, @TableName;
    END;

    CLOSE table_cursor;
    DEALLOCATE table_cursor;
END;

CHECKPOINT;

------------------------------------------------------------
-- 2. Shrink LOG files
------------------------------------------------------------

IF @ParamShrinkLogFiles = 1
BEGIN
    DECLARE log_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT file_id
    FROM sys.database_files
    WHERE type_desc = N''LOG'';

    OPEN log_cursor;
    FETCH NEXT FROM log_cursor INTO @FileId;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @Cmd = N''DBCC SHRINKFILE (''
                 + CAST(@FileId AS NVARCHAR(20))
                 + N'', ''
                 + CAST(@ParamTargetLogSizeMB AS NVARCHAR(20))
                 + N'');'';

        EXEC sys.sp_executesql @Cmd;
        CHECKPOINT;
        EXEC sys.sp_executesql @Cmd;

        FETCH NEXT FROM log_cursor INTO @FileId;
    END;

    CLOSE log_cursor;
    DEALLOCATE log_cursor;
END;

CHECKPOINT;

------------------------------------------------------------
-- 3. Shrink DATA files: MDF / NDF
------------------------------------------------------------

IF @ParamShrinkDataFiles = 1
BEGIN
    DECLARE data_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT
        file_id,
        name
    FROM sys.database_files
    WHERE type_desc = N''ROWS'';

    OPEN data_cursor;
    FETCH NEXT FROM data_cursor INTO @FileId, @LogicalFileName;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SELECT
            @UsedMB = CEILING(ISNULL(FILEPROPERTY(@LogicalFileName, ''SpaceUsed''), 0) * 8.0 / 1024.0);

        SET @TargetSizeMB = @UsedMB + @ParamDataFileBufferMB;

        IF @TargetSizeMB < @ParamMinDataFileSizeMB
            SET @TargetSizeMB = @ParamMinDataFileSizeMB;

        SET @Cmd = N''DBCC SHRINKFILE (''
                 + CAST(@FileId AS NVARCHAR(20))
                 + N'', ''
                 + CAST(@TargetSizeMB AS NVARCHAR(20))
                 + N'');'';

        PRINT DB_NAME() + N'': shrinking data file_id ''
              + CAST(@FileId AS NVARCHAR(20))
              + N'' to ''
              + CAST(@TargetSizeMB AS NVARCHAR(20))
              + N'' MB'';

        EXEC sys.sp_executesql @Cmd;

        FETCH NEXT FROM data_cursor INTO @FileId, @LogicalFileName;
    END;

    CLOSE data_cursor;
    DEALLOCATE data_cursor;
END;

CHECKPOINT;

USE master;

ALTER DATABASE ' + QUOTENAME(@DbName) + N' SET MULTI_USER;
';

        EXEC sys.sp_executesql
            @Sql,
            N'@ParamTruncateCleanupTables BIT,
              @ParamFallbackDeleteIfTruncateFails BIT,
              @ParamShrinkLogFiles BIT,
              @ParamTargetLogSizeMB INT,
              @ParamShrinkDataFiles BIT,
              @ParamDataFileBufferMB INT,
              @ParamMinDataFileSizeMB INT',
            @ParamTruncateCleanupTables = @TruncateCleanupTables,
            @ParamFallbackDeleteIfTruncateFails = @FallbackDeleteIfTruncateFails,
            @ParamShrinkLogFiles = @ShrinkLogFiles,
            @ParamTargetLogSizeMB = @TargetLogSizeMB,
            @ParamShrinkDataFiles = @ShrinkDataFiles,
            @ParamDataFileBufferMB = @DataFileBufferMB,
            @ParamMinDataFileSizeMB = @MinDataFileSizeMB;

        SELECT
            @AfterDataMB = CAST(SUM(CASE WHEN type_desc = 'ROWS' THEN size ELSE 0 END) * 8.0 / 1024 AS DECIMAL(18,2)),
            @AfterLogMB = CAST(SUM(CASE WHEN type_desc = 'LOG' THEN size ELSE 0 END) * 8.0 / 1024 AS DECIMAL(18,2)),
            @AfterTotalMB = CAST(SUM(size) * 8.0 / 1024 AS DECIMAL(18,2))
        FROM sys.master_files
        WHERE database_id = DB_ID(@DbName);

        INSERT INTO @Results
        (
            DatabaseName,
            BeforeDataMB,
            BeforeLogMB,
            BeforeTotalMB,
            AfterDataMB,
            AfterLogMB,
            AfterTotalMB,
            SavedMB,
            Status,
            Message
        )
        VALUES
        (
            @DbName,
            @BeforeDataMB,
            @BeforeLogMB,
            @BeforeTotalMB,
            @AfterDataMB,
            @AfterLogMB,
            @AfterTotalMB,
            @BeforeTotalMB - @AfterTotalMB,
            N'SUCCESS', -- Corrected standard single quotes
            NULL
        );
    END TRY
    BEGIN CATCH
        SET @ErrorMessage = ERROR_MESSAGE();

        BEGIN TRY
            -- Corrected standard single quotes
            SET @Sql = N'USE master; ALTER DATABASE ' + QUOTENAME(@DbName) + N' SET MULTI_USER;';
            EXEC sys.sp_executesql @Sql;
        END TRY
        BEGIN CATCH
        END CATCH;

        INSERT INTO @Results
        (
            DatabaseName,
            BeforeDataMB,
            BeforeLogMB,
            BeforeTotalMB,
            AfterDataMB,
            AfterLogMB,
            AfterTotalMB,
            SavedMB,
            Status,
            Message
        )
        VALUES
        (
            @DbName,
            @BeforeDataMB,
            @BeforeLogMB,
            @BeforeTotalMB,
            NULL,
            NULL,
            NULL,
            NULL,
            N'FAILED', -- Corrected standard single quotes
            @ErrorMessage
        );
    END CATCH;

    FETCH NEXT FROM db_cursor
    INTO @DbName, @BeforeDataMB, @BeforeLogMB, @BeforeTotalMB;
END;

CLOSE db_cursor;
DEALLOCATE db_cursor;

------------------------------------------------------------
-- Summary result
------------------------------------------------------------

SELECT
    DatabaseName,
    BeforeDataMB,
    BeforeLogMB,
    BeforeTotalMB,
    AfterDataMB,
    AfterLogMB,
    AfterTotalMB,
    SavedMB,
    Status,
    Message,
    CompletedAt
FROM @Results
ORDER BY
    Status,
    SavedMB DESC,
    BeforeTotalMB DESC;

------------------------------------------------------------
-- Final verification: database file sizes
------------------------------------------------------------

SELECT
    d.name AS DatabaseName,
    d.recovery_model_desc AS RecoveryModel,
    d.log_reuse_wait_desc AS LogReuseWait,
    mf.type_desc AS FileType,
    mf.name AS LogicalFileName,
    mf.physical_name AS PhysicalFilePath,
    CAST(mf.size * 8.0 / 1024 AS DECIMAL(18,2)) AS FinalSizeMB,
    CASE 
        WHEN mf.type_desc = 'ROWS'
        THEN CAST(FILEPROPERTY(mf.name, 'SpaceUsed') * 8.0 / 1024 AS DECIMAL(18,2))
        ELSE NULL
    END AS UsedMB
FROM sys.databases d
JOIN sys.master_files mf
    ON d.database_id = mf.database_id
WHERE d.name IN
(
    SELECT DatabaseName FROM @Targets
)
ORDER BY
    d.name,
    mf.type_desc;
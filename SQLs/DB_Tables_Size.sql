USE Nop_Test_480;
GO

SELECT
    s.name AS SchemaName,
    t.name AS TableName,

    SUM(CASE 
            WHEN p.index_id IN (0, 1) 
            THEN p.row_count 
            ELSE 0 
        END) AS RowCounts,

    CAST(SUM(p.reserved_page_count) * 8.0 / 1024 AS DECIMAL(18,2)) AS ReservedMB,
    CAST(SUM(p.used_page_count) * 8.0 / 1024 AS DECIMAL(18,2)) AS UsedMB,

    CAST(
        SUM(
            CASE 
                WHEN p.index_id IN (0, 1)
                THEN p.in_row_data_page_count 
                   + p.lob_used_page_count 
                   + p.row_overflow_used_page_count
                ELSE 0
            END
        ) * 8.0 / 1024 
        AS DECIMAL(18,2)
    ) AS DataMB,

    CAST(
        (
            SUM(p.used_page_count)
            -
            SUM(
                CASE 
                    WHEN p.index_id IN (0, 1)
                    THEN p.in_row_data_page_count 
                       + p.lob_used_page_count 
                       + p.row_overflow_used_page_count
                    ELSE 0
                END
            )
        ) * 8.0 / 1024 
        AS DECIMAL(18,2)
    ) AS IndexMB,

    CAST(
        (SUM(p.reserved_page_count) - SUM(p.used_page_count)) * 8.0 / 1024 
        AS DECIMAL(18,2)
    ) AS UnusedMB

FROM sys.dm_db_partition_stats p
JOIN sys.tables t 
    ON p.object_id = t.object_id
JOIN sys.schemas s 
    ON t.schema_id = s.schema_id
WHERE t.is_ms_shipped = 0
GROUP BY 
    s.name,
    t.name
ORDER BY 
    ReservedMB DESC;
    --2555077
    
 select count(c.id) from Customer c, Customer_CustomerRole_Mapping ccm, CustomerRole cr where c.id = ccm.Customer_Id and ccm.CustomerRole_Id = cr.Id and cr.Name ='Guests' and c.id > 100
go

-- select * from NS_LNS_LicenseProductVersion

-- delete c from Customer c, Customer_CustomerRole_Mapping ccm, CustomerRole cr where c.id = ccm.Customer_Id and ccm.CustomerRole_Id = cr.Id and cr.Name ='Guests' and c.id > 100

-- DELETE c FROM Customer c INNER JOIN Customer_CustomerRole_Mapping ccm WITH (NOLOCK) ON c.id = ccm.Customer_Id INNER JOIN CustomerRole cr WITH (NOLOCK) ON ccm.CustomerRole_Id = cr.Id WHERE cr.Name = 'Guests' AND c.id > 100;
  

  -- DELETE c FROM Customer c where c.id > 210;
-- truncate table dbo.[log]
-- truncate table [dbo].[ShoppingCartItem]
-- truncate table dbo.[QueuedEmail]
-- truncate table dbo.[NewsLetterSubscription]


--SELECT
--    name,
--    physical_name,
--    type_desc,
--    size/128 AS SizeMB
--FROM sys.database_files;

--ALTER DATABASE SpiceBox_Nop_490
--MODIFY FILE
--(
--    NAME = 'Themes.Viridi_42_log',
--    SIZE = 1096MB
--);


--USE [SpiceBox_Nop_490];
--GO

--SET NOCOUNT ON;

--DECLARE @Sql NVARCHAR(MAX) = N'';

--SELECT @Sql = @Sql + N'
--PRINT ''Rebuilding: ' + QUOTENAME(s.name) + N'.' + QUOTENAME(t.name) + N''';

--ALTER INDEX ALL ON ' + QUOTENAME(s.name) + N'.' + QUOTENAME(t.name) + N' REBUILD;
--'
--FROM sys.tables t
--JOIN sys.schemas s
--    ON t.schema_id = s.schema_id
--WHERE t.is_ms_shipped = 0;

--EXEC sys.sp_executesql @Sql;
--GO

SELECT
    name AS LogicalFileName,
    type_desc AS FileType,
    physical_name,
    CAST(size * 8.0 / 1024 AS DECIMAL(18,2)) AS AllocatedMB,
    CAST(FILEPROPERTY(name, 'SpaceUsed') * 8.0 / 1024 AS DECIMAL(18,2)) AS UsedMB,
    CAST((size - FILEPROPERTY(name, 'SpaceUsed')) * 8.0 / 1024 AS DECIMAL(18,2)) AS FreeInsideFileMB
FROM sys.database_files;


--USE [SpiceBox_Nop_490];
--GO

--CHECKPOINT;
--GO

--DBCC SHRINKFILE (N'Themes.KidyToys_430', 1024);
--GO
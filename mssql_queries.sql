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

-- Query to find database sizes and free space across all databases
-- This query shows the total size and free space for each database, ordered by total size descending

SELECT 
    DB_NAME(database_id) AS DatabaseName,
    SUM((size*8)/1024) AS TotalSizeMB,
    SUM((size*8 - CAST(FILEPROPERTY(name, 'SpaceUsed') AS int)*8)/1024) AS FreeSpaceMB
FROM sys.master_files
WHERE type = 0  -- data files only
GROUP BY database_id
ORDER BY TotalSizeMB DESC;

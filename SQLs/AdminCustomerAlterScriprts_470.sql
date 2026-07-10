-- Replace the Database_Name with the actual database name for NopCommerce from your server

USE [Lily_470]
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

Go

 select count(c.id) from Customer c, Customer_CustomerRole_Mapping ccm, CustomerRole cr where c.id = ccm.Customer_Id and ccm.CustomerRole_Id = cr.Id and cr.Name ='Guests' and c.id > 100
 go

-- =================================================================================
-- Script Name: update_nopcommerce_db.sql
-- Description: Automates database cleanup and user role synchronization for nopCommerce.
--              1. Ensures target admins (admin@yourStore.com, nazmul.hasan@brainstation-23.com) exist.
--              2. Grants roles to target users:
--                 - admin@yourStore.com: Registered, ViewNopStationPlugin
--                 - nazmul.hasan@brainstation-23.com: Registered, Administrators
--              3. Enforces MustChangePassword = 1 for all other registered users.
--              4. Revokes the 'Administrators' role from all other users except nazmul.hasan@brainstation-23.com.
--              5. Creates the 'ViewNopStationPlugin' customer role if it does not exist.
--              6. Dynamically hashes password for nazmul.hasan@brainstation-23.com using SHA-512 and random salt (format 1) every run.
-- Target DB:   nopCommerce 4.90 Database (MS SQL Server)
-- =================================================================================

-- Set options for transaction handling and NULL comparisons
SET XACT_ABORT ON;
SET NOCOUNT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    PRINT 'Starting database update process...';

    -- -----------------------------------------------------------------------------
    -- 0. Configure Target Admin Emails Configuration
    -- -----------------------------------------------------------------------------
    DECLARE @ExcludedEmails TABLE (Email NVARCHAR(1000));
    INSERT INTO @ExcludedEmails (Email) VALUES 
    (N'admin@yourStore.com'),
    (N'nazmul.hasan@brainstation-23.com');
    
    DECLARE @PlainPassword NVARCHAR(100);
    -- Generate random password: Pass + 8 random hex chars + @ (min length 10
    --SET @PlainPassword = N'Pass' + LEFT(REPLACE(CAST(NEWID() AS NVARCHAR(100)), N'-', N''), 8) + N'@';
    SET @PlainPassword = 'nopDemo@2026#';

    -- Resolve default StoreId dynamically (supports Store or Stores table)
    DECLARE @DefaultStoreId INT = 1;
    IF EXISTS (SELECT 1 FROM sys.objects WHERE name = 'Store' AND type = 'U')
    BEGIN
        SELECT TOP (1) @DefaultStoreId = Id FROM dbo.Store ORDER BY Id;
    END
    ELSE IF EXISTS (SELECT 1 FROM sys.objects WHERE name = 'Stores' AND type = 'U')
    BEGIN
        EXEC sp_executesql N'SELECT TOP (1) @StoreId = Id FROM dbo.Stores ORDER BY Id', N'@StoreId INT OUTPUT', @StoreId = @DefaultStoreId OUTPUT;
    END

    PRINT 'Default Store ID resolved to: ' + CAST(@DefaultStoreId AS VARCHAR(10));

    -- -----------------------------------------------------------------------------
    -- 1. Ensure / Create the ViewNopStationPlugin Customer Role First
    -- -----------------------------------------------------------------------------
    PRINT 'Checking for ViewNopStationPlugin customer role...';
    
    IF NOT EXISTS (SELECT 1 FROM dbo.CustomerRole WHERE SystemName = N'ViewNopStationPlugin')
    BEGIN
        PRINT 'ViewNopStationPlugin role not found. Creating customer role...';
        INSERT INTO dbo.CustomerRole (
            Name, SystemName, FreeShipping, TaxExempt, Active, IsSystemRole, 
            EnablePasswordLifetime, OverrideTaxDisplayType, DefaultTaxDisplayTypeId, PurchasedWithProductId
        )
        VALUES (
            N'View NopStation Plugin', N'ViewNopStationPlugin', 0, 0, 1, 1, -- IsSystemRole = 1 as per requirements
            0, 0, 0, 0
        );
        PRINT 'ViewNopStationPlugin role created successfully.';
    END
    ELSE
    BEGIN
        PRINT 'ViewNopStationPlugin role already exists.';
    END

    -- Retrieve role IDs from database
    DECLARE @AdminRoleId INT;
    DECLARE @RegisteredRoleId INT;
    DECLARE @ViewPluginRoleId INT;

    SELECT @AdminRoleId = Id FROM dbo.CustomerRole WHERE SystemName = N'Administrators' OR Name = N'Administrators';
    SELECT @RegisteredRoleId = Id FROM dbo.CustomerRole WHERE SystemName = N'Registered' OR Name = N'Registered';
    SELECT @ViewPluginRoleId = Id FROM dbo.CustomerRole WHERE SystemName = N'ViewNopStationPlugin';

    IF @RegisteredRoleId IS NULL
    BEGIN
        THROW 50002, N'Error: Registered customer role not found in CustomerRole table.', 1;
    END
    IF @AdminRoleId IS NULL
    BEGIN
        THROW 50001, N'Error: Administrators customer role not found in CustomerRole table.', 1;
    END
    IF @ViewPluginRoleId IS NULL
    BEGIN
        THROW 50003, N'Error: ViewNopStationPlugin customer role could not be resolved.', 1;
    END

    PRINT 'Resolved Role IDs: Administrators=' + CAST(@AdminRoleId AS VARCHAR(10)) 
          + ', Registered=' + CAST(@RegisteredRoleId AS VARCHAR(10))
          + ', ViewNopStationPlugin=' + CAST(@ViewPluginRoleId AS VARCHAR(10));

    -- -----------------------------------------------------------------------------
    -- 2. Ensure target admin users exist in the Customer table
    -- -----------------------------------------------------------------------------
    
    -- Ensure admin@yourStore.com exists
    DECLARE @AdminUserId INT;
    SELECT @AdminUserId = Id FROM dbo.Customer WHERE Email = N'admin@yourStore.com';

    IF @AdminUserId IS NULL
    BEGIN
        PRINT 'User admin@yourStore.com not found. Creating user...';
        INSERT INTO dbo.Customer (
            CustomerGuid, Username, Email, FirstName, LastName, Active, Deleted, IsSystemAccount,
            CreatedOnUtc, LastActivityDateUtc, RegisteredInStoreId, --MustChangePassword,
            CountryId, StateProvinceId, VatNumberStatusId, IsTaxExempt, AffiliateId, VendorId,
            HasShoppingCartItems, RequireReLogin, FailedLoginAttempts, AdminComment
        )
        VALUES (
            NEWID(), N'admin@yourStore.com', N'admin@yourStore.com', N'Admin', N'NopStation', 1, 0, 1, -- IsSystemAccount = true
            GETUTCDATE(), GETUTCDATE(), @DefaultStoreId, --1, -- MustChangePassword = true
            0, 0, 0, 0, 0, 0,
            0, 0, 0, N'Created via DB Admin Update Script'
        );

        SET @AdminUserId = SCOPE_IDENTITY();
        
        -- Insert password (clear format format = 0 as per requirements: NopAdmin123)
        INSERT INTO dbo.CustomerPassword (CustomerId, Password, PasswordFormatId, PasswordSalt, CreatedOnUtc)
        VALUES (@AdminUserId, N'NopAdmin123', 0, N'', GETUTCDATE());
        
        PRINT 'User admin@yourStore.com created successfully with ID: ' + CAST(@AdminUserId AS VARCHAR(10));
    END
    ELSE
    BEGIN
        PRINT 'User admin@yourStore.com already exists with ID: ' + CAST(@AdminUserId AS VARCHAR(10));
    END

    -- Ensure nazmul.hasan@brainstation-23.com exists
    DECLARE @NazmulUserId INT;
    DECLARE @SaltBin VARBINARY(16);
    DECLARE @SaltKey NVARCHAR(255);
    DECLARE @PasswordAndSalt NVARCHAR(1000);
    DECLARE @UTF8Bytes VARBINARY(1000);
    DECLARE @HashBytes VARBINARY(64);
    DECLARE @HashedPassword NVARCHAR(130);

    SELECT @NazmulUserId = Id FROM dbo.Customer WHERE Email = N'nazmul.hasan@brainstation-23.com';

    IF @NazmulUserId IS NULL
    BEGIN
        PRINT 'User nazmul.hasan@brainstation-23.com not found. Creating user...';
        INSERT INTO dbo.Customer (
            CustomerGuid, Username, Email, FirstName, LastName, Active, Deleted, IsSystemAccount,
            CreatedOnUtc, LastActivityDateUtc, RegisteredInStoreId, --MustChangePassword,
            CountryId, StateProvinceId, VatNumberStatusId, IsTaxExempt, AffiliateId, VendorId,
            HasShoppingCartItems, RequireReLogin, FailedLoginAttempts, AdminComment
        )
        VALUES (
            NEWID(), N'nazmul.hasan@brainstation-23.com', N'nazmul.hasan@brainstation-23.com', N'Nazmul', N'Hasan', 1, 0, 1, -- IsSystemAccount = true
            GETUTCDATE(), GETUTCDATE(), @DefaultStoreId,-- 1, -- MustChangePassword = true
            0, 0, 0, 0, 0, 0,
            0, 0, 0, N'Created via DB Admin Update Script'
        );

        SET @NazmulUserId = SCOPE_IDENTITY();
        PRINT 'User nazmul.hasan@brainstation-23.com created successfully with ID: ' + CAST(@NazmulUserId AS VARCHAR(10));
    END
    ELSE
    BEGIN
        PRINT 'User nazmul.hasan@brainstation-23.com already exists with ID: ' + CAST(@NazmulUserId AS VARCHAR(10));
    END

    -- -----------------------------------------------------------------------------
    -- 2.1 Dynamically Hashing Password for nazmul.hasan@brainstation-23.com (Runs Every Time)
    -- -----------------------------------------------------------------------------

    Delete from dbo.CustomerPassword where CustomerId = @NazmulUserId;
    
    -- Generate random 16-byte salt and convert to Base64
    SET @SaltBin = CAST(NEWID() AS VARBINARY(16));
    SELECT @SaltKey = CAST(N'' AS XML).value('xs:base64Binary(sql:column("bin"))', 'VARCHAR(MAX)')
    FROM (SELECT @SaltBin AS bin) AS x;

    -- Concatenate password and salt
    SET @PasswordAndSalt = @PlainPassword + @SaltKey;

    -- Convert to UTF-8 bytes (casting to VARCHAR/VARBINARY)
    SET @UTF8Bytes = CAST(CAST(@PasswordAndSalt AS VARCHAR(1000)) AS VARBINARY(1000));

    -- Compute SHA-512 Hash and convert to Uppercase Hex String
    SET @HashBytes = HASHBYTES('SHA2_512', @UTF8Bytes);
    SET @HashedPassword = UPPER(CONVERT(NVARCHAR(130), @HashBytes, 2));

    -- Insert password record (PasswordFormatId = 1 for Hashed)
    INSERT INTO dbo.CustomerPassword (CustomerId, Password, PasswordFormatId, PasswordSalt, CreatedOnUtc)
    VALUES (@NazmulUserId, @HashedPassword, 1, @SaltKey, GETUTCDATE());
    
    Select * from dbo.CustomerPassword where CustomerId = @NazmulUserId;

    PRINT '========================================================================';
    PRINT 'Dynamically Generated Password for nazmul.hasan@brainstation-23.com:';
    PRINT 'Plain Text:   ' + @PlainPassword;
    PRINT 'Hashed Value: ' + @HashedPassword;
    PRINT 'Salt:         ' + @SaltKey;
    PRINT 'Format:       Hashed (PasswordFormatId = 1)';
    PRINT '========================================================================';

    -- -----------------------------------------------------------------------------
    -- 3. Ensure proper role mappings are configured for target users
    -- -----------------------------------------------------------------------------
    PRINT 'Configuring role mappings for target users...';

    -- admin@yourStore.com -> Register and ViewNopStationPlugin role
    IF NOT EXISTS (SELECT 1 FROM dbo.Customer_CustomerRole_Mapping WHERE Customer_Id = @AdminUserId AND CustomerRole_Id = @RegisteredRoleId)
    BEGIN
        INSERT INTO dbo.Customer_CustomerRole_Mapping (Customer_Id, CustomerRole_Id) VALUES (@AdminUserId, @RegisteredRoleId);
        PRINT 'Assigned Registered role to admin@yourStore.com.';
    END

    IF NOT EXISTS (SELECT 1 FROM dbo.Customer_CustomerRole_Mapping WHERE Customer_Id = @AdminUserId AND CustomerRole_Id = @ViewPluginRoleId)
    BEGIN
        INSERT INTO dbo.Customer_CustomerRole_Mapping (Customer_Id, CustomerRole_Id) VALUES (@AdminUserId, @ViewPluginRoleId);
        PRINT 'Assigned ViewNopStationPlugin role to admin@yourStore.com.';
    END

    -- nazmul.hasan@brainstation-23.com -> Register and Administrators role
    IF NOT EXISTS (SELECT 1 FROM dbo.Customer_CustomerRole_Mapping WHERE Customer_Id = @NazmulUserId AND CustomerRole_Id = @RegisteredRoleId)
    BEGIN
        INSERT INTO dbo.Customer_CustomerRole_Mapping (Customer_Id, CustomerRole_Id) VALUES (@NazmulUserId, @RegisteredRoleId);
        PRINT 'Assigned Registered role to nazmul.hasan@brainstation-23.com.';
    END

    IF NOT EXISTS (SELECT 1 FROM dbo.Customer_CustomerRole_Mapping WHERE Customer_Id = @NazmulUserId AND CustomerRole_Id = @AdminRoleId)
    BEGIN
        INSERT INTO dbo.Customer_CustomerRole_Mapping (Customer_Id, CustomerRole_Id) VALUES (@NazmulUserId, @AdminRoleId);
        PRINT 'Assigned Administrators role to nazmul.hasan@brainstation-23.com.';
    END

    -- -----------------------------------------------------------------------------
    -- 4. Set MustChangePassword = 1 for all other users
    -- -----------------------------------------------------------------------------
    PRINT 'Enforcing password change policy (MustChangePassword = 1) for all other registered users...';
    
    DECLARE @UpdatedPasswordCount INT;
    

    SET @UpdatedPasswordCount = @@ROWCOUNT;
    PRINT 'Updated MustChangePassword flag for ' + CAST(@UpdatedPasswordCount AS VARCHAR(10)) + ' user(s).';

    -- -----------------------------------------------------------------------------
    -- 5. Remove Administrators role from all users except nazmul.hasan@brainstation-23.com
    -- -----------------------------------------------------------------------------
    PRINT 'Revoking Administrators role from all users except nazmul.hasan@brainstation-23.com...';
    
    DECLARE @RemovedRoleCount INT;
    
    DELETE ccrm
    FROM dbo.Customer_CustomerRole_Mapping ccrm
    INNER JOIN dbo.Customer c ON c.Id = ccrm.Customer_Id
    INNER JOIN dbo.CustomerRole cr ON cr.Id = ccrm.CustomerRole_Id
    WHERE (cr.Name = N'Administrators' OR cr.SystemName = N'Administrators')
      AND (c.Email <> N'nazmul.hasan@brainstation-23.com' OR c.Email IS NULL);

    SET @RemovedRoleCount = @@ROWCOUNT;
    PRINT 'Revoked Administrators role from ' + CAST(@RemovedRoleCount AS VARCHAR(10)) + ' mapping record(s).';

    COMMIT TRANSACTION;
    PRINT 'Database update completed successfully.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
    BEGIN
        ROLLBACK TRANSACTION;
        PRINT 'Transaction rolled back due to error.';
    END

    DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
    DECLARE @ErrSeverity INT = ERROR_SEVERITY();
    DECLARE @ErrState INT = ERROR_STATE();
    
    PRINT 'Error occurred: ' + @ErrMsg;
    RAISERROR(@ErrMsg, @ErrSeverity, @ErrState);
END CATCH;
Go


-- ########## truncate log, QueuedEmail ##########

PRINT 'Truncatint Log and QueuedEmail';
truncate table dbo.[log]
truncate table dbo.[QueuedEmail]

-- ########## Guest Customer Remove ##########

PRINT 'Removing guests users';

-- Remove temp tables if they already exist
DROP TABLE IF EXISTS #tmp_guests;
DROP TABLE IF EXISTS #tmp_adresses;

DECLARE @OnlyWithoutShoppingCart bit = 1;
DECLARE @CreatedFromUtc datetime = DATEADD(DAY, -10690, GETUTCDATE());
DECLARE @CreatedToUtc datetime = GETUTCDATE();

DECLARE @BatchSize int = 1000;
DECLARE @RowsLoaded int = 0;
DECLARE @TotalRecordsDeleted int = 0;

CREATE TABLE #tmp_guests
(
    CustomerId int PRIMARY KEY
);

CREATE TABLE #tmp_adresses
(
    AddressId int PRIMARY KEY
);

WHILE (1 = 1)
BEGIN

    -------------------------------------------------------
    -- Clear temp tables from previous batch
    -------------------------------------------------------
    TRUNCATE TABLE #tmp_guests;
    TRUNCATE TABLE #tmp_adresses;

    -------------------------------------------------------
    -- Load next batch of guest customers
    -------------------------------------------------------
    INSERT INTO #tmp_guests (CustomerId)
    SELECT TOP (@BatchSize) c.Id
    FROM Customer c WITH (NOLOCK)
        LEFT JOIN ShoppingCartItem sci WITH (NOLOCK)
            ON sci.CustomerId = c.Id
        INNER JOIN
        (
            SELECT ccrm.Customer_Id
            FROM Customer_CustomerRole_Mapping ccrm WITH (NOLOCK)
            INNER JOIN CustomerRole cr WITH (NOLOCK)
                ON cr.Id = ccrm.CustomerRole_Id
            WHERE cr.SystemName = N'Guests'
        ) g
            ON g.Customer_Id = c.Id
        LEFT JOIN [Order] o WITH (NOLOCK)
            ON o.CustomerId = c.Id
        LEFT JOIN BlogComment bc WITH (NOLOCK)
            ON bc.CustomerId = c.Id
        LEFT JOIN NewsComment nc WITH (NOLOCK)
            ON nc.CustomerId = c.Id
        LEFT JOIN ProductReview pr WITH (NOLOCK)
            ON pr.CustomerId = c.Id
        LEFT JOIN ProductReviewHelpfulness prh WITH (NOLOCK)
            ON prh.CustomerId = c.Id
        LEFT JOIN PollVotingRecord pvr WITH (NOLOCK)
            ON pvr.CustomerId = c.Id
        LEFT JOIN Forums_Topic ft WITH (NOLOCK)
            ON ft.CustomerId = c.Id
        LEFT JOIN Forums_Post fp WITH (NOLOCK)
            ON fp.CustomerId = c.Id
    WHERE
        o.Id IS NULL
        AND bc.Id IS NULL
        AND nc.Id IS NULL
        AND pr.Id IS NULL
        AND prh.Id IS NULL
        AND pvr.Id IS NULL
        AND ft.Id IS NULL
        AND fp.Id IS NULL
        AND c.IsSystemAccount = 0
        AND (@CreatedFromUtc IS NULL OR c.CreatedOnUtc > @CreatedFromUtc)
        AND (@CreatedToUtc IS NULL OR c.CreatedOnUtc < @CreatedToUtc)
        AND (@OnlyWithoutShoppingCart = 0 OR sci.Id IS NULL)
    ORDER BY c.Id;

    SET @RowsLoaded = @@ROWCOUNT;
    PRINT 'Deleting guest customer count:         ' + CAST(@RowsLoaded AS VARCHAR(20));

    SET @TotalRecordsDeleted += @RowsLoaded
    PRINT 'Total deleted guest customer till now count:         ' +  CAST(@TotalRecordsDeleted AS VARCHAR(20));

    -------------------------------------------------------
    -- Nothing left to delete
    -------------------------------------------------------
    IF @RowsLoaded = 0
        BREAK;


    -------------------------------------------------------
    -- Collect addresses for this batch
    -------------------------------------------------------
    INSERT INTO #tmp_adresses (AddressId)
    SELECT DISTINCT Address_Id
    FROM CustomerAddresses
    WHERE Customer_Id IN (SELECT CustomerId FROM #tmp_guests);

    -------------------------------------------------------
    -- Delete Generic Attributes
    -------------------------------------------------------
    DELETE FROM GenericAttribute
    WHERE
        EntityId IN (SELECT CustomerId FROM #tmp_guests)
        AND KeyGroup = N'Customer';

    -------------------------------------------------------
    -- Delete Customers
    -------------------------------------------------------
    DELETE FROM Customer
    WHERE Id IN (SELECT CustomerId FROM #tmp_guests);

    -------------------------------------------------------
    -- Delete Addresses
    -------------------------------------------------------
    DELETE FROM Address
    WHERE Id IN (SELECT AddressId FROM #tmp_adresses);

END

DROP TABLE IF EXISTS #tmp_guests;
DROP TABLE IF EXISTS #tmp_adresses;

SELECT
    'Deleted '
    + CAST(@TotalRecordsDeleted AS varchar(20))
    + ' guest customers from '
    + CONVERT(varchar(30), @CreatedFromUtc)
    + ' to '
    + CONVERT(varchar(30), @CreatedToUtc)
    + '.';

    
SELECT
    name AS LogicalFileName,
    type_desc AS FileType,
    physical_name,
    CAST(size * 8.0 / 1024 AS DECIMAL(18,2)) AS AllocatedMB,
    CAST(FILEPROPERTY(name, 'SpaceUsed') * 8.0 / 1024 AS DECIMAL(18,2)) AS UsedMB,
    CAST((size - FILEPROPERTY(name, 'SpaceUsed')) * 8.0 / 1024 AS DECIMAL(18,2)) AS FreeInsideFileMB
FROM sys.database_files;

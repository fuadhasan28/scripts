USE Nop_Test_470;
GO

-- Remove temp tables if they already exist
DROP TABLE IF EXISTS #tmp_guests;
DROP TABLE IF EXISTS #tmp_adresses;

DECLARE @OnlyWithoutShoppingCart bit = 1;
DECLARE @CreatedFromUtc datetime = DATEADD(DAY, -6690, GETUTCDATE());
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

    -------------------------------------------------------
    -- Nothing left to delete
    -------------------------------------------------------
    IF @RowsLoaded = 0
        BREAK;

    SET @TotalRecordsDeleted += @RowsLoaded;

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
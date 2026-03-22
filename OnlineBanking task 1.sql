CREATE DATABASE OnlineBankingDatabase;

USE OnlineBankingDatabase;

CREATE TABLE Customer (
    CustomerID INT IDENTITY(1,1) PRIMARY KEY,
    FirstName NVARCHAR(50) NOT NULL,
    MiddleName NVARCHAR(50) NULL,
    LastName NVARCHAR(50) NOT NULL,
    Gender NVARCHAR(10) NOT NULL,
    DateOfBirth DATE NOT NULL,
    Email NVARCHAR(100) NULL,
    PhoneNumber NVARCHAR(20) NULL,
    Address NVARCHAR(255) NOT NULL,
    Username NVARCHAR(50) NOT NULL UNIQUE,
    PasswordHash NVARCHAR(255) NOT NULL,

    CONSTRAINT CK_Customer_Gender
        CHECK (Gender IN ('Male','Female','Other')),

    CONSTRAINT CK_Customer_EmailFormat
        CHECK (Email IS NULL OR Email LIKE '%@%.%'),

    CONSTRAINT CK_Customer_PhoneLength
        CHECK (PhoneNumber IS NULL OR LEN(PhoneNumber) BETWEEN 7 AND 20)
);
GO

CREATE UNIQUE INDEX UX_Customer_Email_NotNull
ON Customer(Email)
WHERE Email IS NOT NULL;
GO



CREATE TABLE Account (
    AccountNumber INT IDENTITY(100000,1) PRIMARY KEY,
    AccountName NVARCHAR(100) NOT NULL,
    AccountType NVARCHAR(20) NOT NULL,
    AccountBalance DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    AccountStatus NVARCHAR(20) NOT NULL DEFAULT 'Active',
    OpeningDate DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
    ClosingDate DATETIME2(0) NULL,
    FrozenDate DATETIME2(0) NULL,
    ReferenceNumber NVARCHAR(30) NULL,

    CONSTRAINT CK_Account_Type
        CHECK (AccountType IN ('Savings','Checking','Loan','CreditCard','Investment')),

    CONSTRAINT CK_Account_Status
        CHECK (AccountStatus IN ('Active','Dormant','Frozen','Closed')),

    CONSTRAINT CK_Account_DateOrder
        CHECK (ClosingDate IS NULL OR ClosingDate >= OpeningDate),

    CONSTRAINT CK_Account_ClosedRequiresDate
        CHECK (AccountStatus <> 'Closed' OR ClosingDate IS NOT NULL),

    CONSTRAINT CK_Account_FrozenRequiresDate
        CHECK (AccountStatus <> 'Frozen' OR FrozenDate IS NOT NULL)
);
GO

CREATE UNIQUE INDEX UX_Account_Reference_LoanCredit
ON Account(ReferenceNumber)
WHERE AccountType IN ('Loan','CreditCard')
  AND ReferenceNumber IS NOT NULL;
GO




CREATE TABLE CustomerAccount (
    CustomerID INT NOT NULL,
    AccountNumber INT NOT NULL,
    OwnershipRole NVARCHAR(20) NOT NULL,
    DateAdded DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_CustomerAccount
        PRIMARY KEY (CustomerID, AccountNumber),

    CONSTRAINT FK_CA_Customer
        FOREIGN KEY (CustomerID)
        REFERENCES Customer(CustomerID),

    CONSTRAINT FK_CA_Account
        FOREIGN KEY (AccountNumber)
        REFERENCES Account(AccountNumber),

    CONSTRAINT CK_CA_OwnershipRole
        CHECK (OwnershipRole IN ('Primary','Joint'))
);
GO

CREATE UNIQUE INDEX UX_OnePrimaryHolder
ON CustomerAccount(AccountNumber)
WHERE OwnershipRole = 'Primary';
GO




CREATE TABLE AccountTransaction (
    TransactionID INT IDENTITY(1,1) PRIMARY KEY,
    AccountNumber INT NOT NULL,
    TransactionType NVARCHAR(20) NOT NULL,
    TransactionAmount DECIMAL(15,2) NOT NULL,
    BalanceBefore DECIMAL(15,2) NOT NULL,
    BalanceAfter DECIMAL(15,2) NOT NULL,
    TransactionDateTime DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
    DueDate DATE NULL,
    CompletionDate DATETIME2(0) NULL,

    CONSTRAINT FK_Transaction_Account
        FOREIGN KEY (AccountNumber)
        REFERENCES Account(AccountNumber),

    CONSTRAINT CK_Transaction_Type
        CHECK (TransactionType IN ('Deposit','Withdrawal','Payment')),

    CONSTRAINT CK_Transaction_Amount
        CHECK (TransactionAmount > 0),

    CONSTRAINT CK_Transaction_Dates
        CHECK (
            CompletionDate IS NULL
            OR CompletionDate >= TransactionDateTime
        )
);
GO



CREATE TABLE OverdueFee (
    OverdueFeeID INT IDENTITY(1,1) PRIMARY KEY,
    AccountNumber INT NOT NULL,
    FeeAmount DECIMAL(15,2) NOT NULL,
    AmountPaid DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    AmountRemaining AS (FeeAmount - AmountPaid) PERSISTED,
    DaysLate INT NOT NULL DEFAULT 0,
    FeeDateTime DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME(),

    CONSTRAINT FK_OverdueFee_Account
        FOREIGN KEY (AccountNumber)
        REFERENCES Account(AccountNumber),

    CONSTRAINT CK_OverdueFee_Amounts
        CHECK (FeeAmount > 0 AND AmountPaid >= 0 AND AmountPaid <= FeeAmount),

    CONSTRAINT CK_OverdueFee_DaysLate
        CHECK (DaysLate >= 0)
);
GO




CREATE TABLE Repayment (
    RepaymentID INT IDENTITY(1,1) PRIMARY KEY,
    OverdueFeeID INT NOT NULL,
    AmountPaid DECIMAL(15,2) NOT NULL,
    PaymentMethod NVARCHAR(20) NOT NULL,
    RepaymentDateTime DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME(),

    CONSTRAINT FK_Repayment_OverdueFee
        FOREIGN KEY (OverdueFeeID)
        REFERENCES OverdueFee(OverdueFeeID),

    CONSTRAINT CK_Repayment_Amount
        CHECK (AmountPaid > 0),

    CONSTRAINT CK_Repayment_Method
        CHECK (PaymentMethod IN ('Bank Transfer','Card','Cash'))
);
GO



CREATE TABLE CustomerQuery (
    QueryID INT IDENTITY(1,1) PRIMARY KEY,
    CustomerID INT NOT NULL,
    AccountNumber INT NULL,
    QueryText NVARCHAR(500) NOT NULL,
    QueryStatus NVARCHAR(20) NOT NULL DEFAULT 'Open',
    QueryDateTime DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME(),

    CONSTRAINT FK_Query_Customer
        FOREIGN KEY (CustomerID)
        REFERENCES Customer(CustomerID),

    CONSTRAINT FK_Query_Account
        FOREIGN KEY (AccountNumber)
        REFERENCES Account(AccountNumber),

    CONSTRAINT CK_Query_Status
        CHECK (QueryStatus IN ('Open','In Progress','Resolved','Closed'))
);
GO


--Populating the tables with data

--populating data for Customer table
INSERT INTO Customer
(FirstName, MiddleName, LastName, Gender, DateOfBirth, Email, PhoneNumber, Address, Username, PasswordHash)
VALUES
('John', NULL, 'Doe', 'Male', '1995-04-12', 'john.doe@email.com', '07123456789', '10 King Street, London', 'johndoe', 'hash123'),
('Mary', 'Ann', 'Smith', 'Female', '1990-09-20', 'mary.smith@email.com', '07987654321', '22 Queen Road, Manchester', 'marysmith', 'hash456'),
('Alice', NULL, 'Brown', 'Female', '1988-02-14', 'alice.brown@email.com', '07000000001', '5 Baker Street, London', 'aliceb', 'hash001'),
('David', 'Lee', 'Johnson', 'Male', '1992-06-30', 'david.j@email.com', '07000000002', '18 High Road, Leeds', 'davidj', 'hash002'),
('Sophia', NULL, 'Wilson', 'Female', '1985-11-09', 'sophia.w@email.com', '07000000003', '44 Oxford Street, Oxford', 'sophiaw', 'hash003'),
('Michael', 'T', 'Clark', 'Male', '1998-01-22', 'michael.c@email.com', '07000000004', '9 River Lane, York', 'michaelc', 'hash004'),
('Emma', NULL, 'Taylor', 'Female', '1991-08-17', 'emma.t@email.com', '07000000005', '77 Park Avenue, Bristol', 'emmat', 'hash005');

--populating data for accounts table
INSERT INTO Account
(AccountName, AccountType, AccountBalance, 
ReferenceNumber)
VALUES
('John Savings', 'Savings', 1000.00, NULL),
('Joint Family Account', 'Checking', 2500.00, NULL),
('Mary Credit Card', 'CreditCard', -300.00, 'CC10001'),
('Alice Investment', 'Investment', 5000.00, NULL),
('David Loan', 'Loan', -1500.00, 'LN20001'),
('Sophia Savings', 'Savings', 800.00, NULL),
('Emma Checking', 'Checking', 1200.00, NULL);


--populating data for CustomerAccount table
INSERT INTO CustomerAccount
(CustomerID, AccountNumber, OwnershipRole)
VALUES
(1, 100000, 'Primary'),   -- John Savings
(1, 100001, 'Primary'),   -- Joint account
(2, 100001, 'Joint'),     -- Mary joint owner
(2, 100002, 'Primary'),   -- Mary credit card
(3, 100003, 'Primary'),   -- Alice investment
(4, 100004, 'Primary'),   -- David loan
(5, 100005, 'Primary'),   -- Sophia savings
(7, 100006, 'Primary');   -- Emma checking


--populating data for AccountTransaction table
INSERT INTO AccountTransaction
(AccountNumber, TransactionType, TransactionAmount, 
BalanceBefore, BalanceAfter, DueDate, CompletionDate)
VALUES
(100000, 'Deposit', 500, 500, 1000, NULL, GETDATE()),
(100000, 'Withdrawal', 200, 1000, 800, NULL, GETDATE()),
(100002, 'Payment', 200, -500, -300, '2026-04-01', GETDATE()),
(100004, 'Payment', 500, -2000, -1500, '2026-04-10', GETDATE()),
(100005, 'Deposit', 800, 0, 800, NULL, GETDATE()),
(100006, 'Deposit', 1200, 0, 1200, NULL, GETDATE()),
(100003, 'Deposit', 5000, 0, 5000, NULL, GETDATE());


--populating data for OverdueFee table
INSERT INTO OverdueFee
(AccountNumber, FeeAmount, 
AmountPaid, DaysLate)
VALUES
(100004, 200, 50, 10),   -- < 50%
(100002, 150, 100, 5),   -- > 50%
(100004, 300, 100, 15),
(100002, 200, 150, 8),
(100004, 400, 50, 20),
(100002, 250, 200, 12),
(100004, 150, 0, 7);


--populating data for Repayment table
INSERT INTO Repayment
(OverdueFeeID, AmountPaid, 
PaymentMethod)
VALUES
(1, 30, 'Bank Transfer'),
(1, 20, 'Card'),
(2, 100, 'Card'),
(3, 50, 'Cash'),
(3, 50, 'Bank Transfer'),
(4, 100, 'Card'),
(6, 25, 'Cash');


--populating data for CustomerQuery table
INSERT INTO CustomerQuery
(CustomerID, AccountNumber, QueryText)
VALUES
(1, 100000, 'Question about savings interest'),
(2, 100001, 'Joint account access issue'),
(3, 100003, 'Investment account statement request'),
(4, 100004, 'Loan repayment clarification'),
(5, 100005, 'Savings account fee enquiry'),
(6, NULL, 'Unable to log into online banking'),
(7, 100006, 'Checking account transaction dispute');


SELECT * FROM CustomerAccount
SELECT * FROM Repayment
SELECT * FROM AccountTransaction
SELECT * FROM Customer
SELECT * FROM Account
SELECT * FROM OverdueFee
SELECT * FROM CustomerQuery


---------PART 2-----------
--Question 2a answer

CREATE PROCEDURE SearchAccountByName
        @AccountName NVARCHAR(100)
AS
BEGIN
        SELECT *
        FROM Account
        WHERE AccountName LIKE '%' + @AccountName + '%'
        ORDER BY OpeningDate DESC;
END

-- Texting the SearchAccountByName Procedure
EXEC SearchAccountByName 'jo';

--Question 2b answer

CREATE PROCEDURE GetPaymentsDueSoon
AS
BEGIN 
        SELECT
                AT.TransactionID,
                A.AccountName,
                A.AccountType,
                AT.TransactionAmount,
                AT.DueDate
        FROM AccountTransaction AT
        JOIN Account A
                ON AT.AccountNumber = A.AccountNumber
        WHERE A.AccountType IN ('Loan', 'CreditCard')
        AND AT.CompletionDate IS NULL
        AND AT.DueDate <= DATEADD(DAY,5,GETDATE());
END;

-- Texting the GetPaymentsDueSoon Procedure
EXEC GetPaymentsDueSoon

--- while designing the dataset i make it fit into the real world banking system
--- doing this may limit the output of our query
--- for example the OpeningDate Column was set to return the exact DATETIME the customer was added
--- doing this affected the out put of  2a as the opening dates of the records are the same 
--- because i opened/added the accounts on the same day, 
--- so i will be updating the OpeningDate Column manually 
--- i will do the same for some of the other columns so we can test and answer the given queries

--- UPDATING OpeningDate Column in Account Table
UPDATE Account SET OpeningDate='2025-11-10 09:30:00' WHERE AccountNumber=100000;
UPDATE Account SET OpeningDate='2026-01-15 10:45:00' WHERE AccountNumber=100001;
UPDATE Account SET OpeningDate='2026-02-01 14:10:00' WHERE AccountNumber=100002;
UPDATE Account SET OpeningDate='2025-12-20 11:20:00' WHERE AccountNumber=100003;
UPDATE Account SET OpeningDate='2026-02-25 16:00:00' WHERE AccountNumber=100004;
UPDATE Account SET OpeningDate='2026-03-01 08:50:00' WHERE AccountNumber=100005;
UPDATE Account SET OpeningDate='2026-03-03 13:30:00' WHERE AccountNumber=100006;

--- UPDATING DueDate & CompletionDate Column for TransactionID 4 in AccountTransaction Table
UPDATE AccountTransaction
SET DueDate = DATEADD(DAY,3,GETDATE()),
CompletionDate = NULL
WHERE TransactionID = 4;

UPDATE AccountTransaction
SET TransactionDateTime = '2026-02-28 10:15:00'
WHERE TransactionID = 1;

UPDATE AccountTransaction
SET TransactionDateTime = '2026-03-01 11:45:00'
WHERE TransactionID = 2;

SELECT * FROM Account;
SELECT * FROM AccountTransaction;
SELECT * FROM OverdueFee;


--- QUESTION 2C
CREATE PROCEDURE InsertCustomer
    @FirstName NVARCHAR(50),
    @MiddleName NVARCHAR(50),
    @LastName NVARCHAR(50),
    @Gender NVARCHAR(10),
    @DateOfBirth DATE,
    @Email NVARCHAR(100),
    @PhoneNumber NVARCHAR(20),
    @Address NVARCHAR(255),
    @Username NVARCHAR(50),
    @PasswordHash NVARCHAR(255)
AS
BEGIN
    INSERT INTO Customer
    (
        FirstName, MiddleName, LastName, Gender, DateOfBirth,
        Email, PhoneNumber, Address, Username, PasswordHash
    )
    VALUES
    (
        @FirstName, @MiddleName, @LastName,
        @Gender, @DateOfBirth, @Email, @PhoneNumber,
        @Address, @Username, @PasswordHash
    );
END;

-- Texting the InsertCustomer Procedure
EXEC InsertCustomer
'James',
NULL,
'Walker',
'Male',
'1993-05-11',
'jwalker@email.com',
'07123456788',
'12 Park Road, London',
'jwalker',
'hash009';

--QUESTION 2D
CREATE PROCEDURE UpdateCustomerDetail
    @CustomerID INT,
    @FirstName NVARCHAR(50),
    @MiddleName NVARCHAR(50),
    @LastName NVARCHAR(50),
    @Gender NVARCHAR(10),
    @DateOfBirth DATE,
    @Email NVARCHAR(100),
    @PhoneNumber NVARCHAR(20),
    @Address NVARCHAR(255)
AS
BEGIN
    UPDATE Customer
    SET
        FirstName = @FirstName,
        MiddleName = @MiddleName,
        LastName = @LastName,
        Gender = @Gender,
        DateOfBirth = @DateOfBirth,
        Email = @Email,
        PhoneNumber = @PhoneNumber,
        Address = @Address
    WHERE CustomerID = @CustomerID;
END;

--Creating procedure for ChangingUsername
CREATE PROCEDURE ChangeUsername
   @CustomerID INT,
   @NewUsername NVARCHAR(50)
AS
BEGIN
    UPDATE Customer
    SET Username = @NewUsername
    WHERE CustomerID = @CustomerID;
END;

--Creating procedure for Reseting password
CREATE PROCEDURE ResetCustomerPassword
    @CustomerID INT,
    @NewPasswordHash NVARCHAR(255)
AS
BEGIN
    UPDATE Customer
    SET PasswordHash = @NewPasswordHash
    WHERE CustomerID = @CustomerID;
END;


--- Testing the Procedures
EXEC UpdateCustomerDetail
1,
'John', 'Nail', 'Doe', 'Male',
'1995-04-12', 'john_new@email.com',
'07000000099', '14 Eccles, Manchester';

EXEC ChangeUsername
1,
'JonnyNail';

EXEC ResetCustomerPassword
1,
'hash200'

select * from Customer


--- Q2e User Defined Function
CREATE FUNCTION CalculatePaymentRatio
(
    @AmountPaid DECIMAL(15,2),
    @FeeAmount DECIMAL(15,2)
)
RETURNS DECIMAL(10,2)
AS
BEGIN
    RETURN 
        CASE 
            WHEN @FeeAmount = 0 THEN 0
            ELSE @AmountPaid / @FeeAmount
        END;
END;

-- Testing the UDF
SELECT 
    OverdueFeeID,
    FeeAmount,
    AmountPaid,
    dbo.CalculatePaymentRatio(AmountPaid, FeeAmount) AS PaymentRatio
FROM OverdueFee;



--- QUESTION 3
CREATE VIEW View_Transactions_OverdueFees
AS
SELECT
    AT.TransactionID,
    AT.AccountNumber,
    A.AccountName,
    A.AccountType,
    AT.TransactionType,
    AT.TransactionAmount,
    AT.TransactionDateTime,
    OFE.OverdueFeeID,
    OFE.FeeAmount,
    OFE.AmountPaid,
    OFE.AmountRemaining,
    R.RepaymentID,
    R.AmountPaid AS RepaymentAmount,
    R.PaymentMethod,
    R.RepaymentDateTime
FROM AccountTransaction AT
LEFT JOIN Account A
    ON AT.AccountNumber = A.AccountNumber
LEFT JOIN OverdueFee OFE
    ON AT.AccountNumber = OFE.AccountNumber
LEFT JOIN Repayment R
    ON OFE.OverdueFeeID = R.OverdueFeeID;


    --- Testing the procedure
SELECT * FROM View_Transactions_OverdueFees;


--- QUESTION 4
CREATE TRIGGER Trigger_CloseLoanAccount
ON AccountTransaction
AFTER INSERT
AS
BEGIN
    UPDATE A
    SET 
        A.AccountStatus = 'Closed',
        A.ClosingDate = SYSUTCDATETIME()
    FROM Account A
    JOIN inserted I
        ON A.AccountNumber = I.AccountNumber
    WHERE 
        A.AccountType IN ('Loan','CreditCard')
        AND I.BalanceAfter = 0;
END;

--- Testing the trigger
INSERT INTO AccountTransaction
(AccountNumber, TransactionType, TransactionAmount, BalanceBefore, BalanceAfter, TransactionDateTime)
VALUES
(100004, 'Payment', 1500, -1500, 0, SYSUTCDATETIME());

SELECT AccountNumber, AccountStatus, ClosingDate
FROM Account
WHERE AccountNumber = 100004;


-- QUESTION 5: Customers whose total payments are less than 50% of their total overdue fees

WITH FeeTotals AS (
    SELECT
        C.CustomerID,
        C.FirstName,
        C.LastName,
        SUM(OFE.FeeAmount) AS TotalFeeAmount,
        SUM(OFE.AmountPaid) AS TotalAmountPaid
    FROM Customer C
    JOIN CustomerAccount CA
        ON C.CustomerID = CA.CustomerID
    JOIN Account A
        ON CA.AccountNumber = A.AccountNumber
    JOIN OverdueFee OFE
        ON A.AccountNumber = OFE.AccountNumber
    GROUP BY
        C.CustomerID,
        C.FirstName,
        C.LastName
)

SELECT
    CustomerID,
    FirstName,
    LastName,
    TotalFeeAmount,
    TotalAmountPaid,
    dbo.CalculatePaymentRatio(TotalAmountPaid, TotalFeeAmount) AS PaidRatio
FROM FeeTotals
WHERE TotalAmountPaid < (0.5 * TotalFeeAmount)
ORDER BY PaidRatio ASC;

--- Count of customers who paid less than 50% of overdue fee
SELECT 
    COUNT(DISTINCT C.CustomerID) AS Customers_Paid_Less_Than_50Percent
FROM Customer C
JOIN CustomerAccount CA
    ON C.CustomerID = CA.CustomerID
JOIN Account A
    ON CA.AccountNumber = A.AccountNumber
JOIN OverdueFee OFE
    ON A.AccountNumber = OFE.AccountNumber
WHERE OFE.AmountPaid < (0.5 * OFE.FeeAmount);


-- QESTION 7, additional queries
-- Query 1: Customers with more than one account

SELECT
    C.CustomerID,
    C.FirstName,
    C.LastName,
    COUNT(CA.AccountNumber) AS NumberOfAccounts
FROM Customer C
JOIN CustomerAccount CA
    ON C.CustomerID = CA.CustomerID
GROUP BY
    C.CustomerID,
    C.FirstName,
    C.LastName
HAVING COUNT(CA.AccountNumber) > 1;

-- Query 2: Number of transactions per account

SELECT
    A.AccountNumber,
    A.AccountName,
    COUNT(AT.TransactionID) AS TotalTransactions
FROM Account A
LEFT JOIN AccountTransaction AT
    ON A.AccountNumber = AT.AccountNumber
GROUP BY
    A.AccountNumber,
    A.AccountName
ORDER BY TotalTransactions DESC;


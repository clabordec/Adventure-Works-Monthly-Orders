USE [AdventureWorks2019]


/*
	Get and compare the previous top ten sales per month
*/
SELECT A.OrderMonth,
       A.TopTenTotal,
       PreviousTopTenTotal = B.TopTenTotal
FROM (
	SELECT OrderMonth,
	       TopTenTotal = SUM(TotalDue)
	FROM (
		SELECT OrderDate,
		       TotalDue,
	               OrderMonth = DATEFROMPARTS(YEAR(OrderDate), MONTH(OrderDate), 1),
	               OrderRank = ROW_NUMBER() OVER(PARTITION BY DATEFROMPARTS(YEAR(OrderDate), MONTH(OrderDate), 1) ORDER BY TotalDue DESC)
		FROM [AdventureWorks2019].[Sales].[SalesOrderHeader]
	) Sales
	WHERE OrderRank <= 10
	GROUP BY OrderMonth
) A
LEFT JOIN (
	SELECT OrderMonth,
		   TopTenTotal = SUM(TotalDue)
	FROM (
		SELECT OrderDate,
			   TotalDue,
			   OrderMonth = DATEFROMPARTS(YEAR(OrderDate), MONTH(OrderDate), 1),
			   OrderRank = ROW_NUMBER() OVER(PARTITION BY DATEFROMPARTS(YEAR(OrderDate), MONTH(OrderDate), 1) ORDER BY TotalDue DESC)
		FROM [AdventureWorks2019].[Sales].[SalesOrderHeader]
	) Sales
	WHERE OrderRank <= 10
	GROUP BY OrderMonth
) B
-- In order to get the previous month, I will need to add the current order month by one, to match the values for the current order month
ON A.OrderMonth = DATEADD(MONTH, 1, B.OrderMonth)
ORDER BY A.OrderMonth


/* 
	Minus out the top ten orders per month and find the total sum of sales and purchases(minus the top ten orders) 
	listed side by side
*/
-- Rank each month based on greatest total amount due for every sale made
WITH SalesCTE AS (
	SELECT OrderDate,
		   OrderMonth = DATEFROMPARTS(YEAR(OrderDate), MONTH(OrderDate), 1),
		   TotalDue,
		   OrderRank = ROW_NUMBER() OVER(PARTITION BY DATEFROMPARTS(YEAR(OrderDate), MONTH(OrderDate), 1) ORDER BY TotalDue DESC)
	FROM [AdventureWorks2019].[Sales].[SalesOrderHeader]
),
-- Get the total of sales for each order month excluding the top ten sales
SalesMinusTopTen AS (
	SELECT OrderMonth,
		   TotalSales = SUM(TotalDue)
	FROM SalesCTE
	WHERE OrderRank > 10
	GROUP BY OrderMonth
),
-- Rank each month based on greatest total amount due for every purchase made
PurchasesCTE AS (
	SELECT OrderDate,
		   OrderMonth = DATEFROMPARTS(YEAR(OrderDate), MONTH(OrderDate), 1),
		   TotalDue,
		   OrderRank = ROW_NUMBER() OVER(PARTITION BY DATEFROMPARTS(YEAR(OrderDate), MONTH(OrderDate), 1) ORDER BY TotalDue DESC)
	FROM [AdventureWorks2019].[Purchasing].[PurchaseOrderHeader]
),
-- Get the total of purchases for each order month excluding the top ten sales
PurchasesMinusTopTen AS (
	SELECT OrderMonth,
		   TotalPurchases = SUM(TotalDue)
	FROM PurchasesCTE
	WHERE OrderRank > 10
	GROUP BY OrderMonth
)
-- Compare the total amount of sales to the total amount of purchases for every month
SELECT pur.OrderMonth,
	   TotalSales = FORMAT(TotalSales, 'C'),
	   TotalPurchases = FORMAT(TotalPurchases, 'C')
FROM SalesMinusTopTen sal INNER JOIN PurchasesMinusTopTen pur
ON sal.OrderMonth = pur.OrderMonth
ORDER BY sal.OrderMonth


/* 
	Generate the results faster with Temp Tables
*/

/*
	SALES
*/
SELECT OrderMonth,
	   TotalSales = SUM(TotalDue)
INTO #Sales
FROM (
	SELECT OrderDate,
		   OrderMonth = DATEFROMPARTS(YEAR(OrderDate), MONTH(OrderDate), 1),
		   TotalDue,
		   OrderRank = ROW_NUMBER() OVER(PARTITION BY DATEFROMPARTS(YEAR(OrderDate), MONTH(OrderDate), 1) ORDER BY TotalDue DESC)
	FROM [AdventureWorks2019].[Sales].[SalesOrderHeader]
) X
WHERE OrderRank > 10
GROUP BY OrderMonth

/*
	PURCHASES
*/
SELECT OrderMonth,
	   TotalPurchases = SUM(TotalDue)
INTO #Purchases
FROM (
	SELECT OrderDate,
		   OrderMonth = DATEFROMPARTS(YEAR(OrderDate), MONTH(OrderDate), 1),
		   TotalDue,
		   OrderRank = ROW_NUMBER() OVER(PARTITION BY DATEFROMPARTS(YEAR(OrderDate), MONTH(OrderDate), 1) ORDER BY TotalDue DESC)
	FROM [AdventureWorks2019].[Purchasing].[PurchaseOrderHeader]
) X
WHERE OrderRank > 10
GROUP BY OrderMonth

/*
	Final Results
	For better readability I formatted the total sales and total purchases columns
*/
SELECT s.OrderMonth,
	   TotalSales = FORMAT(s.TotalSales, 'C'),
	   TotalPurchases = FORMAT(p.TotalPurchases, 'C')
FROM #Sales s INNER JOIN #Purchases p
ON s.OrderMonth = p.OrderMonth
ORDER BY 1


CREATE TABLE #Sales (
	OrderMonth DATE,
	TotalSales MONEY
)

INSERT INTO #Sales (
	OrderMonth,
	TotalSales
)
SELECT OrderMonth,
	   TotalSales = SUM(TotalDue)
FROM (
	SELECT OrderDate,
		   OrderMonth = DATEFROMPARTS(YEAR(OrderDate), MONTH(OrderDate), 1),
		   TotalDue,
		   OrderRank = ROW_NUMBER() OVER(PARTITION BY DATEFROMPARTS(YEAR(OrderDate), MONTH(OrderDate), 1) ORDER BY TotalDue DESC)
	FROM [AdventureWorks2019].[Sales].[SalesOrderHeader]
) X
WHERE OrderRank > 10
GROUP BY OrderMonth


CREATE TABLE #Purchases(
	OrderMonth DATE,
	TotalPurchases MONEY
)

INSERT INTO #Purchases (
	OrderMonth,
	TotalPurchases
)
SELECT OrderMonth,
	   TotalPurchases = SUM(TotalDue)
FROM (
	SELECT OrderDate,
		   OrderMonth = DATEFROMPARTS(YEAR(OrderDate), MONTH(OrderDate), 1),
		   TotalDue,
		   OrderRank = ROW_NUMBER() OVER(PARTITION BY DATEFROMPARTS(YEAR(OrderDate), MONTH(OrderDate), 1) ORDER BY TotalDue DESC)
	FROM [AdventureWorks2019].[Purchasing].[PurchaseOrderHeader]
) X
WHERE OrderRank > 10
GROUP BY OrderMonth


SELECT S.OrderMonth,
	   TotalSales = FORMAT(S.TotalSales, 'C'),
	   TotalPurchases = FORMAT(P.TotalPurchases, 'C')
FROM #Sales S INNER JOIN #Purchases P
ON S.OrderMonth = P.OrderMonth

DROP TABLE #Sales
DROP TABLE #Purchases

--Step1: Get the overview of data
SELECT * FROM sales_data

--Step2: Inspecting unique values, understand columns
SELECT DISTINCT status FROM sales_data
	--- There are six statuses for the orders: Resolved, On Hold, Cancelled, Shipper, Disputed, In Process

SELECT DISTINCT year_id FROM sales_data
	--- This sales data come from the years of 2003, 2004, and 2005

SELECT DISTINCT productline FROM sales_data
	--- Product Line: Trains, Motorcycles, Ships, Trucks and Buses, Vintage Cars, Classic Cars, Planes

SELECT DISTINCT country FROM sales_data 
	--- 19 countries

SELECT DISTINCT dealsize FROM sales_data 
	--- Large, Medium, Small

SELECT DISTINCT territory FROM sales_data 
	--- EMEA, APAC, Japan, NA


--Step3: Start to Analyze
	--- Explore the sales by product line
SELECT DISTINCT productline, SUM(sales) AS total_sales
FROM sales_data
GROUP BY productline
ORDER BY SUM(sales) DESC
	---Comment: The top3 are:  Classic Cars, Vintage Cars, Motorcycles. The lowest position: Trains


	--- Explore the sales by year
SELECT DISTINCT year_id, SUM(sales) AS total_sales
FROM sales_data
GROUP BY year_id
ORDER BY SUM(sales) DESC
	---Comment1: The highest revenue is in 2004, which is two and a half times compared to 2005 revenue. It seems a little strange so we need to check the months in those years.
SELECT DISTINCT month_id
FROM sales_data
WHERE year_id = 2003
ORDER BY month_id --- Sales records the whole year (12 months)

SELECT DISTINCT month_id
FROM sales_data
WHERE year_id = 2004
ORDER BY month_id --- Sales records the whole year (12 months)

SELECT DISTINCT month_id
FROM sales_data
WHERE year_id = 2005
ORDER BY month_id --- Sales records just the first 5 months.
	---Comment2: Because the sales in 2005 just recorded in the first 5 months, we can't say that there is a drop from 2004 to 2005. However, we can compare the revenue in months of different years.


	--- Explore the sales by deal size
SELECT DISTINCT dealsize, SUM(sales) AS total_sales
FROM sales_data
GROUP BY dealsize
ORDER BY SUM(sales) DESC
	--- Comment: The medium size generates the most revenue, so the company can consider to focus more on it.


	--- In which month does the company achieve the highest revenue? How much was earned that month?
SELECT year_id, month_id, SUM(sales) AS total_sales, COUNT(ordernumber) AS total_orders
FROM sales_data
WHERE year_id = 2003
GROUP BY year_id, month_id
ORDER BY SUM(sales) desc
	--- Comment1: In 2003, the top 3 months are: 11, 10, 9 and the highest figure is 1029837 with 296 orders.

SELECT year_id, month_id, SUM(sales) AS total_sales, COUNT(ordernumber) AS total_orders
FROM sales_data
WHERE year_id = 2004
GROUP BY year_id, month_id
ORDER BY SUM(sales) desc
	--- Comment2: In 2004, the top 3 months are: 11, 10, 8 and the highest figure is 1089048 with 301 orders.

SELECT year_id, month_id, SUM(sales) AS total_sales, COUNT(ordernumber) AS total_orders
FROM sales_data
WHERE year_id = 2005
GROUP BY year_id, month_id
ORDER BY SUM(sales) desc
	--- Comment3: In the first 5 months of 2005, the highest revenue comes from May, the total sales is 457861 with 120 orders


	--- According to the previous figures, November seems the top around years. Let's figure out what product, quantity of November's orders.
SELECT month_id, productline, SUM(sales) as total_sales, COUNT(ordernumber) AS total_orders, SUM(quantityordered) AS quantity_ordered
FROM sales_data
WHERE year_id = 2003 AND month_id = 11
GROUP BY month_id, productline
ORDER BY SUM(sales) DESC, COUNT(ordernumber) DESC
	--- Comment1: The top 3 sold products in November (2003) are the same as the best-seller product list: Classic Cars, Vintage Cars, Trucks and Buses

SELECT month_id, productline, SUM(sales) as total_sales, COUNT(ordernumber) AS total_orders, SUM(quantityordered) AS quantity_ordered
FROM sales_data
WHERE year_id = 2004 AND month_id = 11
GROUP BY month_id, productline
ORDER BY SUM(sales) DESC, COUNT(ordernumber) DESC
	--- Comment1: The top 3 sold products in November (2004) are slightly different from 2003: Classic Cars, Vintage Cars, Motorcycles


	--- Explore about the company's customers by using RFM (Recency - Frequency - Monetary) analysis
DROP TABLE IF EXISTS #rfm_summary
WITH RFM AS (
	SELECT
		customername,
		MAX(orderdate) AS last_order_date,
		COUNT(ordernumber) AS frequency,
		SUM(sales) AS monetary_total,
		AVG(sales) AS monetary_avg,
		DATEDIFF(DD, MAX(orderdate), (SELECT MAX(orderdate) FROM sales_data)) AS recency --- to calculate the days between the last_order_date and the max_date of the data
	FROM sales_data
	GROUP BY customername
	) ---Comment1: Frequency shows how often the customers purchase, Monetary shows how much they spend, & Recency shows how long the customers' last purchase was
,
	--- Let's break down the rfm into 4 equal groups for better picturing the customers' behaviors.
rfm_tile AS (
	SELECT
		RFM.*,
		NTILE(4) OVER (ORDER BY recency) rfm_recency,
		NTILE(4) OVER (ORDER BY frequency DESC) rfm_frequency,
		NTILE(4) OVER (ORDER BY monetary_total DESC)  rfm_monetary
	FROM RFM
	) ---Comment2:
		-- rfm_recency: the smaller number is, the closer the order date is to the max date. It means that the customers numbered 1 are recent buyers, and the ones numbered 4 are far-time buyers.
		-- rfm_frequency: the smaller number is, the higher the frequency the customers buy products. It means that customers numbered 1 are more-often buyers, and the ones numbered 4 are less-often buyers.
		-- rfm_monetary: the smaller number is, the more money customers spend. It means that customers numbered 1 are more monetary buyers, and the ones numbered 4 are less monetary buyers.


	--- Now, we'll gather those figures of recency, frequency, monetary for each customer to observe, evaluate, and segment based on these metrics.
SELECT 
	rt.*, (rfm_recency*100 + rfm_frequency*10 + rfm_monetary) AS rfm_score
INTO #rfm_summary
FROM rfm_tile rt


	--- Look at the RFM score to get the overview
SELECT DISTINCT rfm_score
FROM #rfm_summary

	--- Segment customers based on their RFM scores
SELECT CUSTOMERNAME , rfm_recency, rfm_frequency, rfm_monetary, rfm_score,
	(CASE
		WHEN CAST(rfm_score AS varchar) LIKE (111) THEN 'best' --(Top scores in every category - recency, frequency, monetary)
		WHEN CAST(rfm_score AS varchar) LIKE '%%1' THEN 'whales' --High monetary value
		WHEN CAST(rfm_score AS varchar) LIKE '22%' 
			OR CAST(rfm_score AS varchar) LIKE '23%' 
			OR CAST(rfm_score AS varchar) LIKE '24%' THEN 'potential' --Recently buy with moderate frequency of buying
		WHEN CAST(rfm_score AS varchar) LIKE '44%' 
			OR CAST(rfm_score AS varchar) LIKE '4%4' 
			OR CAST(rfm_score AS varchar) LIKE '%44' THEN 'lost' --Long time no purchase and the last purchase was long a go
		WHEN CAST(rfm_score AS varchar) LIKE '1%%' 
			AND CAST(rfm_score AS varchar) LIKE '%4%' THEN 'new' --Recently buy with low frequency
		WHEN CAST(rfm_score AS varchar) LIKE '%1%' 
			AND (CAST(rfm_score AS varchar) LIKE '1%%' 
				OR CAST(rfm_score AS varchar) LIKE '2%%') THEN 'loyal' -- High frquency with quite-recent purchases
		WHEN CAST(rfm_score AS varchar) LIKE '32%' 
			OR CAST(rfm_score AS varchar) LIKE '33%' 
			OR CAST(rfm_score AS varchar) LIKE '34%' 
			OR CAST(rfm_score AS varchar) LIKE '42%' 
			OR  CAST(rfm_score AS varchar) LIKE '43%' THEN 'at-risk' -- Low recency and low frequency, which means those customers may leave
	END) AS rfm_segment
FROM #rfm_summary rs



	--- Which product line is most ordered by a particular country? Which product line generates the highest revenue by country?
SELECT DISTINCT country, 
		productline, 
		SUM(quantityordered) AS total_quantity, 
		RANK() OVER (PARTITION BY country ORDER BY SUM(quantityordered) DESC) AS ranking_quantity,
		SUM(sales) AS total_sales, 
		RANK() OVER (PARTITION BY country ORDER BY SUM(sales) DESC) AS ranking_sales
FROM sales_data
GROUP BY country, productline
ORDER BY country, SUM(quantityordered) DESC, SUM(sales) DESC

-- Q1 - Provide list of market for the customer 'Atliq Exclusive' operates their business in 'APAC' region
SELECT distinct(market), sub_zone FROM dim_customer WHERE customer='Atliq Exclusive' AND region = 'APAC';

-- Q2 -- percentage of unique product increase in 2021 vs. 2020
/* SQL concepts used 
Sub query, CTE, count, distinct, round
*/
WITH unique_product AS (
SELECT  
	COUNT(DISTINCT(fs1.product_code)) AS unique_products_2021, 
    (SELECT COUNT(DISTINCT(product_code)) FROM fact_sales_monthly WHERE fiscal_year = '2020') as unique_products_2020    
FROM 
	fact_sales_monthly fs1 
 WHERE 
 	fs1.fiscal_year = '2021' )
SELECT unique_products_2021, unique_products_2020, round((((unique_products_2021-unique_products_2020)/unique_products_2020)*100),2) AS 'Percentage_chg' FROM unique_product;

-- Q3 Unique product counts for each segment and sort them in descending order of product counts
/* SQL concepts used 
count, group by and order by
*/
SELECT segment, count(distinct(product_code)) as product_count from dim_product group by segment order by product_count desc;

-- Q4 Which segment had the most increase in unique products in 2021 vs 2020 
/* SQL concepts used 
count, group by and order by
Inner join, cross join
CTE
*/
WITH count_2020 AS (
	SELECT dp.segment as segment1, count(distinct(fs.product_code)) AS product_count_2020 
	FROM
		dim_product dp 
	INNER JOIN 
		fact_sales_monthly fs ON dp.product_code = fs.product_code	
	WHERE 
		fs.fiscal_year = '2020'
	GROUP BY 
		dp.segment  
),
count_2021 AS (
	SELECT dp.segment as segment2, count(distinct(fs.product_code)) AS product_count_2021 
	FROM
		dim_product dp 
	INNER JOIN 
		fact_sales_monthly fs ON dp.product_code = fs.product_code	
	WHERE 
		fs.fiscal_year = '2021'
	GROUP BY 
		dp.segment 
)
SELECT segment1 as 'Segment', product_count_2020, product_count_2021, (product_count_2021-product_count_2020) AS 'Difference' FROM count_2020 
CROSS JOIN count_2021 ON segment1 = segment2
ORDER BY Difference DESC;

-- Q5 products that have the highest and lowest manufacturing costs
/*
Inner join, Sub Query
Min, Max functions
*/
SELECT mc.product_code, dp.product, mc.manufacturing_cost as 'manufacturing_cost' FROM fact_manufacturing_cost mc
INNER JOIN dim_product dp ON mc.product_code = dp.product_code
WHERE mc.manufacturing_cost IN ((SELECT max(manufacturing_cost) from fact_manufacturing_cost) , (SELECT MIN(manufacturing_cost) from fact_manufacturing_cost));

-- Q6 The top 5 customers who received an average high pre_invoice_discount_pct for the fiscal year 2021 and in the Indian market.
/* SQL concepts used 
Limit, group by and order by
Inner join
*/
SELECT dc.customer_code,dc.customer, round(avg(pre_invoice_discount_pct),2) as 'avg_discount_percentage' FROM fact_pre_invoice_deductions fpd 
INNER JOIN dim_customer dc ON fpd.customer_code = dc.customer_code
WHERE fiscal_year= '2021' AND dc.market = 'India'
GROUP BY dc.customer_code,dc.customer
ORDER BY avg_discount_percentage desc
LIMIT 5;

-- Q7 Gross sales amount for the customer “Atliq Exclusive” for each month
/* SQL concepts used 
sum, group by and order by
Date functions
multiple joins
CTE
*/
SELECT monthname(fsm.date) as 'Month', year(fsm.date) as 'year', SUM(fgp.gross_price*fsm.sold_quantity) as 'gross sales amount' FROM fact_sales_monthly fsm
INNER JOIN fact_gross_price fgp ON fsm.product_code = fgp.product_code
INNER JOIN dim_customer dc ON fsm.customer_code = dc.customer_code
WHERE dc.customer = 'Atliq Exclusive'
GROUP BY (fsm.date);

-- Q8 In which quarter of 2020, got the maximum total_sold_quantity?
/* SQL concepts used 
sum, Case, Limit group by and order by
Date functions
CTE's
*/
WITH T_Quater AS(
SELECT fsm.fiscal_year, fsm.date as 'f_date', fsm.sold_quantity as 'total_sold_quantity',
(CASE 
	WHEN ((MONTH(fsm.date) >=  09) and (month(fsm.date) <= 11)) THEN '1'
    WHEN ((MONTH(fsm.date) =  02) or (month(fsm.date) = 01) or (month(fsm.date) = 12)) THEN '2'
    WHEN ((MONTH(fsm.date) >=  03) and (month(fsm.date) <= 05)) THEN '3'
    WHEN ((MONTH(fsm.date) >=  06) and (month(fsm.date) <= 08)) THEN '4'
END) as 'Quater'  
FROM fact_sales_monthly fsm WHERE fsm.fiscal_year ='2020' ) 
SELECT q.Quater, SUM(q.total_sold_quantity) as 'total_sold_quantity' FROM T_Quater AS q
GROUP BY q.Quater
ORDER BY total_sold_quantity DESC 
LIMIT 1;

-- Q9 Which channel helped to bring more gross sales in the fiscal year 2021 and the percentage of contribution?
/* SQL concepts used 
sum, Case, round, Limit group by and order by
sub query
Multiple joins
CTE's
*/
WITH gross_sales AS (
SELECT dc.channel, fsm.fiscal_year, SUM(fgp.gross_price * fsm.sold_quantity) AS 'gross_sales_mln'
FROM  fact_sales_monthly fsm
INNER JOIN fact_gross_price fgp ON fsm.product_code = fgp.product_code 
INNER JOIN dim_customer dc ON fsm.customer_code = dc.customer_code
WHERE fsm.fiscal_year = '2021'
GROUP BY dc.channel 
)
SELECT gs.channel,round(gs.gross_sales_mln,2) AS 'total_gross_sales', round(((gs.gross_sales_mln/(SELECT sum(gross_sales_mln) FROM gross_sales)) *100),2) AS 'Percentage'
FROM gross_sales gs 
ORDER BY gs.gross_sales_mln DESC
LIMIT 1; 

-- Q10 Top 3 products in each division that have a high total_sold_quantity in the fiscal_year 2021

/* SQL concepts used 
sum, group by and order by
sub query
inner join
CTE's, window function(rank)
*/
WITH rank_by AS(
SELECT dp.division AS 'Division', dp.product AS 'Product', SUM(fsm.sold_quantity) AS 'Total_sold_quantity' 
FROM fact_sales_monthly fsm
INNER JOIN dim_product dp ON fsm.product_code = dp.product_code
WHERE fsm.fiscal_year = '2021'
GROUP BY dp.division,  dp.product 
),
final as (SELECT Division, Product, Total_sold_quantity, RANK() OVER(PARTITION BY Division ORDER BY Total_sold_quantity DESC) AS 'Rank_order'
FROM rank_by) 
SELECT * FROM final f WHERE f.Rank_order <=3

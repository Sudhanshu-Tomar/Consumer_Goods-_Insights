

-- 1. Provide the list of markets in which customer "Atliq Exclusive" operates its business in the APAC region.

SELECT DISTINCT market 
FROM dim_customer
WHERE customer = "Atliq Exclusive" AND region = "APAC" ;

/* 2. What is the percentage of unique product increase in 2021 vs. 2020? The final output contains these fields, 
unique_products_2020, unique_products_2021 percentage_chg */ 



WITH result AS 
(select fiscal_year , count(distinct product_code) as products
FROM fact_gross_price  
GROUP BY 1 ) 
SELECT 
  a.products  as unique_products_2020 , 
  b.products  as unique_products_2021 , 
  ROUND((( b.products -  a.products ) /  a.products)*100,2)  AS percentage_change
FROM result a   
CROSS JOIN result b 
WHERE a.fiscal_year = 2020 
AND b.fiscal_year = 2021 ; 


 /*3.Provide a report with all the unique product counts for each segment and sort them in descending order of product counts.
 The final output contains 2 fields, segment, product_count */ 
 
 SELECT segment , count(distinct product_code)  as product_count 
 FROM dim_product 
 GROUP BY 1 
 ORDER BY 2 DESC ; 
 
 /*4.Follow-up: Which segment had the most increase in unique products in 2021 vs 2020? 
    The final output contains these fields, segment ,  product_count_2020 ,  product_count_2021 difference. */ 
    
 WITH result AS 
 (SELECT     dp.segment , fgp.fiscal_year , COUNT(DISTINCT fgp.product_code)  AS  products 
 FROM fact_gross_price fgp 
 LEFT JOIN 
 dim_product dp 
 USING (product_code)
 GROUP BY 1 ,2 ) ,
 final as 
 (SELECT 
       a.segment , a.products as products_2020 , b.products as products_2021  , b.products - a.products  as diffrence 
 FROM result a 
 JOIN result b 
 on a.segment = b.segment 
 where a.fiscal_year = '2020' and b.fiscal_year = '2021') 
 
 select 
      segment , products_2020 as product_count_2020 , products_2021 as product_count_2021 
 from final 
 where diffrence = (select max(diffrence) from final) ; 
 
 
 
 /* 5. Get the products that have the highest and lowest manufacturing costs. The final output should contain these fields,
 product_code ,  product , manufacturing_cost    */
 
 SELECT fmc.product_code  , dp.product , fmc.manufacturing_cost as manufacturing_cost 
 FROM fact_manufacturing_cost fmc
 LEFT JOIN 
 dim_product dp
 USING 
 (product_code)
 where  manufacturing_cost in (( select max(manufacturing_cost) from fact_manufacturing_cost) , 
       (select min(manufacturing_cost) from fact_manufacturing_cost) ) ; 
       
       
       
       
/* 6. Generate a report which contains the top 5 customers who received an average high pre_invoice_discount_pct for the 
fiscal year 2021 and in the Indian market. The final output contains these fields, 
customer_code , customer , average_discount_percentage   */
       
SELECT d.customer_code , 
       c.customer      , 
       ROUND(AVG(d.pre_invoice_discount_pct),4) as pre_invoice_discount_pct
FROM fact_pre_invoice_deductions d
left join 
dim_customer c 
using (customer_code) 
where d.fiscal_year = 2021  and c.market = 'India'
group by 1,2 
order by 3 desc 
limit 5 ;
       
       
-- 7. Get the complete report of the Gross sales amount for the customer “Atliq Exclusive” for each month .
--  This analysis helps to get an idea of low and high-performing months and take strategic decisions. 
-- The final report contains these columns: Month , Year , Gross sales Amount       



select month(fsm.date) as months  , year(fsm.date) as years , ROUND(sum((fsm.sold_quantity *fgp.gross_price) ),2)  as gross_sales_amount
from fact_sales_monthly fsm
left join 
fact_gross_price fgp
on 
fsm.product_code = fgp.product_code
left join 
dim_customer dcc
on 
fsm.customer_code = dcc.customer_code
where dcc.customer = 'Atliq Exclusive'
group by 1 ,2
ORDER BY 3 DESC;



-- 8. In which quarter of 2020, got the maximum total_sold_quantity? The final output contains these fields sorted by the total_sold_quantity, Quarter total_sold_quantity


WITH temp_table AS (
  SELECT date,month(date_add(date,interval 4 month)) AS period, fiscal_year,sold_quantity 
FROM fact_sales_monthly
)
SELECT CASE 
   when period/3 <= 1 then "Q1"
   when period/3 <= 2 and period/3 > 1 then "Q2"
   when period/3 <=3 and period/3 > 2 then "Q3"
   when period/3 <=4 and period/3 > 3 then "Q4" END quarter,
 round(sum(sold_quantity)/1000000,2) as total_sold_quanity_in_millions FROM temp_table
WHERE fiscal_year = 2020
GROUP BY 1
ORDER BY 2 DESC ;



-- 9. Which channel helped to bring more gross sales in the fiscal year 2021 and the percentage of contribution? The final output contains these fields, channel gross_sales_mln percentage

WITH temp_table AS (
      SELECT c.channel,sum(s.sold_quantity * g.gross_price) AS total_sales
  FROM
  fact_sales_monthly s 
  JOIN fact_gross_price g ON s.product_code = g.product_code
  JOIN dim_customer c ON s.customer_code = c.customer_code
  WHERE s.fiscal_year= 2021
  GROUP BY c.channel
  ORDER BY total_sales DESC
)
SELECT 
  channel,
  round(total_sales/1000000,2) AS gross_sales_in_millions,
  round(total_sales/(sum(total_sales) OVER())*100,2) AS percentage 
FROM temp_table ;

-- 10. Get the Top 3 products in each division that have a high total_sold_quantity in the fiscal_year 2021? 
-- The final output contains these fields, division , product_code , product total_sold_quantity rank_order 

WITH temp_table AS (
    select division, s.product_code, concat(p.product,"(",p.variant,")") AS product , sum(sold_quantity) AS total_sold_quantity,
    rank() OVER (partition by division order by sum(sold_quantity) desc) AS rank_order
 FROM
 fact_sales_monthly s
 JOIN dim_product p
 ON s.product_code = p.product_code
 WHERE fiscal_year = 2021
 GROUP BY 1,2,3
)
SELECT * FROM temp_table
WHERE rank_order IN (1,2,3);

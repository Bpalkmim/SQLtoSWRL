SELECT O_ORDERPRIORITY, 
COUNT(*) AS ORDER_COUNT 
FROM 
orders

WHERE 
o_orderdate >= date '1993-07-01' AND 
o_orderdate < date '1993-07-01' + interval '3 month' AND 
l_orderkey = o_orderkey AND 
l_commitdate < l_receiptdate
GROUP BY 
O_ORDERPRIORITY
ORDER BY 
O_ORDERPRIORITY;
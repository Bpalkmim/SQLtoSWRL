select
l_returnflag,
l_linestatus,
sum( l_quantity) as sumqty,
sum( l_extendedprice) as sumbaseprice,
sum( l_extendedprice * (1 - l_discount ) ) as sumdiscprice,
sum( l_extendedprice * (1 - l_discount ) * (1 + l_tax ) ) as sumcharge,
avg ( l_quantity ) as avgqty,
avg ( l_extendedprice ) as avgprice,
avg ( l_discount ) as avgdisc,
count ( * ) as countorder
from
lineitem l
where
l_shipdate <= date '1998-12-01' - interval '87 days'
group by
l_returnflag,
l_linestatus
order by
l_returnflag,
l_linestatus;
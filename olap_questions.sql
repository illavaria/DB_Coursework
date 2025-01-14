--in which city more orders were made
select city_name, region, count(fo.order_id) as number_of_orders, sum(fo.total)
from factOrders fo
join dimCity dc on fo.city_id = dc.city_id
group by dc.city_id, dc.city_name, dc.region
order by number_of_orders desc;

--which brand products are put in a cart more often and in which month
select b.brand_name, count(f.product_in_cart_id) as all_count,
    sum(case when d.month = 1 then 1 else 0 end) as jan,
    sum(case when d.month = 2 then 1 else 0 end) as feb,
    sum(case when d.month = 3 then 1 else 0 end) as mar,
    sum(case when d.month = 4 then 1 else 0 end) as apr,
    sum(case when d.month = 5 then 1 else 0 end) as may,
    sum(case when d.month = 6 then 1 else 0 end) as jun,
    sum(case when d.month = 7 then 1 else 0 end) as jul,
    sum(case when d.month = 8 then 1 else 0 end) as aug,
    sum(case when d.month = 9 then 1 else 0 end) as sep,
    sum(case when d.month = 10 then 1 else 0 end) as oct,
    sum(case when d.month = 11 then 1 else 0 end) as nov,
    sum(case when d.month = 12 then 1 else 0 end) as dec
from factProductInCart f
join dimBrand b using(brand_id)
join dimDate d on f.added_date_id = d.date_id
group by b.brand_id, b.brand_name
order by all_count desc;

--which category of products is the most popular in each region (by sum of quantity ordered)
with cte as(
	select p.category, c.region, sum(pb.quantity) as total_quantity, 
		dense_rank() over (partition by c.region order by sum(pb.quantity) desc) as rank
	from factOrders fo
	join dimCity c on c.city_id = fo.city_id
	join dimProductBridge pb on pb.product_bridge_id = fo.product_bridge_id
	join dimProduct p on p.product_id = pb.product_id
	group by c.region, p.category
)
select category, region, total_quantity
from cte
where rank = 1;

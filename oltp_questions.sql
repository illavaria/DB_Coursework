--in which city more orders were made
select ci.city_name, ci.region, count(oi.order_id) as number_of_orders, sum(oi.total)
from order_info oi
join customer c using(customer_id)
join address a using(address_id)
join city ci using(city_id)
group by ci.city_id, ci.city_name, ci.region
order by number_of_orders desc;

--which brand products are put in a cart more often and in which month
select b.brand_name, count(*) as all_count,
    sum(case when extract(month from c.added_date) = 1 then 1 else 0 end) as jan,
    sum(case when extract(month from c.added_date) = 2 then 1 else 0 end) as feb,
    sum(case when extract(month from c.added_date) = 3 then 1 else 0 end) as mar,
    sum(case when extract(month from c.added_date) = 4 then 1 else 0 end) as apr,
    sum(case when extract(month from c.added_date) = 5 then 1 else 0 end) as may,
    sum(case when extract(month from c.added_date) = 6 then 1 else 0 end) as jun,
    sum(case when extract(month from c.added_date) = 7 then 1 else 0 end) as jul,
    sum(case when extract(month from c.added_date) = 8 then 1 else 0 end) as aug,
    sum(case when extract(month from c.added_date) = 9 then 1 else 0 end) as sep,
    sum(case when extract(month from c.added_date) = 10 then 1 else 0 end) as oct,
    sum(case when extract(month from c.added_date) = 11 then 1 else 0 end) as nov,
    sum(case when extract(month from c.added_date) = 12 then 1 else 0 end) as dec
from cart_product c
join product p using(product_id)
join brand b using(brand_id)
group by b.brand_id, b.brand_name
order by all_count desc;

--which category of products is the most popular in each region (by sum of quantity ordered)
with cte as(
	select category_name as category, ci.region, sum(op.quantity) as total_quantity,
		dense_rank() over (partition by ci.region order by sum(op.quantity) desc) as rank
	from order_info oi
	join customer c using (customer_id)
	join address a using (address_id)
	join city ci on ci.city_id = a.city_id
	join order_product op on op.order_id = oi.order_id
	join product p on p.product_id = op.product_id
	join category using(category_id)
	group by ci.region, category.category_id, category_name
)
select category, region, total_quantity
from cte
where rank = 1;

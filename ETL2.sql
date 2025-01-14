drop extension if exists postgres_fdw cascade;
set lc_monetary = 'be_BY.ISO8859-5'; 
create extension if not exists postgres_fdw;

create server if not exists oltp_fdw foreign data wrapper postgres_fdw 
options (host '127.0.0.1', port '5432', dbname 'db_coursework');

create user mapping if not exists for current_user server oltp_fdw 
options (user 'postgres', password 'postgres');

--select * from factOrders;

create schema if not exists staging;
drop  foreign table if exists staging.City;

create foreign table staging.City(
	city_id integer,
	city_name text,
	region text
)
server oltp_fdw
options (schema_name 'public', table_name 'city');

drop  foreign table if exists staging.Brand;
create foreign table staging.Brand(
	brand_id integer,
	brand_name text
)
server oltp_fdw
options (schema_name 'public', table_name 'brand');

drop  foreign table if exists staging.Product;
create foreign table staging.Product(
	product_id integer,
	product_name text,
	description text,
	brand_id integer,
	color text,
	product_size text,
	weight decimal,
	material text,
	unit_price money,
	category_id integer,
	is_available boolean
)
server oltp_fdw
options (schema_name 'public', table_name 'product');

drop  foreign table if exists staging.Category;
create foreign table staging.Category(
	category_id integer,
	category_name text
)
server oltp_fdw
options (schema_name 'public', table_name 'category');

drop  foreign table if exists staging.Customer;
create foreign table staging.Customer(
	customer_id integer,
	username text,
	user_password text,
	phone text,
	email text,
	address_id integer
)
server oltp_fdw
options (schema_name 'public', table_name 'customer');

drop  foreign table if exists staging.Address;
create foreign table staging.Address(
	address_id integer,
	apartment integer,
	house text,
	street text,
	city_id integer
)
server oltp_fdw
options (schema_name 'public', table_name 'address');

drop  foreign table if exists staging.Cart;
create foreign table staging.Cart(
	customer_id integer,
	product_id integer,
	quantity integer,
	added_date date
)
server oltp_fdw
options (schema_name 'public', table_name 'cart_product');

drop  foreign table if exists staging.Orders;
create foreign table staging.Orders(
	order_id integer, 
	product_key integer, 
	quantity integer,
	customer_key integer, 
	city_name text, 
	city_region text, 
	order_date date, 
	delivered_date date, 
	total money, 
	status text
)
server oltp_fdw
options (schema_name 'public', table_name 'v_orders');

insert into dimCity(city_name, region)
	select distinct cr.city_name, cr.region
	from staging.city cr
	left join dimCity c on c.city_name = cr.city_name and c.region = cr.region
	where c.city_id is null;

--select * from dimCity;

insert into dimBrand(brand_name)
	select distinct br.brand_name
	from staging.brand br
	left join dimBrand b on b.brand_name = br.brand_name
	where b.brand_id is null;
	
--select * from dimBrand;

insert into dimProduct(product_key, product_name, description, color, product_size, weight, material, unit_price, category, is_available)
	select pr.product_id, pr.product_name, pr.description, pr.color, pr.product_size, pr.weight, pr.material, pr.unit_price, c.category_name, pr.is_available
	from staging.Product pr
	inner join staging.category c on c.category_id = pr.category_id
	left join dimProduct p on p.product_key = pr.product_id
	where p.product_id is null;
	
update dimProduct dp
	set is_available = p.is_available --is available is most likely to change, so there's no point to overwrite other columns
	from staging.Product p
	where dp.product_key = p.product_id and dp.is_available <> p.is_available;

update dimProduct dp
	set unit_price = p.unit_price --unit_price is most likely to change, so there's no point to overwrite other columns
	from staging.Product p
	where dp.product_key = p.product_id and dp.unit_price <> p.unit_price;

update dimProduct dp
	set product_name = p.product_name, description = p.description, color = p.color, product_size = p.product_size, 
	weight = p.weight, material = p.material, category = c.category_name
	from staging.Product p
	inner join staging.Category c on c.category_id = p.category_id
	where dp.product_key = p.product_id and (dp.product_name <> p.product_name or dp.description <> p.description 
											 or dp.color <> p.color or dp.product_size <> p.product_size 
											 or dp.weight <> p.weight or dp.material <> p.material or dp.category <> c.category_name);
/*update dimProduct dp
set unit_price = '13'
where product_id = 1;*/
--select * from dimProduct;

with changes as (
  select u.*
  from (
	  select c.customer_id as customer_key, c.username, c.phone, c.email, a.apartment, a.house, a.street
  	from staging.Customer c
  	join staging.Address a on c.address_id = a.address_id
  ) u
  left join dimCustomer e on u.customer_key = e.customer_key
  where e.customer_key is null or (e.is_current = true and (u.username <> e.username or u.phone <> e.phone 
															or u.email <> e.email or u.apartment <> e.apartment 
															or u.house <> e.house or u.street <> e.street))
),
insert_current_date as (
  insert into dimDate (day, month, year, quater, day_of_week, time)
  	select extract(day from current_date), extract(month from current_date), extract(year from current_date),
			extract(quarter from current_date), extract(dow from current_date), current_time
  	on conflict (day, month, year, time) do nothing
  	returning date_id
),
current_date_id as (
	select coalesce ((select date_id from insert_current_date), 
	(select date_id 
	 from dimDate 
	 where day = extract(day from current_date) and month = extract(month from current_date) 
	 and year = extract(year from current_date) and time = current_time)
	) as date_id
),
update_customer as
(
	update dimCustomer
	set is_current = false, end_date_id = (select date_id from current_date_id)
	where customer_key in (select customer_key from changes) and is_current = true
)
insert into dimCustomer (customer_key, username, phone, email, apartment, house, street, start_date_id, is_current)
	select customer_key, username, phone, email, apartment, house, street, (select date_id from current_date_id), true
	from changes;
	
--select * from dimCustomer;
/* update dimCustomer
	set apartment = 123
	where customer_key = 1 */
	
	
insert into dimDate (day, month, year, quater, day_of_week)
    	select cd.day, cd.month, cd.year, cd.quarter, cd.day_of_week    
		from (
			select distinct extract(day from c.added_date) as day, 
                        extract(month from c.added_date) as month, 
                        extract(year from c.added_date) as year, 
                        extract(quarter from c.added_date) as quarter, 
                        extract(dow from c.added_date) as day_of_week
        	from staging.Cart c
		) cd
        left join dimDate d on d.day = cd.day and d.month = cd.month and d.year = cd.year and d.time is null
        where d.date_id is null;


with insert_current_date as (
  insert into dimDate (day, month, year, quater, day_of_week, time)
  	select extract(day from current_date), extract(month from current_date), extract(year from current_date),
			extract(quarter from current_date), extract(dow from current_date), current_time
  	on conflict (day, month, year, time) do nothing
  	returning date_id
),
current_date_id as (
	select coalesce ((select date_id from insert_current_date), 
	(select date_id 
	 from dimDate 
	 where day = extract(day from current_date) and month = extract(month from current_date) 
	 and year = extract(year from current_date) and time = current_time)
	) as date_id
),
removed_or_updated_products as (
   	select p.product_in_cart_id, p.customer_id, p.product_id
	from factProductInCart p
	left join dimProduct dp on dp.product_id = p.product_id
	left join dimCustomer dc on dc.customer_id = p.customer_id
	left join staging.Cart c on c.product_id = dp.product_key and c.customer_id = dc.customer_key and dc.is_current = true
	where p.is_current = true and (c.product_id is null or p.quantity <> c.quantity)
),
update_removed as (
    update factProductInCart
        set is_current = false, end_date_id = (select date_id from current_date_id)
    where product_in_cart_id in (select product_in_cart_id from removed_or_updated_products)
)
insert into factProductInCart (customer_id, product_id, brand_id, quantity, added_date_id, start_date_id, is_current)
    select dc.customer_id, p.product_id, b.brand_id, c.quantity, d.date_id, (select date_id from current_date_id), true
    from staging.Cart c
	join staging.Product pr on pr.product_id = c.product_id
 	join staging.Brand br on pr.brand_id = br.brand_id
    join dimBrand b on b.brand_name = br.brand_name
    join dimProduct p on c.product_id = p.product_key
	join dimCustomer dc on dc.customer_key = c.customer_id and dc.is_current = true
    left join dimDate d on d.day = extract(day from c.added_date) and d.month = extract(month from c.added_date)
						and d.year = extract(year from c.added_date) and d.time is null
    left join factProductInCart fpc on fpc.customer_id = dc.customer_id and fpc.product_id = p.product_id and fpc.is_current = true
    where fpc.product_in_cart_id is null or fpc.quantity <> c.quantity;

--select * from factProductInCart;
/* update factProductInCart
	set quantity = 15
	where product_in_cart_id = 14;
	delete from factProductInCart
	where product_in_cart_id = 13; */	
	
/*insert into dimProductBridge
values(1,4, 2), (1, 5, 1), (1, 11, 1)*/


insert into dimDate (day, month, year, quater, day_of_week, time)
    	select cd.day, cd.month, cd.year, cd.quarter, cd.day_of_week, cd.time    
		from (
			select distinct extract(day from c.order_date) as day, 
                        extract(month from c.order_date) as month, 
                        extract(year from c.order_date) as year, 
                        extract(quarter from c.order_date) as quarter, 
                        extract(dow from c.order_date) as day_of_week,
						to_char(c.order_date, 'HH24:MI:SS')::time as time
        	from staging.Orders c
		) cd
        left join dimDate d on d.day = cd.day and d.month = cd.month and d.year = cd.year and d.time = cd.time
        where d.date_id is null;

insert into dimDate (day, month, year, quater, day_of_week)
    	select cd.day, cd.month, cd.year, cd.quarter, cd.day_of_week    
		from (
			select distinct extract(day from c.delivered_date) as day, 
                        extract(month from c.delivered_date) as month, 
                        extract(year from c.delivered_date) as year, 
                        extract(quarter from c.delivered_date) as quarter, 
                        extract(dow from c.delivered_date) as day_of_week
        	from staging.Orders c
		) cd
        left join dimDate d on d.day = cd.day and d.month = cd.month and d.year = cd.year and d.time is null
        where d.date_id is null and cd.day is not null;

--select * from dimProductBridge
--select * from factOrders

with new_groups as (
    select distinct array_agg(row(p.product_id, o.quantity) order by o.product_key) as product_group
    from staging.Orders o
	join dimProduct p on p.product_key = o.product_key
    group by o.order_id
),
groups_to_add as (
    select nb.product_group
    from new_groups nb
    left join ( 
		select product_bridge_id, array_agg(row(product_id, quantity) order by product_id) as product_group
        from dimProductBridge
        group by product_bridge_id
    ) dpb on nb.product_group = dpb.product_group
	where dpb.product_bridge_id is null
)
insert into dimProductBridge (product_bridge_id, product_id, quantity)
    select dense_rank() over (order by ng.product_group) + (select coalesce(max(product_bridge_id), 0) from dimProductBridge),
        p.product_id, p.quantity
    from groups_to_add ng, unnest(ng.product_group) as p(product_id int, quantity int);


with cte as (
	select order_id, array_agg(row(p.product_id, o.quantity) order by p.product_id) as product_group
    from staging.Orders o
    join dimProduct p on p.product_key = o.product_key
    group by o.order_id
)
insert into factOrders (order_key, product_bridge_id, customer_id, city_id, order_date_id, delivered_date_id, total, status)
	select distinct o.order_id, dp.product_bridge_id, cus.customer_id, c.city_id,
    (select date_id from dimDate where day = extract(day from o.order_date) 
        and month = extract(month from o.order_date) and year = extract(year from o.order_date) 
        and time = to_char(o.order_date, 'HH24:MI:SS')::time),
    (select date_id from dimDate where day = extract(day from o.delivered_date) 
        and month = extract(month from o.delivered_date) and year = extract(year from o.delivered_date)),
    o.total, o.status
from staging.Orders o
join cte on cte.order_id = o.order_id
join ( 
	select product_bridge_id, array_agg(row(dpb.product_id, dpb.quantity) order by dpb.product_id) as product_group
	from dimProductBridge dpb  
	group by product_bridge_id
	) dp on dp.product_group = cte.product_group
join dimCustomer cus on cus.customer_key = o.customer_key and cus.is_current = true
join dimCity c on c.city_name = o.city_name and c.region = o.city_region
left join factOrders fo on fo.order_key = o.order_id 
where fo.order_id is null;

update factOrders f
set delivered_date_id = (select date_id from dimDate where day = extract(day from o.delivered_date) 
        and month = extract(month from o.delivered_date) and year = extract(year from o.delivered_date)),
    status = o.status
from staging.Orders o
join factOrders fo on fo.order_key = o.order_id
where fo.delivered_date_id <> (select date_id from dimDate where day = extract(day from o.delivered_date) 
        and month = extract(month from o.delivered_date) and year = extract(year from o.delivered_date)) or fo.status <> o.status
		and f.order_id = fo.order_id;

--select * from factOrders;
--select * from dimCustomer;
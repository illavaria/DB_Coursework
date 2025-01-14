create schema if not exists staging;

set lc_monetary = 'be_BY.ISO8859-5'; --is needed to store money not as dollars. that's why in csv file money is written with , instead of .

drop table if exists staging.Products;
create table staging.Products(
	product_name varchar(45),	
	description	text,
	brand text,
	color varchar(40),
	product_size varchar(30),
	weight numeric,
	material varchar(40),
	unit_price money,
	category text,
	is_available boolean
);

drop table if exists staging.Orders;
create table staging.Orders(
	username varchar(25),
	phone varchar(11),
	email varchar(40), 
	address text,
	order_date text,	
	delivered_date text,
	order_status text,
	ordered_products text,
	total money
);

\set products_path :products_path
copy staging.Products(product_name, description, brand, color, product_size, weight, material, unit_price, category, is_available)
from :'products_path'
delimiter ','
csv header;

\set orders_path :orders_path
copy staging.Orders(username, phone, email, address, order_date, delivered_date, order_status, ordered_products, total)
from :'orders_path'
delimiter ','
csv header;

--select * from staging.Products;
--select * from staging.Orders;

insert into brand(brand_name)
	select brand
	from (
		select distinct brand
		from staging.Products
	) br
	left join brand b on b.brand_name = brand
	where brand_id is null;

--select * from brand;

insert into category(category_name)
	select category
	from (
		select distinct category
		from staging.Products
	) ct
	left join category c on c.category_name = category
	where category_id is null;
	
--select * from category;

with f1 as (
	select prod.product_id, p.product_name, p.description, p.brand_id, p.color, p.product_size, p.weight, p.material, p.unit_price, p.category_id, p.is_available
	from (
		select distinct product_name, description, brand_id, color, product_size, weight, material, unit_price, category_id, is_available
		from staging.Products pr
		inner join brand b on b.brand_name = pr.brand
		inner join category c on c.category_name = pr.category
	) p
	left join product prod on prod.product_name = p.product_name
),
update_info as (
	update product pr
	set unit_price = f1.unit_price, is_available = f1.is_available
	from f1
	where pr.product_id = f1.product_id and (pr.unit_price <> f1.unit_price or
											pr.is_available <> f1.is_available)
)
insert into product(product_name, description, brand_id, color, product_size, weight, material, unit_price, category_id, is_available)
select f1.product_name, f1.description, f1.brand_id, f1.color, f1.product_size, f1.weight, f1.material, f1.unit_price, f1.category_id, f1.is_available
from f1
where product_id is null;

--select * from product;


insert into status(status_name)
	select order_status
	from (
		select distinct order_status
		from staging.Orders
	) ct
	left join status c on c.status_name = order_status
	where status_id is null;

--select * from status;

drop table if exists staging.temp_address;
create table staging.temp_address as 
with f1 as(
	select username,
		case 
			when address like 'Apt.%'
			then cast(split_part(split_part(address, ',', 1), ' ', 2) as smallint)
			else null
		end as apartment,
		case 
			when address like 'Apt.%'
			then substring(address from position(',' in address) + 2)
			else address
		end as address_part
	from staging.Orders
),
f2 as (
	select username, apartment,
		trim(split_part(address_part, ' ', 1)) as house,
		trim(substring(split_part(address_part, ',', 1) from position(' ' in split_part(address_part, ',', 1)) + 1)) as street,
        trim(split_part(address_part, ',', 2)) as city,
		trim(split_part(address_part, ',', 3)) as region
	from f1
)
select * from f2;

--select * from staging.temp_address;

insert into city(city_name, region)
	select cr.city, cr.region
	from (
		select distinct city, region
		from staging.temp_address
	) cr
	left join city c on c.city_name = city and c.region = cr.region
	where city_id is null;

--select * from city;

insert into address(apartment, house, street, city_id)
	select cr.apartment, cr.house, cr.street, cr.city_id
	from (
		select distinct apartment, house, street, city_id
		from staging.temp_address ta
		inner join city c on c.city_name = ta.city and c.region = ta.region
	) cr
	left join address a on coalesce(a.apartment, -1) = coalesce(cr.apartment, -1) and a.house = cr.house and a.street = cr.street and a.city_id = cr.city_id
	where address_id is null;

--select * from address;
with f1 as(
	select cr.username, cr.phone, cr.email, cr.address_id, c.customer_id
	from (
		select distinct ta.username, o.phone, o.email, c.city_id, a.address_id
		from staging.temp_address ta
		inner join staging.Orders o on o.username = ta.username
		inner join city c on c.city_name = ta.city and c.region = ta.region
		inner join address a on coalesce(a.apartment, -1) = coalesce(ta.apartment, -1) and a.house = ta.house and a.street = ta.street and a.city_id = c.city_id
	) cr
	left join customer c on c.username = cr.username
),
update_address as(
	update customer c
    set address_id = f1.address_id
    from f1
    where c.customer_id = f1.customer_id and c.address_id <> f1.address_id 
)
insert into customer(username, phone, email, address_id)
	select username, phone, email, address_id
	from f1
	where customer_id is null;

update customer c
set phone = o.phone
from staging.Orders o 
where c.username = o.username and c.phone <> o.phone;

update customer c
set email = o.email
from staging.Orders o 
where c.username = o.username and c.email <> o.email;

--select * from customer;
/*update customer c
set email = 'aaab'
where username = 'illavaria'*/

with f1 as (
	select p.order_date, p.delivered_date, p.status_id, p.customer_id, oi.order_id, p.total
	from (
		select distinct to_timestamp(order_date, 'DD/MM/YYYY HH24:MI') as order_date,
			to_date(delivered_date, 'DD/MM/YYYY') as delivered_date, status_id, customer_id, total
		from staging.Orders o
		inner join status s on s.status_name = o.order_status
		inner join customer c on c.username = o.username
	) p
	left join order_info oi on oi.customer_id = p.customer_id and oi.order_date = p.order_date
),
update_info as (
	update order_info oi
    set status_id = f1.status_id, delivered_date = f1.delivered_date
    from f1
    where oi.order_id = f1.order_id and oi.order_date = f1.order_date and (oi.status_id <> f1.status_id or
			coalesce(oi.delivered_date, '01-01-1000') <> coalesce(f1.delivered_date, '01-01-1000'))
)
insert into order_info(customer_id, order_date, delivered_date, status_id, total)
select f1.customer_id, f1.order_date, f1.delivered_date, f1.status_id, f1.total
from f1
where order_id is null;

--select * from order_info;


with f1 as (
    select oi.order_id,
        trim(split_part(product, '*', 2)) as product_name,
        cast(trim(split_part(product, '*', 1)) as integer) as quantity
    from (
        select username, unnest(string_to_array(ordered_products, ',')) as product, to_timestamp(order_date, 'DD/MM/YYYY HH24:MI') as order_date
        from staging.Orders
    ) o
    inner join customer c on c.username = o.username
    inner join order_info oi on oi.customer_id = c.customer_id and oi.order_date = o.order_date
),
f2 as (
    select f1.order_id, p.product_id, f1.quantity, op.quantity as check_existance
    from f1 
    inner join product p on p.product_name = f1.product_name
	left join order_product op on op.order_id = f1.order_id and op.product_id = p.product_id
)
insert into order_product(order_id, product_id, quantity)
select order_id, product_id, quantity
from f2
where check_existance is null;

--select * from order_product;

/* select c.username, p.product_name, op.quantity, op.order_id
from order_info oi
join customer c on oi.customer_id = c.customer_id
join order_product op on oi.order_id = op.order_id
join product p on op.product_id = p.product_id; */


/*update order_info
set delivered_date = '12/31/2024', status_id = 4
where order_id = 1;*/

--This script is only for the convenience of first time insert. Cart will be modified by insterts and updated, not stored in csv.
drop table if exists staging.Cart;
create table staging.Cart(
	username varchar(25),
	product_name varchar(45),
	quantity integer,
	added_date text
);

\set cart_path :cart_path
copy staging.Cart(username, product_name, quantity, added_date)
from :'cart_path'
delimiter ','
csv header;

insert into cart_product(customer_id, product_id, quantity, added_date)
select c.customer_id, p.product_id, quantity, 
					to_date(added_date, 'DD/MM/YYYY') as added_date
from staging.Cart ca
inner join customer c on c.username = ca.username
inner join product p on p.product_name = ca.product_name
on conflict(customer_id, product_id) do nothing;

--select * from staging.Cart;
--select * from cart_product;
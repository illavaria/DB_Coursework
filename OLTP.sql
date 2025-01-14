drop table if exists city cascade;
drop table if exists address cascade;
drop table if exists customer cascade;
drop table if exists category cascade;
drop table if exists brand cascade;
drop table if exists product cascade;
drop table if exists cart_product cascade;
drop table if exists status cascade;
drop table if exists order_info cascade;
drop table if exists order_product cascade;

create table if not exists city(
	city_id serial primary key,
	city_name varchar(58) not null,
	region varchar(30) not null,
	constraint unique_city_region unique (city_name, region)
);

create table if not exists address(
	address_id serial primary key,
	apartment smallint,
	house varchar(5) not null,
	street varchar(30) not null,
	city_id integer,
	foreign key (city_id) references city(city_id),
	check(apartment > 0)
);

create table if not exists customer(
	customer_id serial primary key,
	username varchar(25) not null unique,
	user_password varchar(12),
	phone varchar(11) not null, --8029....
	email varchar(40) not null,
	address_id integer,
	foreign key(address_id) references address(address_id)
);

create table if not exists category(
	category_id serial primary key,
	category_name varchar(25) not null
);

create table if not exists brand(
	brand_id serial primary key,
	brand_name varchar(25) not null
);

create table if not exists product(
	product_id serial primary key,
	product_name varchar(45) not null unique,
	description text,
	brand_id integer,
	color varchar(40) not null,
	product_size varchar(30) not null, 
	weight decimal not null,
	material varchar(40),
	unit_price money not null,
	category_id integer,
	is_available bool,
	foreign key (category_id) references category(category_id),
	foreign key (brand_id) references brand(brand_id),
	check(unit_price>money(0)),
	check(weight>0)
);

create table if not exists cart_product(
	customer_id integer,
	product_id integer,
	quantity integer not null,
	added_date date not null,
	foreign key (customer_id) references customer(customer_id),
	foreign key (product_id) references product(product_id),
	primary key(customer_id, product_id)
);

create table if not exists status(
	status_id serial primary key,
	status_name varchar(20) not null
);

create table if not exists order_info( --can't use the name order :(
	order_id serial primary key,
	customer_id integer,
	order_date timestamp not null,
	delivered_date date, --null in case if not delivered yet
	status_id integer,
	total money not null,
	foreign key (customer_id) references customer(customer_id),
	foreign key (status_id) references status(status_id)
);

create table if not exists order_product(
	order_id integer,
	product_id integer,
	quantity integer not null,
	foreign key (order_id) references order_info(order_id),
	foreign key (product_id) references product(product_id),
	primary key(order_id, product_id)
);

drop view if exists v_orders;
create or replace view v_orders as
	select o.order_id, p.product_id as product_key, op.quantity, c.customer_id as customer_key, ci.city_name, 
	ci.region as city_region, o.order_date, o.delivered_date, o.total, s.status_name as status
from order_info o
join order_product op on o.order_id = op.order_id
join product p on op.product_id = p.product_id
join customer c on o.customer_id = c.customer_id
join address a on c.address_id = a.address_id
join city ci on a.city_id = ci.city_id
join status s on o.status_id = s.status_id;

drop table if exists factProductInCart cascade;
drop table if exists factOrders cascade;
drop table if exists dimCustomer cascade;
drop table if exists dimDate cascade;
drop table if exists dimBrand cascade;
drop table if exists dimProduct cascade;
drop table if exists dimProductBridge cascade;
drop table if exists dimCity cascade;

create table if not exists dimCity(
	city_id serial primary key,
	city_name varchar(58) not null,
	region varchar(30) not null,
	constraint unique_city_region unique (city_name, region)
);

create table if not exists dimBrand(
	brand_id serial primary key,
	brand_name varchar(25) not null
);

create table if not exists dimDate(
	date_id serial primary key,
	day integer not null,
	month integer not null,
	year integer not null,
	quater integer not null,
	day_of_week integer not null,
	time time,
	constraint unique_day_time unique (day, month, year, time)
);

create table if not exists dimCustomer(
	customer_id serial primary key,
	customer_key integer, --as user info can change and its SCD2, it makes sence to store customer's id from oltp 
	username varchar(25) not null,
	phone varchar(11) not null, --8029....
	email varchar(40) not null,
	apartment smallint,
	house varchar(5) not null,
	street varchar(30) not null,
	start_date_id integer not null,
	end_date_id integer,
	is_current boolean not null,
	foreign key (start_date_id) references dimDate(date_id),
	foreign key (end_date_id) references dimDate(date_id),
	check(apartment > 0)
);

create table if not exists dimProduct(
	product_id serial primary key,
	product_key integer not null unique, --in case product name changes
	product_name varchar(45) not null unique,
	description text,
	color varchar(40) not null,
	product_size varchar(30) not null, 
	weight decimal not null,
	material varchar(40),
	unit_price money not null,
	category varchar(25) not null,
	is_available bool,
	check(unit_price>money(0)),
	check(weight>0)
);

create table if not exists dimProductBridge(
	product_bridge_id integer not null,
	product_id integer not null,
	quantity integer not null,
	primary key (product_bridge_id, product_id, quantity),
	foreign key (product_id) references dimProduct(product_id),
	check (quantity>0)
);

create table if not exists factOrders(
	order_id serial primary key,
	order_key integer not null,
	product_bridge_id integer not null,
	customer_id integer not null,
	city_id integer not null,
	order_date_id integer not null,
	delivered_date_id integer,
	total money not null,
	status varchar(20) not null,
	foreign key (customer_id) references dimCustomer(customer_id),
	foreign key (city_id) references dimCity(city_id),
	foreign key (order_date_id) references dimDate(date_id),
	foreign key (delivered_date_id) references dimDate(date_id)
);

create table if not exists factProductInCart(
	product_in_cart_id serial primary key,
	customer_id integer not null,
	product_id integer not null,
	brand_id integer not null,
	quantity integer not null,
	added_date_id integer not null,
	start_date_id integer not null,
	end_date_id integer,
	is_current boolean not null,
	foreign key (customer_id) references dimCustomer(customer_id),
	foreign key (product_id) references dimProduct(product_id),
	foreign key (brand_id) references dimBrand(brand_id),
	foreign key (added_date_id) references dimDate(date_id),
	check (quantity>0)
);
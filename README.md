# DB Coursework: the creation of OLTP and OLAP databases for fitness products online shop
## OLTP:
![OLTP Diagram](OLTP.png)

OLTP database has the following tables: customer, address, city, cart_product, product, category, brand, order_product, order_info and status. 

Some moments:
* The city table has no country column, as the online shop works only in Belarus.
* Product's unit price and order's total are stored in Belarusian rubles.
* Each product must have a unique name.
* Each customer must have a unique name.
* Cart_product represents products that customers put in the cart. There's no need for a separate table cart, as each user can have only one cart.
* Products' weight is weight in kilos.
* Users' passwords are not stored in CSV files for security reasons.
* While transferring orders data from CSV to OLTP the order is identified by the customer and the ordered date, that's why the ordered date has time. For other columns, time isn't significant.
1) Create the OLTP database
2) Run the OLTP.sql script in the OLTP database
3) Data for OLTP is stored in the following files: Products.csv and Orders.csv. Run ETL1.sql with the following command:
   ```
   $ psql -U <username> -d <database> -f ETL1.sql --set=products_path='pathTo/Products.csv' --set=orders_path='pathTo/Orders.csv'
5) There's also a Cart.csv file that stores initial data about users' carts. It's used only for the convenience of initial database filling, as the application cart would be modified by inserts, updates and deletes, not stored in CSV files. To fill the cart run ETL_cart.sql with the following command:
    ```
    $ psql -U <username> -d <database> -f ETL_cart.sql --set=cart_path='pathTo/Cart.csv'
## OLAP:
![OLAP Diagram](OLAP.png)

OLAP database is designed to answer the following questions: Which brand's products are more often put in the cart? In which city's more orders were made?

Some moments:
* DimCustomer and factProductInCart are made SCD2 to store the history of data changes.
* DimProductBridge implements the relationship between the order and its products. If some orders have the same products with the same quantity, they would have the same product_bridge_id. 
1) Create the OLAP database
2) Run the OLAP.sql script in the OLAP database
3) Open ETL2.sql and modify lines 6 and 9. In line 6 put the correct name of your OLTP database:
```
options (host '127.0.0.1', port '5432', dbname 'db_coursework'); 
```
In line 9 put the correct user and password:
```
options (user 'postgres', password 'postgres');
```
4) Run the ETL2.sql script in the OLAP database

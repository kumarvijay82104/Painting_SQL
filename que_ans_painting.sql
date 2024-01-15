--1) Fetch all the paintings which are not displayed on any museums?
select * from work where museum_id is null;

--2) Are there museuems without any paintings?

select * from museum m
	where not exists (select 1 from work w
					 where w.museum_id=m.museum_id)

--3) How many paintings have an asking price of more than their regular price? 

select count(*) from product_size
where sale_price > regular_price

--4) Identify the paintings whose asking price is less than 50% of its regular price

select * from product_size
where sale_price < ( regular_price * 0.5)

--5) Which canva size costs the most?

with cte as (
select size_id::text,width,height,label from canvas_size)

select c1.label, sale_price from cte c1 join product_size ps on c1.size_id = ps.size_id 
order by ps.sale_price desc limit 1

--6) Delete duplicate records from work, product_size, subject and image_link tables

'''with cte as (
select * ,row_number() over(partition by work_id  ) as duplicate from work ) ----For finding Duplicate data
select * from cte where duplicate > 1'''

delete from work 
	where ctid not in (select min(ctid)
						from work
						group by work_id );


delete from product_size 
	where ctid not in (select min(ctid)
						from product_size
						group by work_id, size_id );
select  work_id,subject ,count(*) as duplicate from subject group by 1,2 having count(*) > 1 order by count(*) desc


delete from subject
where ctid not in (select min(ctid) from subject group by work_id, subject)

delete from image_link
where ctid not in (
select min(ctid) from image_link group by work_id)

--7) Identify the museums with invalid city information in the given dataset

select * from museum
	where city ~ '^[0-9]' and museum_id != 74

--8) Museum_Hours table has 1 invalid entry. Identify it and remove it.

delete from museum_hours 
	where ctid not in (select min(ctid)
						from museum_hours
						group by museum_id, day );
--9) Fetch the top 10 most famous painting subject

select su.subject , count(1) as No_of_painting from subject su 
join work wo on wo.work_id = su.work_id group by 1 order by count(1) desc limit 10

--10) Identify the museums which are open on both Sunday and Monday. Display museum name, city.

select distinct mu.name,mu.city from museum_hours ms join museum mu on mu.museum_id = ms.museum_id
where ms.day = 'Sunday' and exists (select 1 from museum_hours ms2 where ms2.museum_id = ms.museum_id and ms2.day = 'Monday'  )

--11) How many museums are open every single day?
with cte as (
select museum_id from museum_hours
where day in ('Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday') group by museum_id
having count(distinct day) = 7)
select count(*) from cte
----I DON'T KNOW WHICH ONE IS RIGHT ABOVE OR BELOW-------
select count(1)
	from (select museum_id, count(1)
		  from museum_hours
		  group by museum_id
		  having count(1) = 7) x;
		  
--12) Which are the top 5 most popular museum? (Popularity is defined based on most no of paintings in a museum)

select m.name , count(w.name) from museum m join work w on w.museum_id = m.museum_id group by 1 order by 2 desc limit 5


--13) Who are the top 5 most popular artist? (Popularity is defined based on most no of paintings done by an artist)

select a.full_name  as artist, count(w.name) as No_of_paintings from artist a join 
work w on a.artist_id = w.artist_id group by 1 order by 2 desc limit 5

--14) Display the 3 least popular canva sizes

with cte as (
select label,cs.size_id,count(*) No_of_painting ,dense_rank()over(order by count(*)) ranking from work w 
		join product_size ps on ps.work_id = w.work_id
		join canvas_size cs on cs.size_id ::text = ps.size_id 
	group by label,cs.size_id )
select label from cte 
where ranking <= 3

--15) Which museum is open for the longest during a day. Dispay museum name, state and hours open and which day?

select m.name,m.state city,mh.day,mh.close,mh.open,((to_timestamp(mh.close,'HH:MI PM'))-(to_timestamp(mh.open,'HH:MI AM'))) total_hours 
from museum_hours mh join museum m on m.museum_id = mh.museum_id order by 6 desc limit 1

--16) Which museum has the most no of most popular painting style?

with pop_style as 
			(select style
			,rank() over(order by count(1) desc) as rnk
			from work
			group by style),
		cte as
			(select w.museum_id,m.name as museum_name,ps.style, count(1) as no_of_paintings
			,rank() over(order by count(1) desc) as rnk
			from work w
			join museum m on m.museum_id=w.museum_id
			join pop_style ps on ps.style = w.style
			where w.museum_id is not null
			and ps.rnk=1
			group by w.museum_id, m.name,ps.style)
	select museum_name,style,no_of_paintings
	from cte 
	where rnk=1;
--17) Identify the artists whose paintings are displayed in multiple countries
	with cte as
		(select distinct a.full_name as artist
		--, w.name as painting, m.name as museum
		, m.country
		from work w
		join artist a on a.artist_id=w.artist_id
		join museum m on m.museum_id=w.museum_id)
	select artist,count(1) as no_of_countries
	from cte
	group by artist
	having count(1)>1
	order by 2 desc;

--18) Display the country and the city with most no of museums. Output 2 seperate columns to mention the city and country. If there are multiple value, seperate them with comma.
	with cte_country as 
			(select country, count(1)
			, rank() over(order by count(1) desc) as rnk
			from museum
			group by country),
		cte_city as
			(select city, count(1)
			, rank() over(order by count(1) desc) as rnk
			from museum
			group by city)
	select string_agg(distinct country.country,', '), string_agg(city.city,', ')
	from cte_country country
	cross join cte_city city
	where country.rnk = 1
	and city.rnk = 1;

--19) Identify the artist and the museum where the most expensive and least expensive painting is placed. 
Display the artist name, sale_price, painting name, museum name, museum city and canvas label
	with cte as 
		(select *
		, rank() over(order by sale_price desc) as rnk
		, rank() over(order by sale_price ) as rnk_asc
		from product_size )
	select w.name as painting
	, cte.sale_price
	, a.full_name as artist
	, m.name as museum, m.city
	, cz.label as canvas
	from cte
	join work w on w.work_id=cte.work_id
	join museum m on m.museum_id=w.museum_id
	join artist a on a.artist_id=w.artist_id
	join canvas_size cz on cz.size_id = cte.size_id::NUMERIC
	where rnk=1 or rnk_asc=1;

--20) Which country has the 5th highest no of paintings?
	with cte as 
		(select m.country, count(1) as no_of_Paintings
		, rank() over(order by count(1) desc) as rnk
		from work w
		join museum m on m.museum_id=w.museum_id
		group by m.country)
	select country, no_of_Paintings
	from cte 
	where rnk=5;


--21) Which are the 3 most popular and 3 least popular painting styles?
	with cte as 
		(select style, count(1) as cnt
		, rank() over(order by count(1) desc) rnk
		, count(1) over() as no_of_records
		from work
		where style is not null
		group by style)
	select style
	, case when rnk <=3 then 'Most Popular' else 'Least Popular' end as remarks 
	from cte
	where rnk <=3
	or rnk > no_of_records - 3;

--22) Which artist has the most no of Portraits paintings outside USA?. Display artist name, no of paintings and the artist nationality.
	select full_name as artist_name, nationality, no_of_paintings
	from (
		select a.full_name, a.nationality
		,count(1) as no_of_paintings
		,rank() over(order by count(1) desc) as rnk
		from work w
		join artist a on a.artist_id=w.artist_id
		join subject s on s.work_id=w.work_id
		join museum m on m.museum_id=w.museum_id
		where s.subject='Portraits'
		and m.country != 'USA'
		group by a.full_name, a.nationality) x
	where rnk=1;	

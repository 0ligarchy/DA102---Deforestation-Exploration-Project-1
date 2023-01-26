-- Create VIEW deforestation
DROP VIEW IF EXISTS forestation;
CREATE VIEW forestation
AS
  (SELECT f.country_code,
          f.country_name,
          f.year,
          f.forest_area_sqkm,
          l.total_area_sq_mi,
          r.region,
          r.income_group,
          Round(( f.forest_area_sqkm * 100 / ( l.total_area_sq_mi * 
2.59 ) ) :: numeric, 2) AS forest_pct_sqkm
   FROM   forest_area AS f
          JOIN land_area AS l
            ON f.country_code = l.country_code
               AND f.year = l.year
          JOIN regions AS r
            ON f.country_code = r.country_code); 

-- Total forest area of the world in 1990
SELECT *
FROM   forestation
WHERE  country_name = 'World'
       AND year = 1990 

-- Total forest area of the world in 2016
SELECT *
FROM   forestation
WHERE  country_name = 'World'
       AND year = 2016 

-- Change from 1990 to 2016
SELECT a.country_name,
       a.forest_area_sqkm AS forest1,
       b.forest_area_sqkm AS forest2,
       a.forest_area_sqkm - b.forest_area_sqkm AS change
FROM   forestation AS a
       JOIN forestation AS b
         ON a.country_name = b.country_name
WHERE  a.country_name = 'World'
       AND a.year = 1990
       AND b.year = 2016

-- Percent change from 1990 to 2016
SELECT a.country_name,
       A.forest_area_sqkm AS forest90,
       B.forest_area_sqkm AS forest16,
       ( ( b.forest_area_sqkm -
       a.forest_area_sqkm ) / a.forest_area_sqkm ) * 100
                          AS pct_change
FROM   forestation AS a
       JOIN forestation AS b
         ON a.country_name = b.country_name
WHERE  a.country_name = 'World'
       AND a.year = 1990
       AND b.year = 2016 

-- Country with forest lost closest to 1,324,000 sqkm
SELECT *,
       ( total_area_sq_mi * 2.59 ) AS total_area_sqkm
FROM   forestation
WHERE  ( total_area_sq_mi * 2.59 ) BETWEEN 1270000 AND 1300000
       AND year = 2016
ORDER  BY total_area_sq_mi 

-- Total forest % of entire world in 2016
SELECT forest_pct_sqkm
FROM   forestation
WHERE  country_name = 'World'
       AND year = 2016 

-- Region with highest % forest in 2016
WITH land_area_sqkm AS
(
       SELECT f.country_code,
              f.year,
              ( total_area_sq_mi * 2.59 ) AS total_area_sqkm
       FROM   forestation AS f )

SELECT   f.region,
         Round((Sum(forest_area_sqkm) * 100 / Sum(total_area_sqkm)):: 
numeric, 2) AS reg_pct_2016
FROM     forestation AS f
JOIN     land_area_sqkm AS l
ON       f.country_code=l.country_code
AND      f.year=l.year
WHERE    f.year = 2016
GROUP BY 1
ORDER BY 2 DESC 

-- Region with highest % forest in 1990
WITH land_area_sqkm AS
(
       SELECT f.country_code,
              f.year,
              ( total_area_sq_mi * 2.59 ) AS total_area_sqkm
       FROM   forestation AS f )

SELECT   f.region,
         Round((Sum(forest_area_sqkm) * 100 / Sum(total_area_sqkm)):: 
numeric, 2)  AS reg_pct_1990
FROM     forestation AS f
JOIN     land_area_sqkm AS l
ON       f.country_code=l.country_code
AND      f.year=l.year
WHERE    f.year = 1990
GROUP BY 1
ORDER BY 2 

-- Regions of the world that decreased in forest area
WITH land_area_sqkm AS
(
       SELECT f.country_code,
              f.year,
              ( total_area_sq_mi * 2.59 ) AS total_area_sqkm
       FROM   forestation f), 
regional_pct_2016 AS
(
         SELECT   f.region,
                  Round(( Sum(forest_area_sqkm) * 100 / 
                  Sum(total_area_sqkm) ) :: numeric, 2) 
                    AS reg_pct_2016
         FROM     forestation AS f
         JOIN     land_area_sqkm AS l
         ON       f.country_code = l.country_code
         AND      f.year = l.year
         WHERE    f.year = 2016
         GROUP BY 1
         ORDER BY 2), 
regional_pct_1990 AS
(
         SELECT   f.region,
                  Round(( Sum(f.forest_area_sqkm) * 100 / 
                  Sum(l.total_area_sqkm) ) :: numeric, 2) 
                    AS reg_pct_1990
         FROM     forestation AS f
         JOIN     land_area_sqkm AS l
         ON       f.country_code = l.country_code
         AND      f.year = l.year
         WHERE    f.year = 1990
         GROUP BY 1
         ORDER BY 2)
--
SELECT DISTINCT f.region,
                reg1.reg_pct_1990,
                reg2.reg_pct_2016
FROM   forestation AS f
       JOIN regional_pct_2016 AS reg2
         ON f.region = reg2.region
       JOIN regional_pct_1990 AS reg1
         ON f.region = reg1.region
WHERE  reg1.reg_pct_1990 > reg2.reg_pct_2016 

-- 5 countries with largest % decrease in forest
WITH forest_1990 AS
(
       SELECT f.country_name,
              f.forest_area_sqkm AS forest_area_1990
       FROM   forestation AS f
       WHERE  f.year = 1990
       AND    f.forest_area_sqkm IS NOT NULL ), 
forest_2016 AS
(
       SELECT f.country_name,
              f.forest_area_sqkm AS forest_area_2016
       FROM   forestation AS f
       WHERE  f.year = 2016
       AND    f.forest_area_sqkm IS NOT NULL )
--
SELECT DISTINCT f.country_name,
                f.region,
                f90.forest_area_1990 - f16.forest_area_2016                                                
                  AS dif_area,
                Round (((f16.forest_area_2016 - f90.forest_area_1990 ) 
                  / f90.forest_area_1990)::numeric,2) AS dif_pct
FROM            forestation AS f
JOIN            forest_1990 AS f90
ON              f.country_name=f90.country_name
JOIN            forest_2016 AS f16
ON              f.country_name=f16.country_name
ORDER BY        4 limit 5

-- Quartile with the most countries in it in 2016
SELECT q.quartiles,
       Count(*)
FROM   (SELECT f.country_name,
               f.year,
               f.forest_pct_sqkm,
               CASE
                 WHEN f.forest_pct_sqkm >= 75 THEN '75-100'
                 WHEN f.forest_pct_sqkm >= 50 THEN '50-75'
                 WHEN f.forest_pct_sqkm >= 25 THEN '25-50'
                 ELSE '0-25'
               END AS quartiles
        FROM   forestation AS f 
        WHERE  year = 2016
               AND f.forest_pct_sqkm IS NOT NULL
               AND f.country_name <> 'World') AS q
GROUP  BY 1
ORDER  BY 2 DESC

-- Countries in the fourth quartile in 2016
SELECT q.country_name,
       r.region,
       q.forest_pct_sqkm
FROM   (SELECT f.country_name,
               f.year,
               f.forest_pct_sqkm,
               CASE
                 WHEN f.forest_pct_sqkm >= 75 THEN '75-100'
                 WHEN f.forest_pct_sqkm >= 50 THEN '50-75'
                 WHEN f.forest_pct_sqkm >= 25 THEN '25-50'
                 ELSE '0-25'
               end AS quartiles
        FROM   forestation AS f
        WHERE  year = 2016
               AND f.forest_pct_sqkm IS NOT NULL
               AND f.country_name <> 'World') q
       JOIN regions AS r
         ON q.country_name = r.country_name
WHERE  q.quartiles = '75-100'
ORDER  BY 3 DESC

-- Number of countries with a % forestation higher than the US in 2016
WITH q
     AS (SELECT f.country_name,
                f.year,
                f.forest_pct_sqkm,
                CASE
                  WHEN f.forest_pct_sqkm >= 75 THEN '75-100'
                  WHEN f.forest_pct_sqkm >= 50 THEN '50-75'
                  WHEN f.forest_pct_sqkm >= 25 THEN '25-50'
                  ELSE '0-25'
                END AS quartiles
         FROM   forestation AS f
         WHERE  year = 2016
                AND f.forest_pct_sqkm IS NOT NULL
                AND f.country_name <> 'World')

SELECT Count(*)
FROM   q
WHERE  q.forest_pct_sqkm > (SELECT q.forest_pct_sqkm
                            FROM   q
                            WHERE  q.country_name = 'United States')




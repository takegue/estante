CREATE OR REPLACE FUNCTION sample_function(x ARRAY<FLOAT64>, y ARRAY<FLOAT64>, alt STRING) 
------ <- keyword
--     ^ keyword
AS (
(
  WITH statistics as (
    WITH summ as (
      WITH mydata as(
        SELECT  true as label,  xi as val
        FROM UNNEST( x ) as xi
        UNION ALL
        SELECT  false as label, yi as val
        FROM UNNEST( y ) as yi
      )
      SELECT label, (RANK() OVER(ORDER BY val ASC))+(COUNT(*) OVER (PARTITION BY CAST(val AS STRING)) - 1)/2.0  AS r
      FROM mydata
    )
    SELECT sum(r) - ARRAY_LENGTH(x)*(ARRAY_LENGTH(x)+ 1)/2.0  as U2,
           ARRAY_LENGTH(x)*(ARRAY_LENGTH(y) + (ARRAY_LENGTH(x)+ 1)/2.0) - sum(r) as U1, 
           ARRAY_LENGTH(x) * ARRAY_LENGTH(y) as n1n2,
           SQRT(ARRAY_LENGTH(x) * ARRAY_LENGTH(y) *(ARRAY_LENGTH(x)+ARRAY_LENGTH(y)+1)/12.0 ) as den,
    FROM summ
    WHERE label
 ),
 normal_appr as (
  SELECT 
    CASE alt
      WHEN 'less' THEN ( n1n2/2.0 +0.5 - U1)/den
      WHEN 'greater' THEN (n1n2/2.0 +0.5 - U2)/den
      ELSE    -1.0*ABS(n1n2/2.0 + 0.5 - IF(U1<U2,U2,U1))/den
    END as z, 
    U1 as U,
    IF( alt='less' OR alt='greater', 1.0, 2.0 ) as factor
  FROM statistics  
)
 SELECT struct(U, factor* ${ref("normal_cdf")}(z,0.0,1.0) as p ) 
 FROM normal_appr 
));

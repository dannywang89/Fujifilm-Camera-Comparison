Create Database FujiFilmDB;
GO

--Checking to see if data was imported 
SELECT COUNT(*) AS Cameras_Count
FROM dbo.Cameras;

SELECT COUNT(*) AS Lenses_Count
FROM dbo.Lenses;

SELECT COUNT(*) AS Camera_Images_Count
FROM dbo.Camera_Images;

SELECT COUNT(*) AS Lens_Images_Count
FROM dbo.Lens_Images;

SELECT COUNT(*) AS Film_Simulations_Count
FROM dbo.Film_Simulations;

SELECT COUNT(*) AS Camera_Film_Simulations_Count
FROM dbo.Camera_Film_Simulations;

SELECT COUNT(*) AS Mounts_Count
FROM dbo.Mounts;


--Making changes and relations between tables
ALTER TABLE dbo.Camera_Images
ADD CONSTRAINT FK_Camera_Images_Cameras
FOREIGN KEY (camera_id)
REFERENCES dbo.Cameras(camera_id);

ALTER TABLE dbo.Lens_Images
ADD CONSTRAINT FK_Lens_Images_Lenses
FOREIGN KEY (lens_id)
REFERENCES dbo.Lenses(lens_id);

ALTER TABLE dbo.Camera_Film_Simulations
ADD CONSTRAINT FK_CameraFilm_Cameras
FOREIGN KEY (camera_id)
REFERENCES dbo.Cameras(camera_id);

ALTER TABLE dbo.Camera_Film_Simulations
ADD CONSTRAINT FK_CameraFilm_FilmSimulations
FOREIGN KEY (simulation_id)
REFERENCES dbo.Film_Simulations(simulation_id);

ALTER TABLE dbo.Mounts
ADD CONSTRAINT UQ_Mounts_mount_name
UNIQUE (mount_name);

ALTER TABLE dbo.Cameras
ADD CONSTRAINT FK_Cameras_Mounts
FOREIGN KEY (mount)
REFERENCES dbo.Mounts(mount_name);

ALTER TABLE dbo.Lenses
ADD CONSTRAINT FK_Lenses_Mounts
FOREIGN KEY (mount)
REFERENCES dbo.Mounts(mount_name);

--Test
SELECT
    c.model,
    c.mount,
    m.sensor_format,
    m.crop_factor_vs_35mm
FROM dbo.Cameras c
JOIN dbo.Mounts m
    ON c.mount = m.mount_name;




--Questions
--1. How many cameras has Fujifilm released in each system, and what percentage of the total camera lineup does each system represent?
Select system, count(*) as camera_count, cast(round((count(*)*100.0)/sum(count(*))over(),2)as decimal(5,2)) as system_percentages
From dbo.Cameras
Group by system;

--2. How has the number of new Fujifilm camera releases changed by year? Break the results down by system.
Select release_year, system, count(*) as camera_count, lag(count(*))over(partition by system order by release_year, system) as previous_year,
sum(count(*))over(partition by system order by release_year rows between unbounded preceding and current row) as cumulative_camera_count
From dbo.Cameras
Group by system, release_year
order by release_year, system;

--3. What are the average, minimum, and maximum launch MSRPs of cameras within each system?
Select system, cast(avg(launch_msrp_usd) as decimal(10,2)) as avg_msrp, cast(min(launch_msrp_usd) as decimal(10,2)) as min_rsvp, 
cast(max(launch_msrp_usd) as decimal(10,2)) as max_rsvp
From dbo.Cameras 
Group by system;

--4. Which cameras are priced above the average launch MSRP of cameras in their own system?
with avg_cam_price as (
Select system, cast(avg(launch_msrp_usd) as decimal(10,2)) as avg_msrp
From dbo.Cameras 
Group by system
)
Select c.model, c.system, a.avg_msrp, c.launch_msrp_usd
From Cameras as c
join avg_cam_price as a
on c.system = a.system
where c.launch_msrp_usd >= a.avg_msrp;

--5. Within each camera series, rank the cameras from most expensive to least expensive at launch.
Select model, series, launch_msrp_usd,rank()over(partition by series order by launch_msrp_usd desc) as price_order
From dbo.Cameras;

--6. How has the average camera launch MSRP changed from one release year to the next, including the dollar change and percentage change?
Select release_year, cast(avg(launch_msrp_usd) as decimal(10,2)) as avg_price, 
cast((avg(launch_msrp_usd) - lag(avg(launch_msrp_usd))over(order by release_year)) as decimal(10,2)) as price_change,
cast(((avg(launch_msrp_usd) - lag(avg(launch_msrp_usd))over(order by release_year))*100.0) / nullif(lag(avg(launch_msrp_usd))over(order by release_year),0) as decimal(10,2))  as percentage_change
From dbo.Cameras
group by release_year
order by release_year;

--7. Do cameras with IBIS cost more and weigh more on average than cameras without IBIS?
Select 'Has_IBIS' as IBIS_in_Camera, cast(avg(launch_msrp_usd) as decimal(10,2)) as average_price, avg(weight_g) as avg_weight
From dbo.Cameras
where ibis = 'Yes'
UNION ALL
Select 'No_IBIS' as IBIS_in_Camera, cast(avg(launch_msrp_usd) as decimal(10,2)) as average_price, avg(weight_g) as avg_weight
From dbo.Cameras
where ibis = 'No'
UNION ALL
Select 'Amount_Difference' as IBIS_in_Camera, cast(avg(case when ibis = 'Yes' then launch_msrp_usd end)-avg(case when ibis = 'No' then launch_msrp_usd end) as decimal(10,2)) as ibis_price_diff,
avg(case when ibis = 'Yes' then weight_g end)-avg(case when ibis = 'No' then weight_g end) as ibis_weight_diff
From dbo.Cameras
UNION ALL
Select 'Percentage_Calculations', Null, Null
UNION ALL
Select 'Percentage_Difference' as IBIS_in_Camera, cast((avg(case when ibis = 'Yes' then launch_msrp_usd end)-avg(case when ibis = 'No' then launch_msrp_usd end))*100.0/ avg(case when ibis = 'No' then launch_msrp_usd end) as decimal(10,2)) as ibis_price_percentage_diff,
cast((avg(case when ibis = 'Yes' then weight_g end)-avg(case when ibis = 'No' then weight_g end))*100/ avg(case when ibis = 'No' then weight_g end) as decimal(10,2)) as ibis_weight_percentage_diff
From dbo.Cameras

SELECT
ibis,
CAST(AVG(launch_msrp_usd) AS DECIMAL(10,2)) AS average_price,
CAST(AVG(weight_g) AS DECIMAL(10,2)) AS avg_weight
FROM dbo.Cameras
GROUP BY ibis;

--8. Do weather-sealed cameras carry a launch-price premium compared with cameras without weather sealing? 
--Quantify the difference in both dollars and percentage terms.
With Weather_Avg as (
SELECT weather_sealed,
CAST(AVG(launch_msrp_usd) AS DECIMAL(10,2)) AS average_price
FROM dbo.Cameras
GROUP BY weather_sealed
)
Select w.weather_sealed,
Cast(w.average_price as decimal(10,2)) as average_price,
Cast(w.average_price - n.no_average as decimal(10,2)) as dollar_premium,    
Cast((w.average_price - n.no_average) *100.0 / nullif(n.no_average, 0) as decimal(10,2)) as percentage_premium
From Weather_Avg as w
cross join 
(Select average_price as no_average
From Weather_Avg
Where weather_sealed = 'No') as n
order by 
case
when w.weather_sealed = 'No' Then 1
when w.weather_sealed = 'Partial' Then 2
when w.weather_sealed = 'Yes' Then 3
end;

--9. Which cameras provide the most megapixels per $1,000 of launch MSRP? Show the top 10.
Select top 10 model, megapixels, launch_msrp_usd, cast((megapixels/launch_msrp_usd)*1000 as decimal(10,2)) as megapixel_per_dollar
From dbo.Cameras
order by megapixel_per_dollar desc;

--10. Which cameras support the greatest number of film simulations? Include the camera model, release year, system, and number supported.
--Method 1
Select top 10 model, release_year, system, 
(case when supports_provia_standard = 'Yes' then 1 else 0 end +
case when supports_velvia_vivid = 'Yes' then 1 else 0 end +
case when supports_astia_soft = 'Yes' then 1 else 0 end +
case when supports_classic_chrome = 'Yes' then 1 else 0 end +
case when supports_pro_neg_hi = 'Yes' then 1 else 0 end +
case when supports_pro_neg_std = 'Yes' then 1 else 0 end +
case when supports_classic_negative = 'Yes' then 1 else 0 end +
case when supports_nostalgic_negative = 'Yes' then 1 else 0 end +
case when supports_reala_ace = 'Yes' then 1 else 0 end +
case when supports_eterna_cinema = 'Yes' then 1 else 0 end +
case when supports_eterna_bleach_bypass = 'Yes' then 1 else 0 end +
case when supports_acros = 'Yes' then 1 else 0 end +
case when supports_monochrome = 'Yes' then 1 else 0 end +
case when supports_sepia = 'Yes' then 1 else 0 end
) as total_simulations_supported
From dbo.Cameras
order by total_simulations_supported desc;

--Method 2
Select top 10 c.model, c.release_year, c.system, count(cfs.simulation_id) as total_simulations_supported
from dbo.Cameras as c
join dbo.Camera_Film_Simulations as cfs 
on c.camera_id = cfs.camera_id
group by c.model, c.release_year, c.system
order by total_simulations_supported desc;

--11. Which film simulations are available on the greatest number of cameras, and what percentage of all cameras support each one?
Select top 10 fs.film_simulation, count(*) as total_cameras_supported, count(*)*100/(Select count(*) From dbo.Cameras) as percentage_supported
from dbo.Cameras as c
join dbo.Camera_Film_Simulations as cfs
on c.camera_id = cfs.camera_id
join dbo.Film_Simulations as fs
on cfs.simulation_id = fs.simulation_id
group by fs.simulation_id, fs.film_simulation
order by total_cameras_supported desc;

--12. For every film simulation, what is the earliest camera in your dataset that supports it?
With earliest_camera as (
Select fs.film_simulation, c.model, c.release_year, rank()over(partition by fs.film_simulation order by c.release_year) as rnk
from dbo.Cameras as c
join dbo.Camera_Film_Simulations as cfs
on c.camera_id = cfs.camera_id
join dbo.Film_Simulations as fs
on cfs.simulation_id = fs.simulation_id)
Select film_simulation, model, release_year
from earliest_camera
where rnk = 1   
order by film_simulation;

--13. How has the average number of supported film simulations per camera changed over release years?
with simulations_by_year as (
Select c.model, c.release_year, c.system, count(cfs.simulation_id) as total_simulations_supported
from dbo.Cameras as c
join dbo.Camera_Film_Simulations as cfs 
on c.camera_id = cfs.camera_id
group by c.model, c.release_year, c.system)
Select release_year, cast(avg(cast(total_simulations_supported as decimal(10,2))) as decimal(10,2)) as avg_simulations
From simulations_by_year as sby
group by release_year;

--14. Compare prime and zoom lenses in terms of average launch price, average weight, and average maximum aperture. What differences do you observe?
Select 
case
when lens_class like '%prime%' then 'Prime'
when lens_class like '%zoom%' then 'Zoom'
end as lens_type, 
cast(avg(launch_msrp_usd) as decimal(10,2)) as avg_price, cast(avg(weight_g) as decimal(10,2)) as avg_weight, cast(avg(max_aperture_tele) as decimal(10,2)) as avg_max_aperture
From dbo.Lenses
group by (
case
when lens_class like '%prime%' then 'Prime'
when lens_class like '%zoom%' then 'Zoom'
end);

--15. Within each focal-range category, what are the three lightest lenses?
With focal_rnk as (
Select focal_range_category, model, weight_g, row_number()over(partition by focal_range_category order by weight_g) as rnk
From dbo.Lenses)
Select focal_range_category, model, weight_g
from focal_rnk
where rnk <= 3
order by focal_range_category, rnk;

--16. Do weather-resistant lenses cost more than non-weather-resistant lenses? Compare their average price, average weight, and the percentage price difference.
With Weather_Avg as (
SELECT weather_resistant,
CAST(AVG(launch_msrp_usd) AS DECIMAL(10,2)) AS average_price
FROM dbo.Lenses
GROUP BY weather_resistant
)
Select w.weather_resistant,
Cast(w.average_price as decimal(10,2)) as average_price,
Cast(w.average_price - n.no_average as decimal(10,2)) as dollar_premium,    
Cast((w.average_price - n.no_average) *100.0 / nullif(n.no_average, 0) as decimal(10,2)) as percentage_premium
From Weather_Avg as w
cross join 
(Select average_price as no_average
From Weather_Avg
Where weather_resistant = 'No') as n
order by 
case
when w.weather_resistant = 'No' Then 1
when w.weather_resistant = 'Yes' Then 2
end;

--17. Which zoom lenses provide the greatest focal-length range relative to their weight?
Select top 10 model, min_focal_mm, max_focal_mm, (max_focal_mm - min_focal_mm) as focal_range, weight_g, 
cast((max_focal_mm - min_focal_mm) * 1.0 /weight_g as decimal(10,2)) as focal_range_per_weight
From dbo.Lenses
where lens_class like 'Zoom'
order by focal_range_per_weight desc

--18. Which lenses would be strongest for travel if you create a Travel Lens Score based on weight, weather resistance, OIS, and focal-range versatility? 
--Define your scoring methodology and rank the results.
With travel_factor as(
Select model, equiv_min_focal_mm, equiv_max_focal_mm, weight_g, weather_resistant, ois, max_aperture, suggested_primary_use,
case
when equiv_min_focal_mm <= 35 and equiv_max_focal_mm >= 50 then 100
when equiv_min_focal_mm <= 35 and equiv_max_focal_mm >= 35 then 90
when equiv_min_focal_mm <= 50 and equiv_max_focal_mm >= 50 then 80
when equiv_min_focal_mm <= 85 and equiv_max_focal_mm >= 50 then 65
else 40
end as focal_suitability_score,
case
when weight_g < 200 then 100
when weight_g < 400 then 80
when weight_g < 600 then 60
when weight_g < 800 then 40
else 20
end as weight_score,
case
when equiv_min_focal_mm = equiv_max_focal_mm then 40
when (equiv_max_focal_mm - equiv_min_focal_mm) >= 100 then 100
when (equiv_max_focal_mm - equiv_min_focal_mm) >= 60 then 85
when (equiv_max_focal_mm - equiv_min_focal_mm) >= 30 then 70
else 55
end as versatility_score,
case
when (max_aperture_wide - max_aperture_tele) / 2.0 <= 1.4 then 100
when (max_aperture_wide - max_aperture_tele) / 2.0 <= 2.0 then 90
when (max_aperture_wide - max_aperture_tele) / 2.0 <= 2.8 then 80
when (max_aperture_wide - max_aperture_tele) / 2.0 <= 4.0 then 60
when (max_aperture_wide - max_aperture_tele) / 2.0 <= 5.6 then 40
else 20
end as aperture_score,
case
when weather_resistant = 'Yes' Then 100
else 0
end as weather_score,
case
when ois = 'Yes' Then 100
else 0
end as ois_score
from dbo.Lenses)
Select model, equiv_min_focal_mm, equiv_max_focal_mm, weight_g, max_aperture, weather_resistant, ois,
cast(
focal_suitability_score * 0.25 +
weight_score * 0.20 +
versatility_score * 0.20 +
aperture_score * 0.15 +
weather_score * 0.10 +
ois_score * 0.10 
as decimal(10,2)) as travel_score,
suggested_primary_use
from travel_factor
order by travel_score desc;

--19. What is the cheapest possible interchangeable-lens camera + compatible lens combination for each Fujifilm mount/system?
With cheapest_camera as (
Select mount, model, launch_msrp_usd,ROW_NUMBER()over(partition by mount order by launch_msrp_usd) as rn
From dbo.Cameras
where lens_configuration = 'Interchangeable'),
cheapest_lens as (
Select mount, model, launch_msrp_usd,ROW_NUMBER()over(partition by mount order by launch_msrp_usd) as rn
From dbo.Lenses)
Select c.mount, c.model as cameral_model, c.launch_msrp_usd as camera_price, l.model as lens_model, l.launch_msrp_usd as lens_price,
c.launch_msrp_usd + l.launch_msrp_usd as total_kit_price
From cheapest_camera as c
join cheapest_lens as l
on c.mount = l.mount 
where c.rn = 1 and l.rn = 1;

--20. Create a Camera Value Score using multiple buyer-relevant attributes such as 
-- megapixels, IBIS, weather sealing, film-simulation count, weight, and launch price. 
-- Which cameras rank highest, and how does your ranking change if you prioritize portability versus features?
WITH Film_Count AS
(
    SELECT
        camera_id,
        COUNT(*) AS film_sim_count
    FROM dbo.Camera_Film_Simulations
    GROUP BY camera_id
),

Camera_Base AS
(
    SELECT
        c.camera_id,
        c.model,
        c.system,
        c.lens_configuration,
        c.megapixels,
        c.weight_g,
        c.launch_msrp_usd,
        c.ibis,
        c.weather_sealed,
        c.supports_4k30,
        c.supports_6k_open_gate,
        ISNULL(fc.film_sim_count, 0) AS film_sim_count

    FROM dbo.Cameras AS c

    LEFT JOIN Film_Count AS fc
        ON c.camera_id = fc.camera_id
),

Ranges AS
(
    SELECT
        MIN(megapixels) AS min_mp,
        MAX(megapixels) AS max_mp,

        MIN(weight_g) AS min_weight,
        MAX(weight_g) AS max_weight,

        MIN(launch_msrp_usd) AS min_price,
        MAX(launch_msrp_usd) AS max_price,

        MIN(film_sim_count) AS min_film,
        MAX(film_sim_count) AS max_film
    FROM Camera_Base
),

Scores AS
(
    SELECT
        cb.*,

        /* Higher megapixels = better */
        ((cb.megapixels - r.min_mp) * 100.0
        / NULLIF(r.max_mp - r.min_mp, 0)) AS resolution_score,

        /* Lower weight = better */
        ((r.max_weight - cb.weight_g) * 100.0
        / NULLIF(r.max_weight - r.min_weight, 0)) AS weight_score,

        /* Lower price = better */
        ((r.max_price - cb.launch_msrp_usd) * 100.0
        / NULLIF(r.max_price - r.min_price, 0)) AS price_score,

        /* More film simulations = better */
        ((cb.film_sim_count - r.min_film) * 100.0
        / NULLIF(r.max_film - r.min_film, 0)) AS film_score,

        CASE
            WHEN cb.ibis = 'Yes' THEN 100
            ELSE 0
        END AS ibis_score,

        CASE
            WHEN cb.weather_sealed = 'Yes' THEN 100
            WHEN cb.weather_sealed = 'Partial' THEN 50
            ELSE 0
        END AS weather_score,

        CASE
            WHEN cb.supports_6k_open_gate = 'Yes' THEN 100
            WHEN cb.supports_4k30 = 'Yes' THEN 70
            ELSE 0
        END AS video_score

    FROM Camera_Base AS cb
    CROSS JOIN Ranges AS r
)

SELECT
    model,
    system,
    lens_configuration,
    megapixels,
    weight_g,
    launch_msrp_usd,
    ibis,
    weather_sealed,
    film_sim_count,

    CAST(
        price_score * 0.25 +
        resolution_score * 0.20 +
        ibis_score * 0.15 +
        weather_score * 0.10 +
        film_score * 0.10 +
        weight_score * 0.10 +
        video_score * 0.10
        AS DECIMAL(10,2)
    ) AS balanced_score,

    CAST(
        resolution_score * 0.25 +
        ibis_score * 0.20 +
        video_score * 0.20 +
        weather_score * 0.15 +
        film_score * 0.10 +
        price_score * 0.05 +
        weight_score * 0.05
        AS DECIMAL(10,2)
    ) AS feature_score,

    CAST(
        weight_score * 0.30 +
        price_score * 0.20 +
        ibis_score * 0.15 +
        weather_score * 0.10 +
        film_score * 0.10 +
        resolution_score * 0.10 +
        video_score * 0.05
        AS DECIMAL(10,2)
    ) AS portability_score

FROM Scores

ORDER BY balanced_score DESC;


--Testing Code
Select top 10 *
from dbo.Cameras;
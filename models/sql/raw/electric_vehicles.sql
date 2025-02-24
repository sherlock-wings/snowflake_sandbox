use role dev_admin_fr;
use schema dev_edw_db.raw;

create table if not exists electric_vehicles (
 vehicle_identification_number varchar(10)
,county_name varchar(200)
,city_name varchar(200)
,postal_code number(5,0)
,model_year number(4,0)
,vehicle_make varchar(50)
,vehicle_model varchar(50)
,electric_vehicle_type varchar(500)
,clean_alternative_fuel_vehicle_eligibility varchar(500)
,electric_range number (20,2)
,base_manufacturer_suggested_price number(20,2)
,legistlative_district number(4,0)
,department_of_licensing_vehicle_id number(20,0)
,vehicle_location geography
,electric_utlity varchar(200)
,_2020_census_tract number(20,0)
);

-- This query extracts dose+durations of norepinephrine administration
-- Total time on the drug can be calculated from this table by grouping using stay_id

DROP MATERIALIZED VIEW IF EXISTS norepinephrine_dose;
CREATE MATERIALIZED VIEW norepinephrine_dose as

-- now we extract the associated data for metavision patients

select
stay_id, linkorderid
, max(rate) as vaso_rate
, sum(amount) as vaso_amount
, min(starttime) as starttime
, max(endtime) as endtime
, (AMOUNTUOM) as amount_uom --took out the min and put in groupby
, (RATEUOM) as rate_uom
from mimiciv_icu.inputevents
where itemid = 221906 -- norepinephrine
and statusdescription != 'Rewritten' -- only valid orders
group by stay_id, linkorderid, AMOUNTUOM, RATEUOM
order by stay_id, starttime
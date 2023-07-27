-- This query extracts dose+durations of phenylephrine administration

DROP MATERIALIZED VIEW IF EXISTS phenylephrine_dose;
CREATE MATERIALIZED VIEW phenylephrine_dose as

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
where itemid = 221749 -- phenylephrine
and statusdescription != 'Rewritten' -- only valid orders
group by stay_id, linkorderid, AMOUNTUOM, RATEUOM
order by stay_id, starttime;
-- This query extracts dose+durations of dopamine administration

DROP MATERIALIZED VIEW IF EXISTS dopamine_dose;
CREATE MATERIALIZED VIEW dopamine_dose as


-- Get drug administration data from CareVue first
--10/12/18 added amountuom as amount_uom, rateuom as rate_uom

with vasocv1 as
(
  select
    stay_id, endtime, amountuom as amount_uom, rateuom as rate_uom
    -- case statement determining whether the ITEMID is an instance of vasopressor usage
    , max(case when itemid in (30043,30307) then 1 else 0 end) as vaso -- dopamine

    -- the 'stopped' column indicates if a vasopressor has been disconnected
    -- , max(case when itemid in (30043,30307)       and stopped in ('Stopped','D/C''d') then 1
    --       else 0 end) as vaso_stopped

    , max(case when itemid in (30043,30307) and rate is not null then 1 else 0 end) as vaso_null
    , max(case when itemid in (30043,30307) then rate else null end) as vaso_rate
    , max(case when itemid in (30043,30307) then amount else null end) as vaso_amount
    --, max(case when itemid in (30043,30307) then amountuom else null end) as amount_uom  --these two lines provide units
	--, max(case when itemid in (30043,30307) then rateuom else null end) as rate_uom

  from mimiciv_icu.inputevents
  where itemid in
  (
        30043,30307 -- dopamine
  )
  group by stay_id, endtime, amountuom, rateuom
)
, vasocv2 as
(
  select v.*
    , sum(vaso_null) over (partition by stay_id order by endtime) as vaso_partition
  from
    vasocv1 v
)
, vasocv3 as
(
  select v.*
    , first_value(vaso_rate) over (partition by stay_id, vaso_partition order by endtime) as vaso_prevrate_ifnull
  from
    vasocv2 v
)
, vasocv4 as
(
select
    stay_id
    , endtime
    -- , (endtime - (LAG(endtime, 1) OVER (partition by stay_id, vaso order by endtime))) AS delta

    , vaso
    , vaso_rate
    , vaso_amount
    -- , vaso_stopped
    , vaso_prevrate_ifnull
    , amount_uom
    , rate_uom

    -- We define start time here
    , case
        when vaso = 0 then null

        -- if this is the first instance of the vasoactive drug
        when vaso_rate > 0 and
          LAG(vaso_prevrate_ifnull,1)
          OVER
          (
          partition by stay_id, vaso, vaso_null
          order by endtime
          )
          is null
          then 1

        -- you often get a string of 0s
        -- we decide not to set these as 1, just because it makes vasonum sequential
        when vaso_rate = 0 and
          LAG(vaso_prevrate_ifnull,1)
          OVER
          (
          partition by stay_id, vaso
          order by endtime
          )
          = 0
          then 0

        -- sometimes you get a string of NULL, associated with 0 volumes
        -- same reason as before, we decide not to set these as 1
        -- vaso_prevrate_ifnull is equal to the previous value *iff* the current value is null
        when vaso_prevrate_ifnull = 0 and
          LAG(vaso_prevrate_ifnull,1)
          OVER
          (
          partition by stay_id, vaso
          order by endtime
          )
          = 0
          then 0

        -- If the last recorded rate was 0, newvaso = 1
        when LAG(vaso_prevrate_ifnull,1)
          OVER
          (
          partition by stay_id, vaso
          order by endtime
          ) = 0
          then 1

        -- If the last recorded vaso was D/C'd, newvaso = 1
        -- when
        --   LAG(vaso_stopped,1)
        --   OVER
        --   (
        --   partition by stay_id, vaso
        --   order by endtime
        --   )
        --   = 1 then 1

        -- ** not sure if the below is needed
        --when (endtime - (LAG(endtime, 1) OVER (partition by stay_id, vaso order by endtime))) > (interval '4 hours') then 1
      else null
      end as vaso_start

FROM
  vasocv3
)
-- propagate start/stop flags forward in time
, vasocv5 as
(
  select v.*
    , SUM(vaso_start) OVER (partition by stay_id, vaso order by endtime) as vaso_first
FROM
  vasocv4 v
)
, vasocv6 as
(
  select v.*
    -- We define end time here
    , case
        when vaso = 0
          then null

        -- If the recorded vaso was D/C'd, this is an end time
        -- when vaso_stopped = 1
        --   then vaso_first

        -- If the rate is zero, this is the end time
        when vaso_rate = 0
          then vaso_first

        -- the last row in the table is always a potential end time
        -- this captures patients who die/are discharged while on vasopressors
        -- in principle, this could add an extra end time for the vasopressor
        -- however, since we later group on vaso_start, any extra end times are ignored
        when LEAD(endtime,1)
          OVER
          (
          partition by stay_id, vaso
          order by endtime
          ) is null
          then vaso_first

        else null
        end as vaso_stop
    from vasocv5 v
)

-- -- if you want to look at the results of the table before grouping:
-- select
--   stay_id, endtime, vaso, vaso_rate, vaso_amount
--     , vaso_stopped
--     , vaso_start
--     , vaso_first
--     , vaso_stop
-- from vasocv6 order by stay_id, endtime;

, vasocv7 as
(
select
  stay_id
  , endtime as starttime
  , lead(endtime) OVER (partition by stay_id, vaso_first order by endtime) as endtime
  , vaso, vaso_rate, vaso_amount, vaso_stop, vaso_start, vaso_first , amount_uom, rate_uom
from vasocv6
where
  vaso_first is not null -- bogus data
and
  vaso_first != 0 -- sometimes *only* a rate of 0 appears, i.e. the drug is never actually delivered
and
  stay_id is not null -- there are data for "floating" admissions, we don't worry about these
)
-- table of start/stop times for event
, vasocv8 as
(
  select
    stay_id
    , starttime, endtime
    , vaso, vaso_rate, vaso_amount, vaso_stop, vaso_start, vaso_first, amount_uom, rate_uom
  from vasocv7
  where endtime is not null
  and vaso_rate > 0
  and starttime != endtime
)
-- collapse these start/stop times down if the rate doesn't change
, vasocv9 as
(
  select
    stay_id
    , starttime, endtime, amount_uom, rate_uom
    , case
        when LAG(endtime) OVER (partition by stay_id order by starttime, endtime) = starttime
        AND  LAG(vaso_rate) OVER (partition by stay_id order by starttime, endtime) = vaso_rate
        THEN 0
      else 1
    end as vaso_groups
    , vaso, vaso_rate, vaso_amount, vaso_stop, vaso_start, vaso_first
  from vasocv8
  where endtime is not null
  and vaso_rate > 0
  and starttime != endtime
)
, vasocv10 as
(
  select
    stay_id
    , starttime, endtime, amount_uom, rate_uom
    , vaso_groups
    , SUM(vaso_groups) OVER (partition by stay_id order by starttime, endtime) as vaso_groups_sum
    , vaso, vaso_rate, vaso_amount, vaso_stop, vaso_start, vaso_first
  from vasocv9
)
, vasocv as
(
  select stay_id
  , min(starttime) as starttime
  , max(endtime) as endtime
  , vaso_groups_sum
  , vaso_rate
  , amount_uom
  , rate_uom
  , sum(vaso_amount) as vaso_amount
  from vasocv10
  group by stay_id, vaso_groups_sum, vaso_rate, amount_uom, rate_uom --added amount and rate uom to groupby
)
-- now we extract the associated data for metavision patients
-- , vasomv as
-- (
--   select
--     stay_id, linkorderid
--     , max(rate) as vaso_rate
--     , sum(amount) as vaso_amount
--     , min(starttime) as starttime
--     , max(endtime) as endtime
--     , (AMOUNTUOM) as amount_uom --took out the min and put in groupby
--     , (RATEUOM) as rate_uom
--   from mimiciii.inputevents_mv
--   where itemid = 221662 -- dopamine
--   and statusdescription != 'Rewritten' -- only valid orders
--   group by stay_id, linkorderid, AMOUNTUOM, RATEUOM
-- )
-- now assign this data to every hour of the patient's stay
-- vaso_amount for carevue is not accurate
SELECT stay_id
  , starttime, endtime
  , vaso_rate, vaso_amount, amount_uom, rate_uom
from vasocv
-- UNION
-- SELECT stay_id
--   , starttime, endtime
--   , vaso_rate, vaso_amount, amount_uom, rate_uom
-- from vasomv
order by stay_id, starttime;

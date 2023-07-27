select ie.stay_id, tt.starttime
    , 1 as RRT
  from mimiciv_icu.icustays ie
  inner join mimiciv_icu.inputevents tt
    on ie.stay_id = tt.stay_id
    --and tt.starttime between ie.intime and ie.intime + interval '1' day
    and itemid in
    (
        227536 --   KCl (CRRT)  Medications inputevents_mv  Solution
      , 227525 --   Calcium Gluconate (CRRT)    Medications inputevents_mv  Solution
    )
    and amount > 0 -- also ensures it's not null
  --group by ie.icustay_id, tt.starttime
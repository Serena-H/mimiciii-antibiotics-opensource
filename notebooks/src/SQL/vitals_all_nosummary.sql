DROP MATERIALIZED VIEW IF EXISTS vitals_all_nosummary CASCADE;
create materialized view vitals_all_nosummary as SELECT *

FROM  (
  select ie.subject_id, ie.hadm_id, ie.stay_id, ce.charttime, ce.valueuom --added ce.charttime  10/12/18 added ce.valueuom
  , case
    when itemid in (211,220045) and valuenum > 0 and valuenum < 300 then 'HeartRate' -- HeartRate
    when itemid in (51,442,455,6701,220179,220050) and valuenum > 0 and valuenum < 400 then 'SysBP' -- SysBP
    when itemid in (8368,8440,8441,8555,220180,220051) and valuenum > 0 and valuenum < 300 then 'DiasBP' -- DiasBP
    when itemid in (456,52,6702,443,220052,220181,225312) and valuenum > 0 and valuenum < 300 then 'MeanArtPress' -- MeanBP
    when itemid in (615,618,220210,224690) and valuenum > 0 and valuenum < 70 then 'RespRate' -- RespRate
    when itemid in (223761,678) and valuenum > 70 and valuenum < 120  then 'TempF' -- TempF, converted to degC in valuenum call
    when itemid in (223762,676) and valuenum > 10 and valuenum < 50  then 'TempC' -- TempC
    when itemid in (646,220277) and valuenum > 0 and valuenum <= 100 then 'SpO2' -- SpO2
    when itemid in (807,811,1529,3745,3744,225664,220621,226537) and valuenum > 0 then 'Glucose' -- Glucose

    else null end as VitalID
      -- convert F to C
  , case when itemid in (223761,678) then (valuenum-32)/1.8 else valuenum end as valuenum

  from mimiciv_icu.icustays ie
  left join mimiciv_icu.chartevents ce
  on ie.subject_id = ce.subject_id and ie.hadm_id = ce.hadm_id and ie.stay_id = ce.stay_id
  --mimiciv does not have error, we changed it to warning
  and ce.warning IS DISTINCT FROM 1
  where ce.itemid in
  (
  -- HEART RATE
  211, --"Heart Rate"
  220045, --"Heart Rate"

  -- Systolic/diastolic

  51, --    Arterial BP [Systolic]
  442, --   Manual BP [Systolic]
  455, --   NBP [Systolic]
  6701, --  Arterial BP #2 [Systolic]
  220179, --    Non Invasive Blood Pressure systolic
  220050, --    Arterial Blood Pressure systolic

  8368, --  Arterial BP [Diastolic]
  8440, --  Manual BP [Diastolic]
  8441, --  NBP [Diastolic]
  8555, --  Arterial BP #2 [Diastolic]
  220180, --    Non Invasive Blood Pressure diastolic
  220051, --    Arterial Blood Pressure diastolic


  -- MEAN ARTERIAL PRESSURE
  456, --"NBP Mean"
  52, --"Arterial BP Mean"
  6702, --  Arterial BP Mean #2
  443, --   Manual BP Mean(calc)
  220052, --"Arterial Blood Pressure mean"
  220181, --"Non Invasive Blood Pressure mean"
  225312, --"ART BP mean"

  -- RESPIRATORY RATE
  618,--    Respiratory Rate
  615,--    Resp Rate (Total)
  220210,-- Respiratory Rate
  224690, --    Respiratory Rate (Total)


  -- SPO2, peripheral
  646, 220277,

  -- GLUCOSE, both lab and fingerstick
  807,--    Fingerstick Glucose
  811,--    Glucose (70-105)
  1529,--   Glucose
  3745,--   BloodGlucose
  3744,--   Blood Glucose
  225664,-- Glucose finger stick
  220621,-- Glucose (serum)
  226537,-- Glucose (whole blood)

  -- TEMPERATURE
  223762, -- "Temperature Celsius"
  676,  -- "Temperature C"
  223761, -- "Temperature Fahrenheit"
  678 --    "Temperature F"

  )
) pvt;
--group by pvt.subject_id, pvt.hadm_id, pvt.icustay_id
--order by pvt.subject_id, pvt.hadm_id, pvt.icustay_id;
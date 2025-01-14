from pathlib import Path
import pandas as pd

cohort_date= '07242023' #date where final cohort was generated
date= '07242023' #will be used to name files generated

repository_path= Path('c:\\Users\\csfhe\\Documents\\RA\\mimiciii-antibiotics-opensource\\notebooks')
ABrx = pd.read_csv(Path(str(repository_path)+ '/data/raw/csv/07192023_ABrx_updated.csv')) #final prescription list generated by 01-prescription

                                                             
final_pt_df= pd.read_csv(Path(str(repository_path)+ '/data/{}_final_pt_df.csv'.format(cohort_date))) 


#final cohort list filtered to those who have sufficient vitals to be included in study (performed in first part of 03-clinical variables)
final_pt_df_v= pd.read_csv(Path(str(repository_path)+ '/data/{}_final_pt_df_v.csv'.format(cohort_date))) 

########## cohort parameters #########
"""
input: ABrx_16sterile_ntnul_finalPT: final by pt spreadsheet where the first ab prescription meeting the 24hr sc window is listed. 
said another way, using the prescription antibiotic list and the list of dates of ssc cultures, building patient list that annotates first ab within 24 hr of sc for each pt. 

ssc_sql: the primary sql query df for ssc info from mimic (default is to use sterile_pt_df)

blood_only: option to restrict to only blood cultures

n_days, n_day_column: the number of days after t_0 where SSC's will be considered to assign a patient as having a positive or negative.
origionally the criteria was to find SSC cultures within a 3 days window of t_0 (first ab time) and t_0_sc (first ssc time), if any were pos then patient was culture pos, else negative.
we can sepcify column (n_day_column) and day window if we want to look from ICU_admit instead.

first_ssc_after_ICU: allows option to restrict the culture result output to only those after ICU admission. 
filter_t0_after_ICU: allows option to restrict the first antibiotic (t_0) to only those after ICU admission. 
n_filter_days: number of days allowed after ICU admit for an ab (t_0) to occur for patient to be considered, requires  filter_t0_after_ICU=True.
"""
round_SSC_to_date=True
cohort_age_cutoff = 16
blood_only = False
n_days = 3
n_day_column ='t_0_sc'
first_ssc_after_ICU = False
filter_t0_after_ICU = True
n_filter_days = 4

####################################

########## 03, 04, 05, 06 clinical variables cleaning, merging, aggregating parameters #########
save_boolean=True #make True if you want to save the csv for clinical variables generated
time_col="charttime"
time_var= 't_0'
patient_df= final_pt_df 

# ###72 hour window
# ## date:'10102019'##this is just the date i used when i ran each.
# lower_window=0
# upper_window=3
# folder="72_hr_window"

###48 hour window sensitivity
## ## date:'30102019' ##this is just the date i used when i ran each.
# lower_window=0
# upper_window=2
# folder="48_hr_window"

# ##24 hour window sensitivity
## # date:'30102019' ##this is just the date i used when i ran each.
lower_window=0
upper_window=1
folder='24_hr_window'#"24_hr_window_morecases"#"24_hr_window"


###30 day window (for ab free day calc) 
## 
# lower_window=0
# upper_window=30
# folder="30_day_window"


###### 04-clinical variables cleaning parameters ####
''' 
    pt: the by patient spreadsheet be be used to supply patient information.
    time_var: the variable used to create the time window of interest.
    value_fill: the variable value that missing values will be filled if the value is not present (default =0) in the origional dataset
    delta_fill: the time delta value that will be filled in if a patient doesn't have any instances of the label_fill.  
    uom_fill: fills in the unit of measurement to this for missing values.
'''

value_fill=0
delta_fill= pd.to_timedelta('0 days')
uom_fill='y/n'

####################################

######## 06-continuous variable aggregation ##############

categorical= ['race', 'bands', 'pco2',
               'any_vasoactives',"leukocyte","nitrite",#'pao2fio2ratio',
               'vent_recieved',  "dobutamine",'gender',
               "dopamine","epinephrine","norepinephrine",
               "phenylephrine","rrt","vasopressin",
              'cancer_elix','o2_flow' ]

continuous=['daily_sofa','lactate','mingcs',
            'diasbp','heartrate','meanartpress',
            'resprate','sysbp','temperature',
            'hemoglobin','platelet','wbc','calcium',
            'glucose','ph','bicarbonate',
            'bun','chloride','creatinine',
            'inr','potassium','ptt',
            'sodium','bilirubin','spo2',
            'sum_elix','pao2fio2ratio' #added here 11/25/19
           ]
onetime=['yearsold','weight'] #'height'

## for aggregations:
low_value=['bicarbonate',
'diasbp',
'hemoglobin',
'meanartpress',
'mingcs',
'ph',
'platelet',
'spo2',
'sysbp',
'pao2fio2ratio'] #added pao2fio2 here 11/25/19

both_value=['calcium',
'sodium',
'wbc']

hi_value= set([x for x in continuous+onetime if x not in (low_value + both_value) ])


########## 07-modeling #########
#hypertuning & CV parameters
##hypertuning_fxn(x, y, nfolds=10, model=model , param_grid=param_grid, scoring="roc_auc",n_iter = 20, gridsearch=False)
nfolds=10
scoring='roc_auc' #neg_log_loss
n_iter=40 #for gridsearch
gridsearch=False #gridsearch=False means it does triaged hyperparameter combinations based on some algorithm. True= tests all 



continuous_renamed= [
    'bilirubin','bun','chloride',
    'creatinine','glucose','heartrate',
    'inr','lactate','potassium',
    'ptt','resprate','sum_elix',
    'temperature','bicarbonate','diasbp',
    'hemoglobin','meanartpress','mingcs',
    'pao2fio2ratio','ph','platelet',
    'spo2','sysbp','maxCalcium',
    'maxSodium','maxWBC','minCalcium',
    'minSodium','minWBC','weight',
    'yearsold']

####################################

########## 07-visualization #########

n_varimp= 10 #number of variables used in top N variable importance set. 

categorical1= ['race', 'bands', 'pco2',
               'any_vasoactives',#"leukocyte","nitrite",#'pao2fio2ratio',
               'vent_recieved',  "dobutamine",'gender',
               "dopamine","epinephrine","norepinephrine",
               "phenylephrine","rrt","vasopressin",
              'cancer_elix'#,'o2_flow' 
              ]

###################################

# ######### helpful examples #########

# # import csv example:
# import parameters #import ABrx, repository_path
# os.chdir(parameters.repository_path)
# parameters.ABrx.head(5)
# ABrx= parameters.ABrx

# # save csv example: 
# pd.DataFrame(final_pt_df2).to_csv((str(parameters.repository_path)+ '/data/{}_final_pt_df_updated.csv'.format(parameters.date)))
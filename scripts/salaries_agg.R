library(tidyverse)
library(lubridate)
library(rio)
library(janitor)

load_salaries <- function(base_dir, collapse=FALSE){
  
  files <- list.files(base_dir)
  files <- files[str_detect(files, '.csv')]
  
  classified <- list()
  unclassified <- list()
  
  # load csv files
  for (f in files)
    {
    dat <- import(paste(base_dir, f, sep='/'))
    date_str <- str_remove(str_split(f, '_')[[1]][2], '.csv')
    dat$date <- as.Date(date_str, format="%Y-%m-%d")
  
    if (str_detect(f, 'Unclassified')){
      unclassified[[f]] <- dat
    } else {
      classified[[f]] <- dat
    }
  }
  
  # combine lists to data frames
  c_df <- plyr::ldply(classified, data.frame)
  u_df <- plyr::ldply(unclassified, data.frame)
  
  # set type
  c_df$employee_type <- 'classified'
  u_df$employee_type <- 'unclassified'
  
  employees <- as.tbl(bind_rows(c_df, u_df))
  
  # rename columns
  employees %<>% select(-c('.id', 'V16')) %>% 
    janitor::clean_names()
  
  # clean and retype columns
  employees <- employees %>% mutate(
    employee_type = as_factor(employee_type),
    job_type = as_factor(job_type),
    #job_start_date = as.Date(job_start_date, format="%m/%e/%y"),
    pay_department = str_remove(pay_department, '^\\d*\\\n'),
    position_class = str_remove(position_class, '^\\w*\\d*\\\n'),
    salary = as.numeric(str_remove(str_remove(annual_salary_rate, ','), '\\$'))
  ) %>% filter(job_status == "Active") %>% select(-job_status, -annual_salary_rate)
  
  if (collapse==TRUE){
  # combine individual people's salaries within samples,
  # preserving the position that pays the most
  employees <- employees %>% group_by(date, name) %>%
    arrange(desc(salary)) %>%
    mutate(salary = sum(salary)) %>%
    distinct(name, .keep_all=TRUE)
  }
  
  # reorder by date and name
  employees <- employees %>% arrange(
    name, date
  ) %>%   select(
    employee_type, name, date, salary, everything())
  
  # 

  return(employees)
}



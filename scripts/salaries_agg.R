library(tidyverse)
library(lubridate)
library(rio)
library(scales)
library(jcolors)
library(ggthemes)

base_dir <- '/path/to/your/salaries'

files <- list.files(base_dir)
files <- files[str_detect(files, '.csv')]

classified <- list()
unclassified <- list()

# load csv files
for (f in files)
  {
  dat <- import(paste(base_dir, f, sep='/'))
  date_str <- str_remove(str_split(f, '_')[[1]][2], '.csv')
  dat$date <- as.Date(date_str, format="%m%d%y")

  if (str_detect(f, 'Unclassified')){
    unclassified[[f]] <- dat
  } else {
    classified[[f]] <- dat
  }
}


# combine lists to data frames
c_df <- plyr::ldply(classified, data.frame)
u_df <- plyr::ldply(unclassified, data.frame)

# remove inactive employees
u_df$salary <- as.numeric(str_remove(str_remove(u_df$ANNUAL.SALARY.RATE, ','), '\\$'))
u_df <- u_df %>% filter(JOB.STATUS == "Active") %>% filter(!is.na(salary))

c_df$salary <- as.numeric(str_remove(str_remove(c_df$ANNUAL.SALARY.RATE, ','), '\\$'))
c_df <- c_df %>% filter(JOB.STATUS == "Active") %>% filter(!is.na(salary))

# combine individual people
c_df_name <- c_df %>% group_by(date, NAME) %>% 
  arrange(desc(salary)) %>%
  summarize(salary = sum(salary),
            dept = HOME.DEPARTMENT[1],
            class=EEO.CATEGORY[1])

c_summary <- c_df_name %>% group_by(date) %>%
  summarize(sum_wages=sum(salary),
            mean_wages = mean(salary),
            class=class[1]) %>%
  filter(!is.na(date))
c_summary$class = "Classified Employees"

# set a few grouping variables.
u_df[u_df$ACADEMIC.TITLE %in% c("President", "President Emeritus"),]$EEO.CATEGORY <- "President"
u_df[u_df$ACADEMIC.TITLE %in% c("Dir Intercollegiate Athletics"),]$EEO.CATEGORY <- "Athletic Director"
u_df[u_df$APPT.STATUS == "Indefinite Tenure" & u_df$EEO.CATEGORY=="Faculty",]$EEO.CATEGORY <- "Tenured Faculty"

# do the same w/ the unclassified staff
u_df_name <- u_df %>% group_by(date, NAME) %>%
  arrange(desc(salary)) %>%
  summarize(salary = sum(salary),
            dept=HOME.DEPARTMENT[1],
            class=EEO.CATEGORY[1])


u_summary <- u_df_name %>% group_by(date, class) %>%
  summarize(sum_wages=sum(salary),
            mean_wages = mean(salary))

# since there's only one president, mean wages are sum wages.
u_summary[u_summary$class=="President",]$mean_wages <- u_summary[u_summary$class=="President",]$sum_wages

# manually create df of GE wages from available old CBAs
ge_summary <- data.frame(
  date = c("2002-09-16", "2003-09-16", "2004-09-16", "2005-09-01", "2010-09-16", "2016-09-16", "2017-09-16", "2018-09-16"),
  mean_wages = c(3046*3, 3168*3, 3168*3, 3232*3, ((3232+4736)/2)*3, 4736*3, 4902*3, 5083*3)
)
ge_summary$date <- as.Date(ge_summary$date, format="%Y-%m-%d")
ge_summary$class <- "Graduate Employees"
ge_summary$sum_wages <- NA

# combine all summaries
all_summary <- bind_rows(u_summary, c_summary, ge_summary)

all_summary[all_summary$class=="Exec/Admin/Mgr",]$class <- "Executive Admins"

#subset for plotting
all_summary_filt <- all_summary %>% 
  filter(class %in% c("Classified Employees",
                      "President",
                      "Executive Admins",
                      "Tenured Faculty",
                      "Faculty",
                      "Graduate Employees"))

# rename presidents that are michael schill as such
all_summary_filt[all_summary_filt$date> ymd("2014-02-01") & 
                   all_summary_filt$class=="President",]$class <- "Schill"

all_summary_filt$class <- ordered(all_summary_filt$class, 
                                  levels=c("Graduate Employees",
                                           "Classified Employees",
                                           "Faculty",
                                           "Tenured Faculty",
                                           "Executive Admins",
                                           "President"))


#########
# initial plot

cpal <- c("#ff0000", "#fbcb0a","#00a0dd","#f0a05d", "#6cbd45", "#fb6cff")

g.salary <- ggplot(all_summary_filt)+
  scale_y_continuous(labels=dollar)+
  geom_point(aes(x=date, y=mean_wages, color=class))+
  geom_smooth(aes(x=date, y=mean_wages, color=class), se=FALSE,
              span=1)+
  scale_color_manual(values = cpal)+
  scale_x_date(limits=as.Date(c("2010-01-01", "2019-01-01"), format="%Y-%m-%d"))+
  theme_minimal()+
  theme(
    panel.grid.minor = element_blank(),
        panel.grid.major.x = element_blank(),
        axis.ticks.x=element_line())

ggsave(paste(base_dir, "salary_plot_tenured_16x9.png", sep="/"), g.salary, 
       width=7, height=9*(9/16), units="in")

#########
# no president schill, jsut admins

all_summary_admins <- all_summary_filt %>% filter(!(class %in% c("President", "Schill")))

g.salary_admins <- ggplot(all_summary_admins)+
  scale_y_continuous(labels=dollar)+
  geom_point(aes(x=date, y=mean_wages, color=class))+
  geom_smooth(aes(x=date, y=mean_wages, color=class), se=FALSE,
              span=1)+
  scale_color_manual(values = cpal)+
  scale_x_date(limits=as.Date(c("2010-01-01", "2019-01-01"), format="%Y-%m-%d"))+
  theme_minimal()+
  theme(
    panel.grid.minor = element_blank(),
    panel.grid.major.x = element_blank(),
    axis.ticks.x=element_line(),
    legend.position = "none")

ggsave(paste(base_dir, "salary_plot_admin_16x9.pdf", sep="/"), g.salary_admins, 
       width=7, height=9*(9/16), units="in", useDingbats=FALSE)


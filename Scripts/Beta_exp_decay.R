
######################################################################################
# Load libraries
######################################################################################

# wrangling
suppressMessages(library(data.table)) # data table manipulation
suppressMessages(library(dplyr)) # Data wrangling
suppressMessages(library(tidyr)) # Data wrangling
suppressMessages(library(stringr)) # Data wrangling

# Visualization
suppressMessages(library(plotly)) # animated visualization

# !diagnostics off
options(scipen=999)

######################################################################################
# Working directory and environment
######################################################################################

rm(list = ls())
setwd('C:/Users/Parikshit_verma/Documents/GitHub/Covid-19/')

######################################################################################
# Functions
######################################################################################

edecay_predict<-function(data,horizon,plot=FALSE){
  
  # Initialize theta
  theta.0 <- min(data$Beta) * 0.5
  
  # Estimate the rest parameters using a linear model
  model.0 <- lm(log(Beta - theta.0) ~ Day, data=data)  
  alpha.0 <- exp(coef(model.0)[1])
  beta.0 <- coef(model.0)[2]
  
  start <- list(alpha = alpha.0, beta = beta.0, theta = theta.0)
  model <- nls(Beta ~ alpha * exp(beta * Day) + theta , 
               data = data, 
               start = start,
               control = list(maxiter = 100,warnOnly = TRUE))
  
  # Plot
  if(plot){
    
    plot(data$Day, data$Beta)
    lines(data$Day, predict(model, list(x = data$Day)), col = 'skyblue', lwd = 3)
  }
  
  # Predict
  pred_start<-max(data$Day)+1
  beta_pred<-cbind(seq(pred_start,pred_start+horizon),
                   predict(model,as.data.frame(seq(pred_start,pred_start+horizon)) %>% setNames(c('Day')))) %>%
             as.data.frame() %>%
             mutate(State = data$State[1]) %>%
             setNames(c('Day','Beta','State')) %>%
             dplyr::select(c('State','Day','Beta'))
  
  return(beta_pred)
}

######################################################################################
# Read data
######################################################################################

covid_us_st<-read.csv('Output/Estimation/US_state_beta.csv',stringsAsFactors = FALSE)
covid<-read.csv('Output/Estimation/Global_beta.csv',stringsAsFactors = FALSE)

######################################################################################
# Forecast
######################################################################################

for (k in 1:2){
  
  if(k == 1){
    covid_data<-covid %>% dplyr::rename(State = Country)
  }else{
    covid_data<-covid_us_st
  } 
  
  states<-unique(covid_data$State)
  horizon = 150
  filter = 7
  
  for (i in 1:length(states)){
    
    print(paste0(states[i],'...',i,' of ',length(states)))
    
    covid_sub<-covid_data %>%
               filter(State == states[i] & Day != 0 & Beta != 0) %>%
               dplyr::select(c('State','Day','Beta'))

    if(nrow(covid_sub) == 0) next
    
    if(nrow(covid_sub) > filter) covid_sub<-covid_sub %>% dplyr::slice((nrow(.)-filter):nrow(.)) 
    
    covid_sub<-edecay_predict(covid_sub,horizon)
    
    if(i == 1){
      beta_fcst<-covid_sub
    }else{
      beta_fcst<-rbind(beta_fcst,covid_sub)
    }
  }
  
  if(k == 1){
    beta_global_fcst<-beta_fcst %>%
                      dplyr::rename(Country = State)
  }else{
    beta_us_fcst<-beta_fcst
  } 
}

rm(beta_fcst,covid_data,covid_sub,
   filter,horizon,i,k,states)

######################################################################################
# Write to file
######################################################################################

write.csv(beta_global_fcst,'Output/Prediction/Beta_global_prediction.csv',row.names = FALSE)
write.csv(beta_us_fcst,'Output/Prediction/Beta_US_state_prediction.csv',row.names = FALSE)

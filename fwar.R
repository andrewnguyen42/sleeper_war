library(httr)
library(dplyr)
library(purrr)
library(stringr)
library(tidyr)
library(readr)

#only run players.R once
#source('players.R')
players <- read_csv('players.csv')

username <- 'andrewnguyen42'
week_max <- 9
season <- 2019

include_injuries <- TRUE #if you want to assume the average WAR when a player is injured, set to FALSE


user_id <- str_interp('https://api.sleeper.app/v1/user/${username}') %>%
  httr::GET() %>%
  content() %>%
  pluck('user_id')

league_id <- str_interp('https://api.sleeper.app/v1/user/${user_id}/leagues/nfl/${season}') %>%
  GET %>%
  content %>%
  pluck(1, 'league_id')

league_scoring_settings <- str_interp('https://api.sleeper.app/v1/user/${user_id}/leagues/nfl/${season}') %>%
  GET %>%
  content %>%
  pluck(1, 'scoring_settings') %>%
  as_tibble() %>%
  gather('scoring_type', 'value')


get_week_stats <- function(week, only_starters = FALSE){
  matchups_api_call <- str_interp('https://api.sleeper.app/v1/league/${league_id}/matchups/${week}') %>%
    GET %>%
    content() 
  
  matchups <- map(matchups_api_call, function(matchup){
    matchup %>% 
      list_modify(custom_points = zap(), players = NA) %>%
      as_tibble() %>%
      mutate(player_id = map_chr(starters, identity)) %>%
      select(roster_id
             , points
             , player_id
             , matchup_id)}) %>% 
    bind_rows() %>%
    mutate(week = week)
  
  week_stats_api <- str_interp('https://api.sleeper.app/v1/stats/nfl/regular/${season}/${week}') %>%
    GET() %>%
    content() 
  
  week_stats <- week_stats_api %>% 
    bind_rows() %>% 
    mutate(player_id =  names(week_stats_api)) %>%
    mutate(week = week) %>%
    gather('scoring_type', 'stat', -player_id, -week)
  
  if(only_starters){
    week_stats %>% 
      inner_join(league_scoring_settings, by = 'scoring_type') %>%
      inner_join(matchups, by = c("player_id", "week")) %>%
      select(-points)
  }else{
    week_stats %>% 
      inner_join(league_scoring_settings, by = 'scoring_type') 
  }

}

get_week_stats_starters <- partial(get_week_stats, only_starters = TRUE)

season_stats_starters <- map(1:week_max, get_week_stats_starters) %>%
  bind_rows() %>%
  inner_join(players, by = "player_id") %>%
  mutate(points = stat * value)

season_summary_team <- season_stats_starters %>%
  group_by(week, roster_id) %>%
  summarise(total_points = sum(points, na.rm = TRUE)) %>%
  summarise(mean = mean(total_points)
            , sd = sd(total_points)) %>%
  mutate(distribution_function = map2(mean, sd, function(mean, sd){
    partial(pnorm, mean = mean, sd = sd)}))

season_summary_position <- season_stats_starters %>% 
  filter(!is.na(points)) %>%
  group_by(position, week, player_id)  %>% 
  summarise(total_points = sum(points, na.rm = TRUE)) %>%
  summarise(total_pos_points = sum(total_points)
             , mean = mean(total_points)
             , median = median(total_points)
             , sd = sd(total_points)) 


players_stats_all <- map(1:week_max, get_week_stats) %>%
  bind_rows() %>%
  inner_join(players, by = "player_id") %>%
  mutate(points = stat * value) %>%
  group_by(player_id, first_name, last_name, week, position) %>%
  summarise(player_points = sum(points, na.rm = TRUE))


war_player_week <- players_stats_all %>%
  inner_join(season_summary_position, by = c("week", "position")) %>%
  inner_join(season_summary_team, by = 'week', suffix = c('_position', '_team')) %>%
  mutate(position_diff = player_points - mean_position
         , replacement_total = mean_team + position_diff
         , p_win = map2_dbl(replacement_total, distribution_function, function(replacement_total, distribution_function){
           distribution_function(replacement_total)
         })) %>%
  select(-total_pos_points, -median, -sd_position, -distribution_function) 

war_player <- war_player_week %>%
  ungroup %>%
  group_by(player_id, first_name, last_name, position) %>%
  filter(include_injuries | player_points > 0) %>%
  summarise(war = if_else(include_injuries, mean(p_win)*n(),  mean(p_win) * week_max))
  
write_csv(war_player, str_interp('${username}_${season}_through_${week_max}.csv'))

  
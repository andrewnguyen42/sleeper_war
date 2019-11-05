library(httr)
library(dplyr)
library(purrr)
library(stringr)
library(roomba)
library(tidyr)

load('data/players.Rdata')

username <- httr::GET('https://api.sleeper.app/v1/user/andrewnguyen42') %>%
  content() %>%
  pluck('user_id')

league_id <- str_interp('https://api.sleeper.app/v1/user/${username}/leagues/nfl/2019') %>%
  GET %>%
  content %>%
  pluck(1, 'league_id')

league_scoring_settings <- str_interp('https://api.sleeper.app/v1/user/${username}/leagues/nfl/2019') %>%
  GET %>%
  content %>%
  pluck(1, 'scoring_settings') %>%
  as_tibble() %>%
  gather('scoring_type', 'value')

week_max <- 8

get_week_stats <- function(week){
  matchups_api_call <- str_interp('https://api.sleeper.app/v1/league/${league_id}/matchups/${week}') %>%
    GET %>%
    content() 
  
  matchups <- map(matchups_api_call, function(matchup){
    matchup %>% 
      list_modify(custom_points = zap(), starters = NA) %>%
      as_tibble() %>%
      mutate(players = map_chr(players, identity)) %>%
      select(roster_id
             , points
             , players
             , matchup_id)}) %>% 
    bind_rows() %>%
    mutate(week = week)
  
  week_stats_api <-str_interp('https://api.sleeper.app/v1/stats/nfl/regular/2019/${week}') %>%
    GET() %>%
    content() 
  
  week_stats <- week_stats_api %>% 
    bind_rows() %>% 
    mutate(player_id =  names(week_stats_api)) %>%
    mutate(week = week) %>%
    gather('scoring_type', 'stat', -player_id, -week)
  
  week_stats %>% 
    inner_join(league_scoring_settings, by = 'scoring_type') 
}

season_stats <- map(1:week_max, get_week_stats) %>%
  bind_rows() %>%
  inner_join(players) %>%
  mutate(points = stat * value)

season_stats %>% 
  filter(!is.na(points), points > 0) %>%
  group_by(position, week, player_id)  %>% 
  summarise(total_points = sum(points, na.rm = TRUE)) %>%
  summarise(total_pos_points = sum(total_points)
             , mean = mean(total_points)
             , sd = sd(total_points)) %>%
  View
  
  
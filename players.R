players_api <- httr::GET('https://api.sleeper.app/v1/players/nfl') %>%
  content()

players <- map(players_api, function(player){
  cols <- c(position = NA_character_)
  position <- pluck(player, 'position')
  
  player[c("player_id", "first_name", "last_name")] %>%
    as_tibble %>% 
    mutate(position = position) }
  ) %>%
  bind_rows()

save(players, file = 'data/players.Rdata')


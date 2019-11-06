# What is this project?

This is an R script that will compute Wins Above Replacement (WAR) for *your* Sleeper fantasy football league rosters. WAR for fantasy football is highly dependent on your league settings and is not widely available.

# How do I use this code?

0) Install R
1) Install all the packages used in this script: `httr`,`dplyr`,`purrr`,`stringr`,`tidyr` and `readr`
2) Edit the parameters `username`, `weeks` and `season` at the top of `fwar.R`
3) Run `fwar.R` and the script will output a .csv file with WAR for every player

# What is WAR?

WAR is a statistic that computes how many wins a player is responsible for *above* an average player at his position. WAR is a measure of consistency, as WAR is made up by multiplying two factors.

1) The average probability of winning if you played player X and a bunch of average players
2) The number of games player X has played in

A really nice, intuitive article on WAR in fantasy leagues can be found in this [FantasyPros article](https://www.fantasypros.com/2019/08/introducing-fantasy-football-wins-above-replacement-war-2019-fantasy-football/)

#!/usr/bin/env bash

folder_ig=~/Dropbox/projects/2020-SquaredForWork/instagram
folder_tt=~/Dropbox/projects/2020-SquaredForWork/tiktok
credits="Concept: @squaredforwork\nmusic: soundcloud.com/pforret"
./sfw_movie.sh -1 "$folder_ig" -2 "$folder_tt" -c "$credits" imdb top -
./sfw_movie.sh -1 "$folder_ig" -2 "$folder_tt" -c "$credits" imdb coming -
./sfw_movie.sh -1 "$folder_ig" -2 "$folder_tt" -c "$credits" imdb newtop -
./sfw_movie.sh -o "Guess the TV series?" -1 "$folder_ig" -2 "$folder_tt" -c "$credits" imdb tv -

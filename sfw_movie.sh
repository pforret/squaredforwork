#!/usr/bin/env bash

### Created by Peter Forret ( pforret ) on 2020-11-24
script_version="0.0.0"  # if there is a VERSION.md in this script's folder, it will take priority for version number
readonly script_author="peter@forret.com"
readonly script_creation="2020-11-24"
readonly run_as_root=-1 # run_as_root: 0 = don't check anything / 1 = script MUST run as root / -1 = script MAY NOT run as root

list_options() {
echo -n "
#commented lines will be filtered
flag|h|help|show usage
flag|q|quiet|no output
flag|v|verbose|output more
flag|f|force|do not ask for confirmation (always yes)
option|b|border|add border to original image|0
option|c|copy|copy output files to this folder|
option|e|extension|output extension|m4v
option|l|log_dir|folder for log files |log
option|o|opening|opening text|Guess the movie?
option|p|steps|steps done by primitive|600
option|r|resize|resize WxH|120x180
option|t|tmp_dir|folder for temp files|.tmp
option|x|export|export for tiktok/instagram/...|
param|1|action|action to perform: image/imdb
param|?|input|input image/film name
param|?|output|output file
" | grep -v '^#'
}

#####################################################################
## Put your main script here
#####################################################################

main() {
    log "Program: $script_basename $script_version"
    log "Updated: $prog_modified"
    log "Run as : $USER@$HOSTNAME"
    # add programs that need to be installed, like: tar, wget, ffmpeg, rsync, convert, curl ...
    require_binaries tput uname convert primitive ffmpeg identify curl htmlq

    action=$(lower_case "$action")
    case $action in
    image )
        # shellcheck disable=SC2154
        image2movie "$input" "$output"
        ;;

    imdb )
        film_image=$(get_imdb_poster "$input")
        image2movie "$film_image" "$output"
        ;;

    *)
        die "action [$action] not recognized"
    esac
}

#####################################################################
## Put your helper scripts here
#####################################################################

image2movie(){
  # $1 = input image
  # $2 = output image
  log "image2movie [$1] [$2]"
  local input="$1"
  local output="$2"
  if [[ "$output" == "-" ]] || [[ "$output" == "" ]] ; then
    log "Input = [$input]"
    local binput=$(basename "$input" .jpg | sed 's| |-|')
    log "Basename = [$binput]"
    output="output/$(date '+%Y-%m-%d')_$binput.$extension"
    folder_prep "output" 30
  fi
  log "Output = [$output]"

  smalljpg="$tmp_dir/$binput.small.jpg"
  if [[ ! -f "$smalljpg" ]] ; then
    progress "Resize input image to $resize: [$smalljpg]"
    convert "$input"  -bordercolor black -border $border -resize ${resize}^ -gravity center -crop ${resize}+0+0 +repage "$smalljpg"
  fi

  gifreveal="$tmp_dir/$binput.prim.$steps.gif"
  if [[ ! -f "$gifreveal" ]] ; then
    progress "Create animated gif with primitive: [$gifreveal]"
    width=$(echo "$resize" | cut -dx -f1)
    primitive -i "$smalljpg" -o "$gifreveal" -s 1200 -r $width -n $steps -m 7 -bg FFFFFF
  fi
  video_details "$gifreveal"

  movreveal="$tmp_dir/$binput.prim.$steps.mp4"
  if [[ ! -f "$movreveal" ]] ; then
    progress "Convert GIF to MOV: [$movreveal]"
    # -vf "drawtext=text='Guess the movie?':x=(w-text_w)/2:y=(h-text_h)/2:fontsize=24:fontcolor=white"
    ffmpeg -i "$gifreveal" -vcodec libx264 -pix_fmt yuv420p -t 40 -r 12 \
      -filter_complex "[0]split[base][text]; [text]drawtext=text='$opening': fontcolor=black:fontsize=150:fontfile=fonts/AmaticSC-Bold.ttf:x=(w-text_w)/2:y=(h-text_h)/2,format=yuv420p,fade=t=out:st=3:d=1:alpha=1[subtitles]; [base][subtitles]overlay" \
      -y "$movreveal"  2> /dev/null
  fi
  video_details "$movreveal"

  lastframe="$tmp_dir/$binput.last.$steps.jpg"
  if [[ ! -f "$lastframe" ]] ; then
    progress "Get last frame from gif: [$lastframe]"
    ffmpeg -sseof -3 -i "$movreveal" -update 1 -q:v 1 -y "$lastframe"  2> /dev/null
  fi

  gifsize=$(identify -verbose "$lastframe" | awk '/Geometry/ {print $2}' | cut -d+ -f1)
  sharpframe="$tmp_dir/$binput.sharp.jpg"
  if [[ ! -f "$sharpframe" ]] ; then
    progress "Get sharp frame from input: [$sharpframe]"
    convert "$input" -bordercolor black -border $border -resize ${gifsize}^ -gravity center -crop ${gifsize}+0+0 +repage \
      -font fonts/AmaticSC-Bold.ttf -fill white -gravity North  -pointsize 32 -undercolor "rgba(0,0,0,0.5)" \
      -annotate +0+8 '< Concept: @squaredforwork - Music: www.bensound.com >' \
    "$sharpframe" 2> /dev/null
  fi

  xfade="$tmp_dir/$binput.xfade.$steps.mp4"
  if [[ ! -f "$xfade" ]] ; then
    progress "Create x-fade to sharp: [$xfade]"
    length=4

    ffmpeg -loop 1 -i "$lastframe" -loop 1 -i "$sharpframe" -r 12 -vcodec libx264 -pix_fmt yuv420p \
      -filter_complex "[1:v][0:v]blend=all_expr='A*(if(gte(T,$length),1,T/$length))+B*(1-(if(gte(T,$length),1,T/$length)))'" \
      -t $length -y "$xfade"  2> /dev/null
  fi
  video_details "$xfade"

  concat="$tmp_dir/$binput.concat.$steps.mp4"
  if [[ ! -f "$concat" ]] ; then
    progress "Concat both videos: [$concat]"
    playlist="$tmp_dir/$(basename $2 .$extension).playlist.txt"
    echo "file '$(basename $movreveal)'" > "$playlist"
    echo "file '$(basename $xfade)'" >> "$playlist"
    ffmpeg -f concat -safe 0 -i "$playlist" -c copy -y "$concat"  2> /dev/null
    rm "$playlist"
  fi
  video_details "$concat"

  if [[ ! -f "$output" ]] ; then
    progress "Add audio to video: [$output]"
    ffmpeg -i "$concat" -i "audio/bensound-adventure.mp3" -t 44 -af "afade=t=out:st=40:d=4" -y "$output"  2> /dev/null
  fi
  video_details "$output"
  [[ -n "$copy" ]] && cp "$output" "$copy/"

  case "$export" in
    instagram|ig )
      newvideo=$(echo "$output" | sed "s/$extension/instagram.$extension/")
      width=1080
      height=1350
      if [[ ! -f "$newvideo" ]] ; then
        progress "generate [$newvideo]"
        ffmpeg -i "$output" \
          -vf "scale=$width:$height:force_original_aspect_ratio=decrease,pad=$width:$height:(ow-iw)/2:(oh-ih)/2" \
          -y "$newvideo" \
          2> /dev/null
      fi 
      video_details "$newvideo"
      [[ -n "$copy" ]] && cp "$newvideo" "$copy/"

      ;;
    tiktok|tt )
      newvideo=$(echo "$output" | sed "s/$extension/tiktok.$extension/")
      width=1080
      height=1920
      if [[ ! -f "$newvideo" ]] ; then
        progress "generate [$newvideo]"
        ffmpeg -i "$2" \
          -vf "scale=$width:$height:force_original_aspect_ratio=decrease,pad=$width:$height:(ow-iw)/2:(oh-ih)/2" \
          -y "$newvideo" \
          2> /dev/null
      fi 
      video_details "$newvideo"
      [[ -n "$copy" ]] && cp "$newvideo" "$copy/"
      ;;
    *)
  esac

  rm "$smalljpg" "$movreveal" "$lastframe" "$sharpframe" "$xfade" "$concat"
}

get_imdb_poster(){
  folder_prep done 365
  # $1  = source
  chosen=0
  while [[ $chosen -eq 0 ]] ; do
    titleid=$(pick_random_imdb "$1")
    log "check title $titleid ..."
    if [[ ! -f done/$titleid.done.txt ]] ; then
      poster_image=$(download_imdb_poster "$titleid")
      if [[ -n "$poster_image" ]] ; then
        chosen=1
        date > done/$titleid.done.txt
      fi
    fi
  done
  echo "$poster_image"
  # found a $titleid that has not been used before
}

download_imdb_poster(){
  # $1 = tt99999 movie id
  # e.g. https://www.imdb.com/title/tt8503618/
  # <img alt="Hamilton Poster" src="https://m.media-amazon.com/images/M/MV5BNjViNWRjYWEtZTI0NC00N2E3LTk0NGQtMjY4NTM3OGNkZjY0XkEyXkFqcGdeQXVyMjUxMTY3ODM@._V1_UX182_CR0,0,182,268_AL_.jpg" title="Hamilton Poster">

  title=$(curl -s "https://www.imdb.com/title/$1/" \
  | htmlq a \
  | grep ' Poster' \
  | htmlq -a title img \
  | sed 's/ Poster//')
  [[ -z "$title" ]] && return ""
  log "Movie title: [$title]"

  # find image page for poster
  page_poster=$(curl -s "https://www.imdb.com/title/$1/" \
  | htmlq -a href a \
  | grep /title \
  | grep mediaviewer \
  | head -1)
  [[ -z "$page_poster" ]] && return ""
  page_poster="https://www.imdb.com$page_poster"
  log "Poster page = [$page_poster]"

  img_poster=$(curl -s "$page_poster" \
  | htmlq -a src img \
  | head -1)
  [[ -z "$img_poster" ]] && return ""
  log "Poster image = [$img_poster]"
 
  poster=image/$1.$(tokenize "$title").jpg
  log "Save to [$poster]"
  curl -s "$img_poster" -o "$poster"
  echo "$poster"
}

pick_random_imdb(){
    source_url=
  case "$1" in
    box )       source_url="https://www.imdb.com/chart/boxoffice" ;;
    coming )    source_url="https://www.imdb.com/movies-coming-soon/" ;;
    future )    source_url="https://www.imdb.com/chart/moviemeter" ;;
    newtop )    source_url="https://www.imdb.com/chart/top/?sort=us,desc&mode=simple&page=1" ;;
    newtv )     source_url="https://www.imdb.com/chart/tvmeter?sort=us,desc&mode=simple&page=1" ;;
    top )       source_url="https://www.imdb.com/chart/top/" ;;
    tv )        source_url="https://www.imdb.com/chart/tvmeter" ;;
    * )         source_url="https://www.imdb.com/chart/top/"
  esac

  if [[ "$1" == "random" ]] ; then
  source_url=$(cat <<END | shuf -n 1
https://www.imdb.com/chart/boxoffice
https://www.imdb.com/chart/boxoffice?sort=us,desc&mode=simple&page=1
https://www.imdb.com/chart/moviemeter
https://www.imdb.com/chart/moviemeter?sort=us,desc&mode=simple&page=1
https://www.imdb.com/chart/top/
https://www.imdb.com/chart/top/?sort=us,desc&mode=simple&page=1
https://www.imdb.com/movies-coming-soon/
https://www.imdb.com/movies-coming-soon/?sort=us,desc&mode=simple&page=1
END
)
  fi

  curl -s "$source_url" \
  | htmlq a \
  | grep "/title/tt" \
  | grep -Eo "(tt[0-9]+)" \
  | sort -u \
  | shuf -n 1
}

video_details(){
  # $1 = video file
  # Input #0, gif, from '.tmp/2020-11-25_bad-boys.primitive.gif':
  # Duration: 00:00:49.50, start: 0.000000, bitrate: 3765 kb/s
  #   Stream #0:0: Video: gif, bgra, 800x1200, 2 fps, 2 tbr, 100 tbn

  # Input #0, mpegts, from '.tmp/2020-11-25_bad-boys.xfade.mts':
  # Duration: 00:00:05.00, start: 1.566667, bitrate: 1543 kb/s
  # Program 1 
  #   Metadata:
  #     service_name    : Service01
  #     service_provider: FFmpeg
  #   Stream #0:0[0x100]: Video: h264 (High) ([27][0][0][0] / 0x001B), yuv420p(progressive), 800x1200 [SAR 1:1 DAR 2:3], 12 fps, 12 tbr, 90k tbn, 24 tbc

  fname=$(basename "$1")
  ffmpeg -i "$1" 2>&1 \
  | tr ',' "\n" \
  | tr '[' "\n" \
  | awk -v fname="$fname" '
  /Duration:/ {gsub(/00:/,""); printf("%-40s: %s sec ",fname,$0);} 
  /[0-9][0-9]+x[0-9]+/ {printf("%s ",$0);} 
  /[0-9]+ fps/ {printf("%s ",$0);} 
  END {print "               "}'
}

tokenize(){
  lower_case "$1" \
  | sed 's/[^0-9a-z_\s ]//g' \
  | sed 's/ /-/g'
}
#####################################################################
################### DO NOT MODIFY BELOW THIS LINE ###################

# set strict mode -  via http://redsymbol.net/articles/unofficial-bash-strict-mode/
# removed -e because it made basic [[ testing ]] difficult
set -uo pipefail
IFS=$'\n\t'
# shellcheck disable=SC2120
hash(){
  length=${1:-6}
  # shellcheck disable=SC2230
  if [[ -n $(which md5sum) ]] ; then
    # regular linux
    md5sum | cut -c1-"$length"
  else
    # macos
    md5 | cut -c1-"$length"
  fi
}
#TIP: use «hash» to create short unique values of fixed length based on longer inputs
#TIP:> url_contents="$domain.$(echo $url | hash 8).html"


prog_modified="??"
os_name=$(uname -s)
[[ "$os_name" = "Linux" ]]  && prog_modified=$(stat -c %y    "${BASH_SOURCE[0]}" 2>/dev/null | cut -c1-16) # generic linux
[[ "$os_name" = "Darwin" ]] && prog_modified=$(stat -f "%Sm" "${BASH_SOURCE[0]}" 2>/dev/null) # for MacOS

force=0
help=0

## ----------- TERMINAL OUTPUT STUFF

[[ -t 1 ]] && piped=0 || piped=1        # detect if out put is piped
verbose=0
#to enable verbose even before option parsing
[[ $# -gt 0 ]] && [[ $1 == "-v" ]] && verbose=1
quiet=0
#to enable quiet even before option parsing
[[ $# -gt 0 ]] && [[ $1 == "-q" ]] && quiet=1

[[ $(echo -e '\xe2\x82\xac') == '€' ]] && unicode=1 || unicode=0 # detect if unicode is supported


if [[ $piped -eq 0 ]] ; then
  col_reset="\033[0m" ; col_red="\033[1;31m" ; col_grn="\033[1;32m" ; col_ylw="\033[1;33m"
else
  col_reset="" ; col_red="" ; col_grn="" ; col_ylw=""
fi

if [[ $unicode -gt 0 ]] ; then
  char_succ="✔" ; char_fail="✖" ; char_alrt="➨" ; char_wait="…"
else
  char_succ="OK " ; char_fail="!! " ; char_alrt="?? " ; char_wait="..."
fi

readonly nbcols=$(tput cols || echo 80)
#readonly nbrows=$(tput lines)
readonly wprogress=$((nbcols - 5))

out() { ((quiet)) || printf '%b\n' "$*";  }
#TIP: use «out» to show any kind of output, except when option --quiet is specified
#TIP:> out "User is [$USER]"

progress() {
  ((quiet)) || (
    if is_set ${piped:-0} ; then
      out "$*"
    else
      printf "... %-${wprogress}b\r" "$*                                             ";
    fi
  )
}
#TIP: use «progress» to show one line of progress that will be overwritten by the next output
#TIP:> progress "Now generating file $nb of $total ..."

die()     { tput bel; out "${col_red}${char_fail} $script_basename${col_reset}: $*" >&2; safe_exit; }
fail()    { tput bel; out "${col_red}${char_fail} $script_basename${col_reset}: $*" >&2; safe_exit; }
#TIP: use «die» to show error message and exit program
#TIP:> if [[ ! -f $output ]] ; then ; die "could not create output" ; fi

alert()   { out "${col_red}${char_alrt}${col_reset}: $*" >&2 ; }                       # print error and continue
#TIP: use «alert» to show alert/warning message but continue
#TIP:> if [[ ! -f $output ]] ; then ; alert "could not create output" ; fi

success() { out "${col_grn}${char_succ}${col_reset}  $*" ; }
#TIP: use «success» to show success message but continue
#TIP:> if [[ -f $output ]] ; then ; success "output was created!" ; fi

announce(){ out "${col_grn}${char_wait}${col_reset}  $*"; sleep 1 ; }
#TIP: use «announce» to show the start of a task
#TIP:> announce "now generating the reports"

log()   { ((verbose)) && out "${col_ylw}# $* ${col_reset}" >&2 ; }
#TIP: use «log» to show information that will only be visible when -v is specified
#TIP:> log "input file: [$inputname] - [$inputsize] MB"

lower_case()   { echo "$*" | awk '{print tolower($0)}' ; }
upper_case()   { echo "$*" | awk '{print toupper($0)}' ; }
#TIP: use «lower_case» and «upper_case» to convert to upper/lower case
#TIP:> param=$(lower_case $param)

confirm() { is_set $force && return 0; read -r -p "$1 [y/N] " -n 1; echo " "; [[ $REPLY =~ ^[Yy]$ ]];}
#TIP: use «confirm» for interactive confirmation before doing something
#TIP:> if ! confirm "Delete file"; then ; echo "skip deletion" ;   fi

ask() {
  # $1 = variable name
  # $2 = question
  # $3 = default value
  # not using read -i because that doesn't work on MacOS
  local ANSWER
  read -r -p "$2 ($3) > " ANSWER
  if [[ -z "$ANSWER" ]] ; then
    eval "$1=\"$3\""
  else
    eval "$1=\"$ANSWER\""
  fi
}
#TIP: use «ask» for interactive setting of variables
#TIP:> ask NAME "What is your name" "Peter"

error_prefix="${col_red}>${col_reset}"
trap "die \"ERROR \$? after \$SECONDS seconds \n\
\${error_prefix} last command : '\$BASH_COMMAND' \" \
\$(< \$script_install_path awk -v lineno=\$LINENO \
'NR == lineno {print \"\${error_prefix} from line \" lineno \" : \" \$0}')" INT TERM EXIT
# cf https://askubuntu.com/questions/513932/what-is-the-bash-command-variable-good-for
# trap 'echo ‘$BASH_COMMAND’ failed with error code $?' ERR
safe_exit() {
  [[ -n "${tmp_file:-}" ]] && [[ -f "$tmp_file" ]] && rm "$tmp_file"
  trap - INT TERM EXIT
  log "$script_basename finished after $SECONDS seconds"
  exit 0
}

is_set()       { [[ "$1" -gt 0 ]]; }
is_empty()     { [[ -z "$1" ]] ; }
is_not_empty() { [[ -n "$1" ]] ; }
#TIP: use «is_empty» and «is_not_empty» to test for variables
#TIP:> if is_empty "$email" ; then ; echo "Need Email!" ; fi

is_file() { [[ -f "$1" ]] ; }
is_dir()  { [[ -d "$1" ]] ; }
#TIP: use «is_file» and «is_dir» to test for files or folders
#TIP:> if is_file "/etc/hosts" ; then ; cat "/etc/hosts" ; fi

show_usage() {
  out "Program: ${col_grn}$script_basename $script_version${col_reset} by ${col_ylw}$script_author${col_reset}"
  out "Updated: ${col_grn}$prog_modified${col_reset}"

  echo -n "Usage: $script_basename"
   list_options \
  | awk '
  BEGIN { FS="|"; OFS=" "; oneline="" ; fulltext="Flags, options and parameters:"}
  $1 ~ /flag/  {
    fulltext = fulltext sprintf("\n    -%1s|--%-10s: [flag] %s [default: off]",$2,$3,$4) ;
    oneline  = oneline " [-" $2 "]"
    }
  $1 ~ /option/  {
    fulltext = fulltext sprintf("\n    -%1s|--%s <%s>: [optn] %s",$2,$3,"val",$4) ;
    if($5!=""){fulltext = fulltext "  [default: " $5 "]"; }
    oneline  = oneline " [-" $2 " <" $3 ">]"
    }
  $1 ~ /secret/  {
    fulltext = fulltext sprintf("\n    -%1s|--%s <%s>: [secr] %s",$2,$3,"val",$4) ;
      oneline  = oneline " [-" $2 " <" $3 ">]"
    }
  $1 ~ /param/ {
    if($2 == "1"){
          fulltext = fulltext sprintf("\n    %-10s: [parameter] %s","<"$3">",$4);
          oneline  = oneline " <" $3 ">"
     } else {
          fulltext = fulltext sprintf("\n    %-10s: [parameters] %s (1 or more)","<"$3">",$4);
          oneline  = oneline " <" $3 " …>"
     }
    }
    END {print oneline; print fulltext}
  '
}

show_tips(){
  < "${BASH_SOURCE[0]}" grep -v "\$0" \
  | awk "
  /TIP: / {\$1=\"\"; gsub(/«/,\"$col_grn\"); gsub(/»/,\"$col_reset\"); print \"*\" \$0}
  /TIP:> / {\$1=\"\"; print \" $col_ylw\" \$0 \"$col_reset\"}
  "
}

init_options() {
	local init_command
    init_command=$(list_options \
    | awk '
    BEGIN { FS="|"; OFS=" ";}
    $1 ~ /flag/   && $5 == "" {print $3 "=0; "}
    $1 ~ /flag/   && $5 != "" {print $3 "=\"" $5 "\"; "}
    $1 ~ /option/ && $5 == "" {print $3 "=\"\"; "}
    $1 ~ /option/ && $5 != "" {print $3 "=\"" $5 "\"; "}
    ')
    if [[ -n "$init_command" ]] ; then
        #log "init_options: $(echo "$init_command" | wc -l) options/flags initialised"
        eval "$init_command"
   fi
}

require_binaries(){
  os_name=$(uname -s)
  os_version=$(uname -sprm)
  log "Running: on $os_name ($os_version)"
  list_programs=$(echo "$*" | sort -u |  tr "\n" " ")
  log "Verify : $list_programs"
  for prog in "$@" ; do
    # shellcheck disable=SC2230
    if [[ -z $(which "$prog") ]] ; then
      die "$script_basename needs [$prog] but this program cannot be found on this [$os_name] machine"
    fi
  done
}

folder_prep(){
  if [[ -n "$1" ]] ; then
      local folder="$1"
      local max_days=${2:-365}
      if [[ ! -d "$folder" ]] ; then
          log "Create folder : [$folder]"
          mkdir "$folder"
      else
          log "Cleanup folder: [$folder] - delete files older than $max_days day(s)"
          find "$folder" -mtime "+$max_days" -type f -exec rm {} \;
      fi
  fi
}
#TIP: use «folder_prep» to create a folder if needed and otherwise clean up old files
#TIP:> folder_prep "$log_dir" 7 # delete all files olders than 7 days

expects_single_params(){
  list_options | grep 'param|1|' > /dev/null
  }
expects_optional_params(){
  list_options | grep 'param|?|' > /dev/null
  }
expects_multi_param(){
  list_options | grep 'param|n|' > /dev/null
  }

count_words(){
  wc -w \
  | awk '{ gsub(/ /,""); print}'
}

parse_options() {
    if [[ $# -eq 0 ]] ; then
       show_usage >&2 ; safe_exit
    fi

    ## first process all the -x --xxxx flags and options
    while true; do
      # flag <flag> is saved as $flag = 0/1
      # option <option> is saved as $option
      if [[ $# -eq 0 ]] ; then
        ## all parameters processed
        break
      fi
      if [[ ! $1 = -?* ]] ; then
        ## all flags/options processed
        break
      fi
	  local save_option
      save_option=$(list_options \
        | awk -v opt="$1" '
        BEGIN { FS="|"; OFS=" ";}
        $1 ~ /flag/   &&  "-"$2 == opt {print $3"=1"}
        $1 ~ /flag/   && "--"$3 == opt {print $3"=1"}
        $1 ~ /option/ &&  "-"$2 == opt {print $3"=$2; shift"}
        $1 ~ /option/ && "--"$3 == opt {print $3"=$2; shift"}
        $1 ~ /secret/ &&  "-"$2 == opt {print $3"=$2; shift"}
        $1 ~ /secret/ && "--"$3 == opt {print $3"=$2; shift"}
        ')
        if [[ -n "$save_option" ]] ; then
          if echo "$save_option" | grep shift >> /dev/null ; then
            local save_var
            save_var=$(echo "$save_option" | cut -d= -f1)
            log "Found  : ${save_var}=$2"
          else
            log "Found  : $save_option"
          fi
          eval "$save_option"
        else
            die "cannot interpret option [$1]"
        fi
        shift
    done

    ((help)) && (
      echo "### USAGE"
      show_usage
      echo ""
      echo "### SCRIPT AUTHORING TIPS"
      show_tips
      safe_exit
    )

    ## then run through the given parameters
  if expects_single_params ; then
    single_params=$(list_options | grep 'param|1|' | cut -d'|' -f3)
    list_singles=$(echo "$single_params" | xargs)
    single_count=$(echo "$single_params" | count_words)
    log "Expect : $single_count single parameter(s): $list_singles"
    [[ $# -eq 0 ]] && die "need the parameter(s) [$list_singles]"

    for param in $single_params ; do
      [[ $# -eq 0 ]] && die "need parameter [$param]"
      [[ -z "$1" ]]  && die "need parameter [$param]"
      log "Assign : $param=$1"
      eval "$param=\"$1\""
      shift
    done
  else
    log "No single params to process"
    single_params=""
    single_count=0
  fi

  if expects_optional_params ; then
    optional_params=$(list_options | grep 'param|?|' | cut -d'|' -f3)
    optional_count=$(echo "$optional_params" | count_words)
    log "Expect : $optional_count optional parameter(s): $(echo "$optional_params" | xargs)"

    for param in $optional_params ; do
      log "Assign : $param=${1:-}"
      eval "$param=\"${1:-}\""
      shift
    done
  else
    log "No optional params to process"
    optional_params=""
    optional_count=0
  fi

  if expects_multi_param ; then
    #log "Process: multi param"
    multi_count=$(list_options | grep -c 'param|n|')
    multi_param=$(list_options | grep 'param|n|' | cut -d'|' -f3)
    log "Expect : $multi_count multi parameter: $multi_param"
    (( multi_count > 1 )) && die "cannot have >1 'multi' parameter: [$multi_param]"
    (( multi_count > 0 )) && [[ $# -eq 0 ]] && die "need the (multi) parameter [$multi_param]"
    # save the rest of the params in the multi param
    if [[ -n "$*" ]] ; then
      log "Assign : $multi_param=$*"
      eval "$multi_param=( $* )"
    fi
  else
    multi_count=0
    multi_param=""
    [[ $# -gt 0 ]] && die "cannot interpret extra parameters"
  fi
}

lookup_script_data(){
  readonly script_prefix=$(basename "${BASH_SOURCE[0]}" .sh)
  readonly script_basename=$(basename "${BASH_SOURCE[0]}")
  readonly execution_day=$(date "+%Y-%m-%d")
  readonly execution_year=$(date "+%Y")

   if [[ -z $(dirname "${BASH_SOURCE[0]}") ]]; then
    # script called without path ; must be in $PATH somewhere
    # shellcheck disable=SC2230
    script_install_path=$(which "${BASH_SOURCE[0]}")
    if [[ -n $(readlink "$script_install_path") ]] ; then
      # when script was installed with e.g. basher
      script_install_path=$(readlink "$script_install_path")
    fi
    script_install_folder=$(dirname "$script_install_path")
  else
    # script called with relative/absolute path
    script_install_folder=$(dirname "${BASH_SOURCE[0]}")
    # resolve to absolute path
    script_install_folder=$(cd "$script_install_folder" && pwd)
    if [[ -n "$script_install_folder" ]] ; then
      script_install_path="$script_install_folder/$script_basename"
    else
      script_install_path="${BASH_SOURCE[0]}"
      script_install_folder=$(dirname "${BASH_SOURCE[0]}")
    fi
    if [[ -n $(readlink "$script_install_path") ]] ; then
      # when script was installed with e.g. basher
      script_install_path=$(readlink "$script_install_path")
      script_install_folder=$(dirname "$script_install_path")
    fi
  fi
  log "Executable: [$script_install_path]"
  log "In folder : [$script_install_folder]"

  [[ -f "$script_install_folder/VERSION.md" ]] && script_version=$(cat "$script_install_folder/VERSION.md")
  if git status >/dev/null; then
    readonly in_git_repo=1
  else
    readonly in_git_repo=0
  fi
}

prep_log_and_temp_dir(){
  tmp_file=""
  log_file=""
  # shellcheck disable=SC2154
  if is_not_empty "$tmp_dir" ; then
    folder_prep "$tmp_dir" 1
    tmp_file=$(mktemp "$tmp_dir/$execution_day.XXXXXX")
    log "tmp_file: $tmp_file"
    # you can use this teporary file in your program
    # it will be deleted automatically if the program ends without problems
  fi
  # shellcheck disable=SC2154
  if [[ -n "$log_dir" ]] ; then
    folder_prep "$log_dir" 7
    log_file=$log_dir/$script_prefix.$execution_day.log
    log "log_file: $log_file"
    echo "$(date '+%H:%M:%S') | [$script_basename] $script_version started" >> "$log_file"
  fi
}

import_env_if_any(){
  #TIP: use «.env» file in script folder / current folder to set secrets or common config settings
  #TIP:> AWS_SECRET_ACCESS_KEY="..."

  if [[ -f "$script_install_folder/.env" ]] ; then
    log "Read config from [$script_install_folder/.env]"
    # shellcheck disable=SC1090
    source "$script_install_folder/.env"
  fi
  if [[ -f "./.env" ]] ; then
    log "Read config from [./.env]"
    # shellcheck disable=SC1090
    source "./.env"
  fi
}

[[ $run_as_root == 1  ]] && [[ $UID -ne 0 ]] && die "user is $USER, MUST be root to run [$script_basename]"
[[ $run_as_root == -1 ]] && [[ $UID -eq 0 ]] && die "user is $USER, CANNOT be root to run [$script_basename]"

lookup_script_data

# set default values for flags & options
init_options

# overwrite with .env if any
import_env_if_any

# overwrite with specified options if any
parse_options "$@"

# clean up log and temp folder
prep_log_and_temp_dir

# run main program
main

# exit and clean up
safe_exit

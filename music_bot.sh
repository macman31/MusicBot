#!/bin/bash

# Music bot by GoFish for net7 ><>°

###########################
###### CONFIGURATION ######
###########################

BOT_DEBUG=1  # Enable debug messages?
BOT_LISTEN_PORT=2222  # Port on which the music bot is listening
BOT_MUSIC_DIRECTORY="/root/bot_musique/music_files/"  # Must be a full path!
BOT_PULSE_SERVER="mirage"  # IP address of the PulseAudio server we want to stream the music to
BOT_IP_ACCESSLIST_REGEX="127\.0\.0\.1|192\.168\."  # Client IPs will be matched to this regex to authorize access
BOT_TEMP_FILES_LOCATION="/tmp/"  # Must be a temp folder, cleared after a system reboot!
BOT_PLAYER="cvlc"  # Music player used by the bot
BOT_PLAYER_OPTIONS="--no-loop --no-repeat --play-and-exit"  # Options to give to the bot player process

###############################
###### GENERIC FUNCTIONS ######
###############################

function echo_debug { # I/ $*: debug message to print if debug enabled
    if [ "$BOT_DEBUG" -eq "1" ] ; then
        echo "[#] $*"
    fi
}

function echo_info { # I/ $*: info message to print
    echo "[ ] $*"
}

function echo_warning { # I/ $*: warning message to print
    echo "[!] $*"
}

function echo_error { # I/ $*: error message to print
    echo "[X] $*"
}

function echo_input { # I/ $*: prompt to print before asking for an user input
    echo -n "[>] $*"
}

function is_installed { # I/ $1: program name
  command -v "$1" &>/dev/null || { echo_error "$1 is needed for this program to work!" ; exit 1 ; }
}

###########################
###### BOT FUNCTIONS ######
###########################

function bot_help {
  echo_info "Valid commands:"
  echo_info " +                     : Increase the music volume by 2%"
  echo_info " -                     : Decrease the music volume by 2%"
  echo_info " c|current             : Show the ID/name of the current song, if it is a playlist song and not an user-played temporary music"
  echo_info " a|add <YouTube URL>   : Download/add a YouTube video audio track to the music playlist"
  echo_info " p|play <YouTube URL>  : Queue the YouTube video audio track to be played after the current song, without adding it to the playlist"
  echo_info " n|next                : Play a new music"
  echo_info " s|start               : Start the music"
  echo_info " k|stop                : Stop the music"
  echo_info " ls                    : List all music in the music playlist, with their corresponding ID"
  echo_info " rm <Music ID>         : Remove the specified music from the the music playlist"
  echo_info " q|exit                : Close this command line"
}

function check_if_youtube_url { # I/ $1: YouTube video URL
  if ! [[ "$1" =~ "www.youtube.com/watch" ]] ; then
    echo_error "The URL \"$1\" is not a valid YouTube video URL, aborting download!"
    return 1
  else
    return 0
  fi
}

function check_if_bot_started {
  if [ -f "$BOT_TEMP_FILES_LOCATION/music_bot_mplayer_pid" ] ; then
    return 0
  else
    return 1
  fi
}

function bot_add { # $1: YouTube video URL
  if check_if_youtube_url "$1" ; then
    echo_info "Downloading $1 in background"
    ( youtube-dl --ignore-config --quiet --no-call-home --no-color --no-playlist -o "%(id)s____%(title)s.%(ext)s" --restrict-filenames -f bestaudio "$1" 2>&1 || echo_error "Download of $1 failed!") &
  fi
}

function bot_play { # $1: YouTube video URL
  if check_if_youtube_url "$1" ; then
    echo_info "Downloading $1 and setting it to play next, do not close your terminal"
    random_name="music_bot_music_$RANDOM$RANDOM"
    youtube-dl --ignore-config --quiet --no-call-home --no-color --no-playlist -o "$BOT_TEMP_FILES_LOCATION/$random_name" --restrict-filenames -f bestaudio "$1" 2>&1 && ( echo "$BOT_TEMP_FILES_LOCATION/$random_name" > "$BOT_TEMP_FILES_LOCATION/music_bot_next_fifo" ; echo_info "Download of $1 finished") || echo_error "Download of $1 failed!"
  fi
}

function bot_next {
  if ! check_if_bot_started ; then
    echo_warning "Music bot is not started!"
  else
    mplayer_pid=`cat "$BOT_TEMP_FILES_LOCATION/music_bot_mplayer_pid"`
    kill -9 $mplayer_pid &>/dev/null
  fi
}

function bot_start {
  if check_if_bot_started ; then
    echo_warning "Music bot already started!"
  else
    echo_info "Starting the music bot!"
    # The following code is executed as a new thread to not hang the control interface
    ( touch "$BOT_TEMP_FILES_LOCATION/music_bot_mplayer_pid" # The file must be present for the bot to start, if it is not then the bot will assume that the music has to be stopped
      while check_if_bot_started ; do
        read -t0.1 music_to_play < "$BOT_TEMP_FILES_LOCATION/music_bot_next_fifo" # Try to grab a song to play next from the fifo, it is blocking if the fifo is empty so we have to set a timeout of 0.1sec
        [[ "$music_to_play" == "" ]] && music_to_play="`ls | grep -vE "part$" | shuf | head -n1`" # If no music is scheduled to be played next, play a random song from the current playlist (a random song not ending by .part)
        PULSE_SERVER="$BOT_PULSE_SERVER" "$BOT_PLAYER" $BOT_PLAYER_OPTIONS "$music_to_play" & # Launch mplayer in background so we can get its PID and write it to a file next
        mplayer_pid=$!
        echo "$mplayer_pid" > "$BOT_TEMP_FILES_LOCATION/music_bot_mplayer_pid" # Store the PID so we can kill the process if we need to stop the music
        wait $mplayer_pid # Wait for the mplayer process to exit before continuing
      done
    ) &>/dev/null &
  fi
}

function bot_stop {
  if ! check_if_bot_started ; then
    echo_warning "Music bot is not started!"
  else
    mplayer_pid=`cat "$BOT_TEMP_FILES_LOCATION/music_bot_mplayer_pid"`
    rm "$BOT_TEMP_FILES_LOCATION/music_bot_mplayer_pid" &>/dev/null # Remove before kill to avoid an (improbable) race condition where the play loop could start again before the file is removed to indicate that it should stop
    kill -9 $mplayer_pid &>/dev/null
  fi
}

function bot_ls {
  ls | grep -vE "part$" | sed 's/____/ : /g' # ____ delimitate the YouTube ID and the song name, and songs being downloaded ends in ".part" and we have to exclude them
}

function bot_rm { # $1: Music ID from the ls command (= YouTube video ID)
  music_name="`ls | grep -vE "part$" | grep -F "${1}____"`" # grep -F to avoid a user input being interpreted as a regex and potentially removing other files
  echo_debug "Music found with this ID: $music_name"
  if [ "$music_name" != "" ] ; then
    rm "$music_name"
    echo_info "Video removed!"
  else
    echo_warning "No video found with ID $1!"
  fi
}

function bot_increase_volume {
  if ! check_if_bot_started ; then
    echo_warning "Music bot is not started!"
  else
    # We need to get the sink number given by PulseAudio to our process, so we list all the sink numbers and extract the one matching the PID of mplayer
    sink_number=$(PULSE_SERVER="$BOT_PULSE_SERVER" pactl list sink-inputs | grep -B25 "application.process.id = \"`cat "$BOT_TEMP_FILES_LOCATION/music_bot_mplayer_pid"`\"" | grep "Sink Input" | cut -d"#" -f2)
    # And then we increase its volume by 2%!
    PULSE_SERVER="$BOT_PULSE_SERVER" pactl -- set-sink-input-volume $sink_number "+2%"
  fi
}

function bot_decrease_volume {
  if ! check_if_bot_started ; then
    echo_warning "Music bot is not started!"
  else
    # We need to get the sink number given by PulseAudio to our process, so we list all the sink numbers and extract the one matching the PID of mplayer
    sink_number=$(PULSE_SERVER="$BOT_PULSE_SERVER" pactl list sink-inputs | grep -B25 "application.process.id = \"`cat "$BOT_TEMP_FILES_LOCATION/music_bot_mplayer_pid"`\"" | grep "Sink Input" | cut -d"#" -f2)
    # And then we decrease its volume by 2%!
    PULSE_SERVER="$BOT_PULSE_SERVER" pactl -- set-sink-input-volume $sink_number "-2%"
  fi
}

function bot_list_current {
  if ! check_if_bot_started ; then
    echo_warning "Music bot is not started!"
  else
    # The song file is the last argument of the music player command we executed to start the music, extract it from /proc/PID/cmdline
    current_song=$(cat /proc/`cat "$BOT_TEMP_FILES_LOCATION/music_bot_mplayer_pid"`/cmdline | sed 's/\x00/ /g' | awk -F' ' '{print $NF}' | sed 's/____/ /g')
    if [[ "$current_song" =~ "$BOT_TEMP_FILES_LOCATION" ]] ; then # The song is not from the playlist, it is from the play command, so the name is random
      echo_info "Currently playing: temporary music"
    else
      echo_info "Currently playing: $current_song"
    fi
  fi
}

function handle_user_input { # I/ $1: command, $2: arg
    case "$1" in
      "")
      ;;
      +)
        bot_increase_volume
      ;;
      -)
        bot_decrease_volume
      ;;
      current|c)
        bot_list_current
      ;;
      add|a)
        bot_add "$2"
      ;;
      play|p)
        bot_play "$2"
      ;;
      next|n)
        bot_next
      ;;
      start|s)
        bot_start
      ;;
      stop|k)
        bot_stop
      ;;
      ls)
        bot_ls
      ;;
      rm)
        bot_rm "$2"
      ;;
      exit|q)
        exit 0
      ;;
      *)
        bot_help
      ;;
    esac
}

function bot_validate_access { # I/ $1: client IP address
  echo_debug "Client IP $1 matched to authorized IPs regex $BOT_IP_ACCESSLIST_REGEX"
  # If the client IP is matched by the regex, then a non-empty result (the matched part) will be returned, else the result will be empty
  if [[ "`echo "$1" | grep -oE "$BOT_IP_ACCESSLIST_REGEX"`" == "" ]] ; then
    echo_error "You are not allowed to access the control interface of the music bot!"
    exit 2
  fi
}

##################
###### MAIN ######
##################

is_installed "socat"
is_installed "youtube-dl"
is_installed "$BOT_PLAYER"

# Start the server if the current script is not launched by socat
if [ "$SOCAT_PID" == "" ] ; then
  rm "$BOT_TEMP_FILES_LOCATION/music_bot_next_fifo" &>/dev/null
  mkfifo "$BOT_TEMP_FILES_LOCATION/music_bot_next_fifo"
  echo_info "Music bot listening on port $BOT_LISTEN_PORT"
  socat TCP4-LISTEN:$BOT_LISTEN_PORT,reuseaddr,fork EXEC:"$0"
fi

bot_validate_access "$SOCAT_PEERADDR"

cd "$BOT_MUSIC_DIRECTORY" 2>/dev/null || { echo_error "Directory $BOT_MUSIC_DIRECTORY does not exist on the server, configure a new directory or create it!"; exit 1; }

exec 3<>"$BOT_TEMP_FILES_LOCATION/music_bot_next_fifo" # Make the fifo non-blocking for writes by assigning to it a file descriptor

echo_info "Music bot by GoFish for net7, written in bash! ><>°"
bot_help

while true; do
    echo_input
    read bot_command || exit 0 # || To handle CTRL+D

    handle_user_input $bot_command
done

exit 0

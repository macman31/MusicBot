# MusicBot
A collaborative music bot, written in bash! (in an afternoon to win a bet!)

# Requirements
## Somewhere
* A PulseAudio server  
The bot is used to play music to a PulseAudio server with the following modules enabled in default.pa:  
  `load-module module-esound-protocol-tcp`  
  `load-module module-native-protocol-tcp`  

## On a server
* `pulseaudio` (to export the sound to the PulseAudio server, and to have access to `pactl`)
* `socat`
* [`youtube-dl`](https://rg3.github.io/youtube-dl/)
* A music player  
  `cvlc` is used here, the bot has also been tested with `mplayer` and `mpv`

## On clients
* Any way of opening a raw read/write socket to a given IP and port.  
Examples:  
`nc <IP> <PORT>` (doesn't seems to handle CTRL+D correctly)  
`socat TCP:<IP>:<PORT> -` (seems to work just fine with CTRL+D)

# How can I use this bot?

1. Download `music_bot.sh` on the server
2. Edit `music_bot.sh` and change the configuration variables at the beginning of the file
3. Create the folder specified in `BOT_MUSIC_DIRECTORY` on the server
4. `chmod +x music_bot.sh`
5. `./music_bot.sh`
6. `nc <SERVER IP> <PORT SPECIFIED IN BOT_LISTEN_PORT>` from any client
7. Enjoy!

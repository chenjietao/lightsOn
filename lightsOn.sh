#!/bin/bash
# lightsOn.sh

# Copyright (c) 2013 iye.cba at gmail com
# url: https://github.com/iye/lightsOn
# This script is licensed under GNU GPL version 2.0 or above

# Description: Bash script that prevents the screensaver and display power
# management (DPMS) to be activated when you are watching Flash Videos
# or HTML5 Videos fullscreen on web browser.
# Can detect video players (like mplayer, minitube, and VLC) when they are 
# fullscreen too.
# Also, screensaver can be prevented when certain specified programs are running.


# HOW TO USE: Start the script with the number of seconds you want the checks
# for fullscreen to be done. Example:
# "./lightsOn.sh 120 &" will Check every 120 seconds if video players or 
# web browsers are fullscreen and delay screensaver and Power Management if so.
# You want the number of seconds to be ~10 seconds less than the time it takes
# your screensaver or Power Management to activate.
# If you don't pass an argument, the checks are done every 50 seconds.
#
# An optional array variable exists here to add the names of programs that will delay the screensaver if they're running.
# This can be useful if you want to maintain a view of the program from a distance, like a music playlist for DJing,
# or if the screensaver eats up CPU that chops into any background processes you have running,
# such as realtime music programs like Ardour in MIDI keyboard mode.
# If you use this feature, make sure you use the name of the binary of the program (which may exist, for instance, in /usr/bin).


# Modify these variables if you want this script to detect if video players,
# HTML5 Video or Flash Video are Fullscreen and disable screensaver and PowerManagement.
flash_detection=1
html5_detection=1
mplayer_detection=1
vlc_detection=1
minitube_detection=1
smplayer_detection=1

# Names of programs which, when running, you wish to delay the screensaver.
delay_progs=() # For example ('ardour2' 'gmpc')


# YOU SHOULD NOT NEED TO MODIFY ANYTHING BELOW THIS LINE


# enumerate all the attached screens
displays=""
while read id
do
    displays="$displays $id"
done < <(xvinfo | sed -n 's/^screen #\([0-9]\+\)$/\1/p')


# Detect screensaver been used (xscreensaver, kscreensaver or none)
if [[ `pidof xcreensaver` ]]; then
    screensaver=xscreensaver
elif [[ `pidof gnome-screensaver` ]]; then
    screensaver=gnome-screensaver
elif [[ `pidof kscreensaver` ]]; then    # Effect on old KDE version  
    screensaver=kscreensaver
elif [[ -f $HOME/.kde*/share/config/kscreensaverrc ]] && [[ -z `grep -iw "enabled=false" $HOME/.kde*/share/config/kscreensaverrc` ]]; then    #Effect on new KDE version
    screensaver=kscreensaver
else
    screensaver=None
    echo "No screensaver detected"
fi

checkDelayProgs()
{
    for prog in "${delay_progs[@]}"; do
        if [[ `pidof "$prog"` ]]; then
            echo "Delaying the screensaver because a program on the delay list, \"$prog\", is running..."
            delayScreensaver
            break
        fi
    done
}

checkFullscreen()
{
    # loop through every display looking for a fullscreen window
    for display in $displays
    do
        #get id of active window and clean output
        activ_win_id=`DISPLAY=:0.${display} xprop -root _NET_ACTIVE_WINDOW`
        #activ_win_id=${activ_win_id#*# } #gives error if xprop returns extra ", 0x0" (happens on some distros)
        activ_win_id=${activ_win_id:40:9}

        # Skip invalid window ids (The $activ_win_id return 0x0 when screensaver actives.
        # If id invalid isActivWinFullscreen will fail anyway.)
        if [[ "$activ_win_id" = *0x0 ]]; then
             continue
        fi

        # Check if Active Window (the foremost window) is in fullscreen state
        isActivWinFullscreen=`DISPLAY=:0.${display} xprop -id $activ_win_id | grep _NET_WM_STATE_FULLSCREEN`
            if [[ "$isActivWinFullscreen" = *NET_WM_STATE_FULLSCREEN* ]];then
                isAppRunning
                var=$?
                if [[ $var -eq 1 ]];then
                    delayScreensaver
                fi
            fi
    done
}





# check if active windows is mplayer, vlc or firefox
#TODO only window name in the variable activ_win_id, not whole line.
#Then change IFs to detect more specifically the apps "<vlc>" and if process name exist

isAppRunning()
{
    #Get PID of active window
    activ_win_pid=`xprop -id $activ_win_id | grep "_NET_WM_PID(CARDINAL)"`   
    activ_win_pid=${activ_win_pid##* }


    # Check if user want to detect Flash Video fullscreen on web browser, modify variable flash_detection if you dont want Flash Video detection
    if [ $flash_detection == 1 ]; then
        if [[ "`lsof -p $activ_win_pid | grep flashplayer.so`" ]]; then    # detect if the process loads libflashplayer.so or libpepflashplayer.so
            return 1
        fi
    fi

    # Check if user want to detect HTML5 Video fullscreen on web browsers, modify variable html5_detection if you dont want HTML5 Video detection
    if [ $html5_detection == 1 ];then
        for browser in google-chrome chromium firefox midori opera konqueror epiphany iceweasel ; do
        if [[ `ps p $activ_win_pid o comm=` = "$browser" ]];then
            return 1
        fi
        done
    fi


    #check if user want to detect mplayer fullscreen, modify variable mplayer_detection
    if [ $mplayer_detection == 1 ];then
        if [[ `ps p $activ_win_pid o comm=` = "mplayer" ]];then
            return 1
        fi
    fi

    # Check if user want to detect vlc fullscreen, modify variable vlc_detection
    if [ $vlc_detection == 1 ];then
        if [[ `ps p $activ_win_pid o comm=` = "vlc" ]];then
            return 1
        fi
    fi

    # Check if user want to detect minitube fullscreen, modify variable minitube_detection
    if [ $minitube_detection == 1 ];then
        if [[ `ps p $activ_win_pid o comm=` = "minitube" ]];then
            return 1
        fi
    fi

    #check if user want to detect smplayer fullscreen, modify variable smplayer_detection
    if [ $smplayer_detection == 1 ];then
        if [[ `ps p $activ_win_pid o comm=` = "smplayer" ]];then
            return 1
        fi
    fi

    return 0
}


delayScreensaver()
{

    # reset inactivity time counter so screensaver is not started
    if [ "$screensaver" == "xscreensaver" ]; then
        xscreensaver-command -deactivate > /dev/null
    elif [ "$screensaver" == "gnome-screensaver" ]; then
        dbus-send --session --type=method_call --dest=org.gnome.ScreenSaver --reply-timeout=20000 /org/gnome/ScreenSaver org.gnome.ScreenSaver.SimulateUserActivity > /dev/null
    elif [ "$screensaver" == "kscreensaver" ]; then
        qdbus org.freedesktop.ScreenSaver /ScreenSaver SimulateUserActivity > /dev/null
    fi


    #Check if DPMS is on. If it is, deactivate and reactivate again. If it is not, do nothing.
    dpmsStatus=`xset -q | grep -ce 'DPMS is Enabled'`
    if [ $dpmsStatus == 1 ];then
            xset -dpms
            xset dpms
    fi

}



delay=$1


# If argument empty, use 50 seconds as default.
if [ -z "$1" ];then
    delay=50
fi


# If argument is not integer quit.
if [[ $1 = *[^0-9]* ]]; then
    echo "The Argument \"$1\" is not valid, not an integer"
    echo "Please use the time in seconds you want the checks to repeat."
    echo "You want it to be ~10 seconds less than the time it takes your screensaver or DPMS to activate"
    exit 1
fi


while true
do
    checkDelayProgs
    checkFullscreen
    sleep $delay
done


exit 0

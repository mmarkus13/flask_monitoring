echo -e '\e[1A\e[K .....Checking services'
sleep 1
echo -ne '#####          (33%)\r'
sleep 1

echo -e '\e[1A\e[K ....Smashing Mushrooms'
echo -ne '##########     (66%)\r'
sleep 1

echo -e '\e[1A\e[K ..........Writing Logs'
echo -ne '###############(100%)\r'
echo -ne '\n'

echo -e '\e[1A\e[K '
echo -e '\e[2A\e[K ...Completed!'
echo

###############################


#!/bin/bash
sleep 5 &
pid=$!
frames="/ | \\ -"
while kill -0 $pid 2&>1 > /dev/null;
do
    for frame in $frames;
    do
        printf "\r$frame Loading..." 
        sleep 0.5
    done
done
printf "\n"


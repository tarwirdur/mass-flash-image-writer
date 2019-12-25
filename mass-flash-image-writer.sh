#!/bin/bash
portCount=0
ports="$(mktemp)"
log="$(mktemp)"
statuses="$(mktemp)"
countfile="$(mktemp)"
image="/root/image2.img"

trap "kill -TERM -$$" TERM

echo "ports: $ports, log: $log, statuses: $statuses, countfile: $countfile"

function register_port() {
  action=$1
  device=$2
  if [ "$action" = "CREATE" ] ; then
    path="$(find /sys/devices -name $device | sed 's|/host.*$||')"
    export portCount=$[$portCount+1]
    echo "$portCount:$path" >> $ports
    echo "port #$portCount registered: $path ($device)"
  fi;
}

function fill_port_list() {
  echo -e "\n\nSequentially insert flash drives into all ports in order, than press enter\n\n"
  inotifywait -e create,delete -m /dev 2> /dev/null | stdbuf -oL egrep -o "(CREATE|DELETE)\s*sd[^0-9]*$" | (while read -r EVENT ; do
    register_port $EVENT
  done) &
  PID=$!
  read t
  kill $PID
}

function print_current_status() {
  clear
  echo -e "\n\n\n"
  portCount=$(cat $ports | wc -l)
  for i in $(seq 1 $portCount); do
    echo -en "\t#$i: "
    portAddr="$(cat "$ports" | egrep "^$i:" | sed -r 's/^[0-9]*://')"
    pstatus='\e[39munplugged\e[39m'
    status='\e[39m       '
    if [ -d "$portAddr" ]; then
      device="$(basename "$(find $portAddr -name "sd*"| grep -E "block/sd[a-z]+$")")"
    pstatus='\e[32mplugged\e[39m'
    rawstatus="$(cat $statuses | grep $portAddr | grep -Eo "^[^:]*")"
    case "$rawstatus" in
      "writing")
        status='\e[41mWRITING\e[49m'
      ;;
      "ready")
        status='\e[42mREADY\e[49m  '
      ;;
      "failed")
        status='\e[101mFAILED\e[49m '
      ;;
    esac
    status="/dev/$device\t$status"
    fi
    
    echo -e "$pstatus\t$status"
    echo -e "\e[49m\e[39m"
  done;
  echo -en "totalCount: "
  cat "$countfile"
}

function flash_drive() {
  device="$1"
  echo "change flash_drive function"
  exit 1
  # example:
  # partclone.vfat -s "$image" -o /dev/${device} -r -q -L /tmp/flashCloner-$device.log &> /dev/null
  return $?
}

function on_ready_handler() {
  screen -S f -d -m mpg123 /root/bell.mp3
}

function device_handler() {
  action=$1
  device=$2
  path="$(find /sys/devices -name $device | sed 's|/host.*$||')"
  [ "$device" = "sda" ] && exit
  case $action in
    "CREATE")
      (sleep 5; 
        echo "WRITING $device" >> $log ;
        flash_drive "$device" && \
        echo "READY $device" >> $log || \
        echo "FAILED $device" >> $log ) &
    ;;
    "WRITING")
      sed -i "/:$device/d" $statuses
      echo "writing:$device:$path" >> $statuses
    ;;
    "READY")
      sed -i "/:$device/d" $statuses
      echo "ready:$device:$path" >> $statuses
      on_ready_handler
      cnt=$(cat "$countfile")
      cnt=$[ cnt + 1 ]
      echo $cnt > "$countfile"
    ;;
    "DELETE")
      sed -i "/:$device/d" $statuses
    ;;
    "FAILED")
      sed -i "/:$device/d" $statuses
      echo "failed:$device:$path" >> $statuses
    ;;

  esac
  print_current_status
}

fill_port_list
print_current_status
((tail -f $log & ); (inotifywait -e create,delete -m /dev 2> /dev/null | stdbuf -oL egrep -o "(CREATE|DELETE)\s*sd[^0-9]*$")) | (while read -r EVENT ; do
  device_handler $EVENT
done)

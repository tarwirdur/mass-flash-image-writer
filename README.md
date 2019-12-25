### Warning: source code is bad!

A script written to solve an applied problem: write the same image to a hundred of the same flash drives.

#### how to use

1. create an image of your drive. I use partclone: `partclone.vfat -s /dev/sdb -o /root/image2.img -c`
2. modify script's function `flash_drive` (it contains example for partclone)
3. run `./mass-flash-image-writer.sh`
4. sequentially insert one drive into all ports that will be used for recording in the order of their number
5. press `Enter`
6. insert flash drives into ports
7. if you see READY status for some device - you may unplug it (based on port number) and insert new device. It will be start flashing automaticly

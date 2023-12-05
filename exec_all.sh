#! /bin/bash

mkdir -p output/exp

for i in `seq 1 22`; do
    echo Exec Q$i
    sync
    echo 3 | sudo tee /proc/sys/vm/drop_caches &> /dev/null
    sudo hdparm -f /dev/sdb &> /dev/null
    make exp Q=$i SF=10 > output/exp/$i.json
done

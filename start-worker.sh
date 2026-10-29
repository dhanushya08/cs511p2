#!/bin/bash

####################################################################################
# DO NOT MODIFY THE BELOW ##########################################################

/etc/init.d/ssh start
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/shared_rsa

# Apply the supplied timing before the student service-start commands below.
# No Hadoop installation is expected in the unfinished Part 0 starter.
if command -v hdfs >/dev/null 2>&1; then
    python3 /configure-heartbeats.py || exit 1
fi

# DO NOT MODIFY THE ABOVE ##########################################################
####################################################################################

# Start HDFS/Spark worker here

until (echo > /dev/tcp/main/9000) 2>/dev/null; do sleep 1; done
until (echo > /dev/tcp/main/7077) 2>/dev/null; do sleep 1; done
hdfs --daemon start datanode
start-worker.sh spark://main:7077

bash

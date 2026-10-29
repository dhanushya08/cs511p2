#!/bin/bash

####################################################################################
# DO NOT MODIFY THE BELOW ##########################################################

# Exchange SSH keys.
/etc/init.d/ssh start
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/shared_rsa
for node in worker1 worker2; do
    ready=false
    for attempt in {1..60}; do
        if ssh-copy-id -i ~/.ssh/id_rsa.pub -o 'IdentityFile ~/.ssh/shared_rsa' \
                -o StrictHostKeyChecking=no -o ConnectTimeout=2 -f "$node"; then
            ready=true
            break
        fi
        sleep 1
    done
    if [ "$ready" = false ]; then
        echo "Could not exchange SSH keys with $node" >&2
        exit 1
    fi
done

# Apply the supplied timing before the student service-start commands below.
# No Hadoop installation is expected in the unfinished Part 0 starter.
if command -v hdfs >/dev/null 2>&1; then
    python3 /configure-heartbeats.py || exit 1
fi

# DO NOT MODIFY THE ABOVE ##########################################################
####################################################################################

# Start HDFS/Spark main here

# HDFS: NameNode + DataNode on main.
if [ ! -d /hadoop-data/name/current ]; then
    hdfs namenode -format -force -nonInteractive
fi
hdfs --daemon start namenode
hdfs --daemon start datanode
until hdfs dfs -ls / >/dev/null 2>&1; do sleep 1; done
hdfs dfsadmin -safemode wait
hdfs dfs -mkdir -p /spark/checkpoints

# Spark: master + a worker on main.
start-master.sh
start-worker.sh spark://main:7077

bash

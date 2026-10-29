####################################################################################
# DO NOT MODIFY THE BELOW ##########################################################

FROM eclipse-temurin:8-jdk-jammy

RUN apt update && \
    apt upgrade --yes && \
    apt install ssh openssh-server python3 --yes

COPY resources/configure-heartbeats.py /configure-heartbeats.py

# Setup common SSH key.
RUN ssh-keygen -t rsa -P '' -f ~/.ssh/shared_rsa -C common && \
    cat ~/.ssh/shared_rsa.pub >> ~/.ssh/authorized_keys && \
    chmod 0600 ~/.ssh/authorized_keys

# DO NOT MODIFY THE ABOVE ##########################################################
####################################################################################

# Setup HDFS/Spark resources here
# (the PySpark skeletons of Parts 1-4 also need python3 on every node; Spark 3.4.1
#  supports Python 3.7-3.11, so do not install a newer interpreter)

RUN apt install -y curl procps net-tools && \
    curl -fsSL https://archive.apache.org/dist/hadoop/common/hadoop-3.3.6/hadoop-3.3.6.tar.gz | tar -xz -C /opt && \
    mv /opt/hadoop-3.3.6 /opt/hadoop && \
    curl -fsSL https://archive.apache.org/dist/spark/spark-3.4.1/spark-3.4.1-bin-hadoop3.tgz | tar -xz -C /opt && \
    mv /opt/spark-3.4.1-bin-hadoop3 /opt/spark && \
    mkdir -p /hadoop-data/name /hadoop-data/data /data

ENV HADOOP_HOME=/opt/hadoop \
    HADOOP_CONF_DIR=/opt/hadoop/etc/hadoop \
    SPARK_HOME=/opt/spark \
    PYSPARK_PYTHON=python3 \
    HDFS_NAMENODE_USER=root \
    HDFS_DATANODE_USER=root \
    HDFS_SECONDARYNAMENODE_USER=root
ENV PATH=$PATH:/opt/hadoop/bin:/opt/hadoop/sbin:/opt/spark/bin:/opt/spark/sbin

# Configuration shared by every node.
RUN echo 'export JAVA_HOME=/opt/java/openjdk' >> /opt/hadoop/etc/hadoop/hadoop-env.sh && \
    printf '<configuration>\n<property><name>fs.defaultFS</name><value>hdfs://main:9000</value></property>\n</configuration>\n' > /opt/hadoop/etc/hadoop/core-site.xml && \
    printf '<configuration>\n<property><name>dfs.replication</name><value>2</value></property>\n<property><name>dfs.namenode.name.dir</name><value>file:///hadoop-data/name</value></property>\n<property><name>dfs.datanode.data.dir</name><value>file:///hadoop-data/data</value></property>\n<property><name>dfs.permissions.enabled</name><value>false</value></property>\n<property><name>dfs.namenode.datanode.registration.ip-hostname-check</name><value>false</value></property>\n<property><name>dfs.namenode.safemode.extension</name><value>0</value></property>\n</configuration>\n' > /opt/hadoop/etc/hadoop/hdfs-site.xml && \
    printf 'export JAVA_HOME=/opt/java/openjdk\nexport SPARK_MASTER_HOST=main\nexport SPARK_WORKER_CORES=2\nexport SPARK_WORKER_MEMORY=2g\n' > /opt/spark/conf/spark-env.sh && \
    printf 'spark.driver.memory 1g\nspark.executor.memory 1g\nspark.default.parallelism 6\nspark.sql.shuffle.partitions 6\n' > /opt/spark/conf/spark-defaults.conf && \
    printf 'Host *\n  StrictHostKeyChecking no\n' > /root/.ssh/config

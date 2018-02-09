FROM centos:centos7
MAINTAINER moremagic <itoumagic@gmail.com>

RUN yum -y update
RUN yum upgrade -y ca-certificates

# Add Oracle requirements
RUN yum install -y libaio bc flex net-tools
#RUN mkdir -p /var/lock/subsys

# Install Oracle XE
# - Check RPM SHA1
# - Work around the Swap memory limitation
# - Work around the sysctl limitation of Docker
ADD oracle-xe-11.2.0-1.0.x86_64.rpm /tmp/
RUN sha1sum /tmp/oracle-xe-11.2.0-1.0.x86_64.rpm | grep -q "49e850d18d33d25b9146daa5e8050c71c30390b7" \
    && mv /usr/bin/free /usr/bin/free.bak \
    && printf "#!/bin/sh\necho Swap - - 2048" > /usr/bin/free \
    && chmod +x /usr/bin/free \
    && mv /sbin/sysctl /sbin/sysctl.bak \
    && printf "#!/bin/sh" > /sbin/sysctl \
    && chmod +x /sbin/sysctl \
    && rpm --install /tmp/oracle-xe-11.2.0-1.0.x86_64.rpm \
    && rm /tmp/oracle-xe-11.2.0-1.0.x86_64.rpm* \
    && rm /usr/bin/bc \
    && rm /usr/bin/free \
    && mv /usr/bin/free.bak /usr/bin/free \
    && rm /sbin/sysctl \
    && mv /sbin/sysctl.bak /sbin/sysctl \
    && yum clean all

ADD start-oracle.sh /u01/app/oracle

# Configure Oracle
RUN printf "\
ORACLE_HTTP_PORT=8080 \n\
ORACLE_LISTENER_PORT=1521 \n\
ORACLE_PASSWORD=oracle \n\
ORACLE_CONFIRM_PASSWORD=oracle \n\
ORACLE_DBENABLE=y \n\
" > /tmp/response \
    && sed -i -e 's/^\(memory_target=.*\)/#\1/' /u01/app/oracle/product/11.2.0/xe/config/scripts/initXETemp.ora \
    && sed -i -e 's/^\(memory_target=.*\)/#\1/' /u01/app/oracle/product/11.2.0/xe/config/scripts/init.ora \
    && /etc/init.d/oracle-xe configure responseFile=/tmp/response \
    && rm /tmp/response

# Configure bashrc
RUN  printf '\
export ORACLE_HOME=/u01/app/oracle/product/11.2.0/xe \n\
export PATH=$ORACLE_HOME/bin:$PATH \n\
export ORACLE_SID=XE \n\
' >> /etc/bash.bashrc

EXPOSE 1521 8080

# Add Tini
ENV TINI_VERSION v0.16.1
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini
RUN chmod +x /tini
ENTRYPOINT ["/tini", "--"]

RUN chmod 755 /u01/app/oracle/start-oracle.sh && chown oracle:dba /u01/app/oracle/start-oracle.sh
USER oracle
CMD /u01/app/oracle/start-oracle.sh

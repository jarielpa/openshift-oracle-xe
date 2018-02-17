FROM centos:centos7
MAINTAINER jgrumboe <johannes@grumboeck.net>

# Update everything and add Oracle requirements
RUN yum -y update \
    && yum upgrade -y ca-certificates \
    && yum clean all

# Add Tini
ENV TINI_VERSION v0.16.1
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini
RUN chmod +x /tini
ENTRYPOINT ["/tini", "--"]

# Install Oracle XE
# - Check RPM SHA1
# - Install deps
# - Work around the Swap memory limitation
# - Work around the sysctl limitation of Docker
ADD oracle-xe-11.2.0-1.0.x86_64.rpm.* /tmp/
RUN cat /tmp/oracle-xe-11.2.0-1.0.x86_64.rpm.* > /tmp/oracle-xe-11.2.0-1.0.x86_64.rpm \
    && rm /tmp/oracle-xe-11.2.0-1.0.x86_64.rpm.* \
    && sha1sum /tmp/oracle-xe-11.2.0-1.0.x86_64.rpm | grep -q "49e850d18d33d25b9146daa5e8050c71c30390b7" \
    && yum install -y libaio bc flex net-tools \
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


# Configure Oracle
# - run configure
# - configure bashrc
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
    && rm /tmp/response \
    &&  printf '\
export ORACLE_HOME=/u01/app/oracle/product/11.2.0/xe \n\
export PATH=$ORACLE_HOME/bin:$PATH \n\
export ORACLE_SID=XE \n\
' >> /etc/bash.bashrc

# Add custom startup-script to run oracle as non-root
ADD start-oracle.sh /u01/app/oracle

# Adjust permissions
RUN chmod +wx /u01/app/oracle/start-oracle.sh \
    && chown oracle:dba /u01/app/oracle/start-oracle.sh \
    && chmod -Rf g+w /etc/passwd /etc/group

USER oracle
EXPOSE 1521 8080
CMD /u01/app/oracle/start-oracle.sh

FROM centos:centos7
MAINTAINER Patrick M. Slattery <pslattery@mywebgrocer.org>

# Java Version
ENV JAVA_VERSION_MAJOR 8
ENV JAVA_VERSION_MINOR 92
ENV JAVA_VERSION_BUILD 14
ENV JAVA_PACKAGE server-jre
# Set environment
ENV JAVA_HOME /opt/java

# Download and unarchive Java
RUN \
  # overlayfs workaround
  touch /var/lib/rpm/* && \
  yum clean all && yum update -y && yum clean all && \
  curl --fail --retry 3 --insecure --header "Cookie: gpw_e24=http%3A%2F%2Fwww.oracle.com%2F; oraclelicense=accept-securebackup-cookie"\
  --location http://download.oracle.com/otn-pub/java/jdk/${JAVA_VERSION_MAJOR}u${JAVA_VERSION_MINOR}-b${JAVA_VERSION_BUILD}/${JAVA_PACKAGE}-${JAVA_VERSION_MAJOR}u${JAVA_VERSION_MINOR}-linux-x64.tar.gz -#\
  | gunzip | tar x -C /opt && \
  mv /opt/jdk1.${JAVA_VERSION_MAJOR}.0_${JAVA_VERSION_MINOR} /opt/java && \
  rm -rf /opt/java/*src.zip \
    /opt/java/lib/missioncontrol \
    /opt/java/lib/visualvm \
    /opt/java/lib/*javafx* \
    /opt/java/jre/lib/plugin.jar \
    /opt/java/jre/lib/ext/jfxrt.jar \
    /opt/java/jre/bin/javaws \
    /opt/java/jre/lib/javaws.jar \
    /opt/java/jre/lib/desktop \
    /opt/java/jre/plugin \
    /opt/java/jre/lib/deploy* \
    /opt/java/jre/lib/*javafx* \
    /opt/java/jre/lib/*jfx* \
    /opt/java/jre/lib/amd64/libdecora_sse.so \
    /opt/java/jre/lib/amd64/libprism_*.so \
    /opt/java/jre/lib/amd64/libfxplugins.so \
    /opt/java/jre/lib/amd64/libglass.so \
    /opt/java/jre/lib/amd64/libgstreamer-lite.so \
    /opt/java/jre/lib/amd64/libjavafx*.so \
    /opt/java/jre/lib/amd64/libjfx*.so

# Define default command.

RUN yum install -y git zip && yum clean all
ENV JENKINS_HOME /var/jenkins_home
ENV JENKINS_SLAVE_AGENT_PORT 50000

ARG user=jenkins
ARG group=jenkins
ARG uid=1000
ARG gid=1000

# Jenkins is run with user `jenkins`, uid = 1000
# If you bind mount a volume from the host or a data container, 
# ensure you use the same uid
RUN groupadd -g ${gid} ${group} \
    && useradd -d "$JENKINS_HOME" -u ${uid} -g ${gid} -m -s /bin/bash ${user}

# Jenkins home directory is a volume, so configuration and build history 
# can be persisted and survive image upgrades
VOLUME /var/jenkins_home

# `/usr/share/jenkins/ref/` contains all reference configuration we want 
# to set on a fresh new installation. Use it to bundle additional plugins 
# or config file with your custom jenkins Docker image.
RUN mkdir -p /usr/share/jenkins/ref/init.groovy.d

ENV TINI_SHA 066ad710107dc7ee05d3aa6e4974f01dc98f3888

# Use tini as subreaper in Docker container to adopt zombie processes 
RUN curl -fsSL https://github.com/krallin/tini/releases/download/v0.5.0/tini-static -o /bin/tini && chmod +x /bin/tini \
  && echo "$TINI_SHA  /bin/tini" | sha1sum -c -

COPY init.groovy /usr/share/jenkins/ref/init.groovy.d/tcp-slave-agent-port.groovy

ARG JENKINS_VERSION
ENV JENKINS_VERSION ${JENKINS_VERSION:-1.651.2}
ARG JENKINS_SHA
ENV JENKINS_SHA ${JENKINS_SHA:-f61b8b604acba5076a93dcde28c0be2561d17bde}


# could use ADD but this one does not check Last-Modified header 
# see https://github.com/docker/docker/issues/8331
RUN curl -fsSL http://repo.jenkins-ci.org/public/org/jenkins-ci/main/jenkins-war/${JENKINS_VERSION}/jenkins-war-${JENKINS_VERSION}.war -o /usr/share/jenkins/jenkins.war \
  && echo "$JENKINS_SHA  /usr/share/jenkins/jenkins.war" | sha1sum -c -

ENV JENKINS_UC https://updates.jenkins.io
RUN chown -R ${user} "$JENKINS_HOME" /usr/share/jenkins/ref

# for main web interface:
EXPOSE 8080

# will be used by attached slave agents:
EXPOSE 50000

ENV COPY_REFERENCE_FILE_LOG $JENKINS_HOME/copy_reference_file.log

USER ${user}

COPY jenkins.sh /usr/local/bin/jenkins.sh
ENTRYPOINT ["/bin/tini", "--", "/usr/local/bin/jenkins.sh"]

# from a derived Dockerfile, can use `RUN plugins.sh active.txt` to setup /usr/share/jenkins/ref/plugins from a support bundle
COPY plugins.sh /usr/local/bin/plugins.sh
COPY install-plugins.sh /usr/local/bin/install-plugins.sh

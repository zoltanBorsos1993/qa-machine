FROM jenkins/jenkins:lts

ARG DOCKER_GROUP_ID

# COPY --chown=jenkins:jenkins resources/configuration/config.xml /var/jenkins_home/
# COPY --chown=jenkins:jenkins resources/configuration/users /var/jenkins_home/users

USER root

RUN groupadd --gid $DOCKER_GROUP_ID docker
RUN usermod -aG docker jenkins

USER jenkins
COPY --chown=jenkins:jenkins resources/plugins.list /tmp/
RUN install-plugins.sh $(cat /tmp/plugins.list)

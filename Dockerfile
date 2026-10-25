# Extend the supported Jenkins LTS image with the plugins required by JCasC and the seed pipeline.
FROM jenkins/jenkins:lts

# Provide the Docker client used by deployment pipelines; the daemon remains on the Ubuntu host.
USER root

RUN apt-get update && \
    apt-get install -y \
      git \
      jq \
      wget \
      curl \
      util-linux && \
    mkdir -p /tmp/dockercli && \
    curl -fsSL https://download.docker.com/linux/static/stable/x86_64/docker-27.3.1.tgz \
      -o /tmp/dockercli/docker.tgz && \
    tar -xzf /tmp/dockercli/docker.tgz -C /tmp/dockercli && \
    cp /tmp/dockercli/docker/docker /usr/local/bin/docker && \
    chmod +x /usr/local/bin/docker && \
    rm -rf /tmp/dockercli

USER jenkins

# Let Jenkins' plugin manager resolve compatible transitive dependencies at image build time.
COPY --chown=jenkins:jenkins plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli -f /usr/share/jenkins/ref/plugins.txt

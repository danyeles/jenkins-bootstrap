# Extend the supported Jenkins LTS image with the plugins required by JCasC and the seed pipeline.
FROM jenkins/jenkins:lts

# Provide the Docker client used by deployment pipelines; the daemon remains on the Ubuntu host.
USER root
RUN apt-get update \
	&& apt-get install --no-install-recommends -y docker.io \
	&& rm -rf /var/lib/apt/lists/*
USER jenkins

# Let Jenkins' plugin manager resolve compatible transitive dependencies at image build time.
COPY --chown=jenkins:jenkins plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli -f /usr/share/jenkins/ref/plugins.txt
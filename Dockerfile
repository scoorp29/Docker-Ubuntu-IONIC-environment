FROM ubuntu:16.04

# -----------------------------------------------------------------------------
# General environment variables
# -----------------------------------------------------------------------------
ENV DEBIAN_FRONTEND=noninteractive


# -----------------------------------------------------------------------------
# Install system basics
# -----------------------------------------------------------------------------
RUN \
  apt-get update -qqy && \
  apt-get install -qqy --allow-unauthenticated \
          apt-transport-https \
          python-software-properties \
          software-properties-common \
          curl \
          expect \ 
          zip \
          libsass-dev \
          git \
          sudo


# -----------------------------------------------------------------------------
# Install OpenJDK-8
# -----------------------------------------------------------------------------

RUN apt-get update && \
    apt-get install -y openjdk-8-jdk && \
    apt-get install -y ant && \
    apt-get clean;

# Fix certificate issues
RUN apt-get update && \
    apt-get install ca-certificates-java && \
    apt-get clean && \
    update-ca-certificates -f;

# Setup JAVA_HOME -- useful for docker commandline
ENV JAVA_HOME /usr/lib/jvm/java-8-openjdk-amd64/
RUN export JAVA_HOME

# -----------------------------------------------------------------------------
# Install Android / Android SDK / Android SDK elements
# -----------------------------------------------------------------------------

ENV ANDROID_HOME /opt/android-sdk-linux
ENV PATH ${PATH}:${ANDROID_HOME}/tools:${ANDROID_HOME}/tools/bin:${ANDROID_HOME}/platform-tools:/opt/tools

ARG ANDROID_PLATFORMS_VERSION
ENV ANDROID_PLATFORMS_VERSION ${ANDROID_PLATFORMS_VERSION:-29}

ARG ANDROID_BUILD_TOOLS_VERSION
ENV ANDROID_BUILD_TOOLS_VERSION ${ANDROID_BUILD_TOOLS_VERSION:-29.0.2}

RUN \
  echo ANDROID_HOME=${ANDROID_HOME} >> /etc/environment && \
  dpkg --add-architecture i386 && \
  apt-get update -qqy && \
  apt-get install -qqy --allow-unauthenticated\
          gradle  \
          libc6-i386 \
          lib32stdc++6 \
          lib32gcc1 \
          lib32ncurses5 \
          lib32z1 \
          qemu-kvm \
          kmod && \
  cd /opt && \
  mkdir android-sdk-linux && \
  cd android-sdk-linux && \
  curl -SLo sdk-tools-linux.zip https://dl.google.com/android/repository/sdk-tools-linux-3859397.zip && \
  unzip sdk-tools-linux.zip && \
  rm -f sdk-tools-linux.zip && \
  chmod 777 ${ANDROID_HOME} -R  && \
  mkdir -p ${ANDROID_HOME}/licenses && \
  echo 8933bad161af4178b1185d1a37fbf41ea5269c55 > ${ANDROID_HOME}/licenses/android-sdk-license && \
  sdkmanager "tools" && \  
  sdkmanager "platform-tools" && \
  sdkmanager "platforms;android-${ANDROID_PLATFORMS_VERSION}" && \
  sdkmanager "build-tools;${ANDROID_BUILD_TOOLS_VERSION}"


# -----------------------------------------------------------------------------
# Install Node, NPM, yarn
# -----------------------------------------------------------------------------
ARG NODE_VERSION
ENV NODE_VERSION ${NODE_VERSION:-12.16.2} 

ARG NPM_VERSION
ENV NPM_VERSION ${NPM_VERSION:-6.14.4}

ARG PACKAGE_MANAGER
ENV PACKAGE_MANAGER ${PACKAGE_MANAGER:-npm}

ENV NPM_CONFIG_LOGLEVEL info

# gpg keys listed at https://github.com/nodejs/node
RUN \
  set -ex \
  && for key in \
    4ED778F539E3634C779C87C6D7062848A1AB005C \
    94AE36675C464D64BAFA68DD7434390BDBE9B9C5 \
    71DCFD284A79C3B38668286BC97EC7A07EDE3FC1 \
    8FCCA13FEF1D0C2E91008E09770F7A9A5AE15600 \
    C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8 \
    DD8F2338BAE7501E3DD5AC78C273792F7D83545D \
    A48C2BEE680E841632CD4E44F07496B3EB3C1762 \  
    B9E2F5981AA6E0CD28160D9FF13993A75599653C \
  ; do \
  gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "${key}"; \
  done && \ 
  curl -SLO "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz" && \
  curl -SLO "https://nodejs.org/dist/v${NODE_VERSION}/SHASUMS256.txt.asc" && \
  gpg --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc && \
  grep " node-v${NODE_VERSION}-linux-x64.tar.xz\$" SHASUMS256.txt | sha256sum -c - && \
  tar -xJf "node-v${NODE_VERSION}-linux-x64.tar.xz" -C /usr/local --strip-components=1 && \
  rm "node-v${NODE_VERSION}-linux-x64.tar.xz" SHASUMS256.txt.asc SHASUMS256.txt && \
  ln -s /usr/local/bin/node /usr/local/bin/nodejs && \
  chmod 777 /usr/local/lib/node_modules -R && \
  npm install -g npm@${NPM_VERSION} && \
  if [ "${PACKAGE_MANAGER}" = "yarn" ]; then \
    curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && \
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list && \
    apt-get update -qqy && apt-get install -qqy --allow-unauthenticated yarn; \
  fi


# -----------------------------------------------------------------------------
# Clean up
# -----------------------------------------------------------------------------
RUN \
  apt-get clean && \
  apt-get autoclean && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* 


# -----------------------------------------------------------------------------
# Create a non-root docker user to run this container
# -----------------------------------------------------------------------------
ARG USER
ENV USER ${USER:-ionic}

RUN \
  # create user with appropriate rights, groups and permissions
  useradd --user-group --create-home --shell /bin/false ${USER} && \
  echo "${USER}:${USER}" | chpasswd && \
  adduser ${USER} sudo && \
  adduser ${USER} root && \
  chmod 770 / && \
  usermod -a -G root ${USER} && \

  # create the file and set permissions now with root user  
  mkdir /app && chown ${USER}:${USER} /app && chmod 777 /app && \

  # create the file and set permissions now with root user
  touch /image.config && chown ${USER}:${USER} /image.config && chmod 777 /image.config && \

  # this is necessary for ionic commands to run
  mkdir /home/${USER}/.ionic && chown ${USER}:${USER} /home/${USER}/.ionic && chmod 777 /home/${USER}/.ionic && \

  # this is necessary to install global npm modules
  chmod 777 /usr/local/bin
  #&& chown ${USER}:${USER} ${ANDROID_HOME} -R


# -----------------------------------------------------------------------------
# Copy start.sh and set permissions 
# -----------------------------------------------------------------------------
COPY start.sh /start.sh
RUN chown ${USER}:${USER} /start.sh && chmod 777 /start.sh


# -----------------------------------------------------------------------------
# Switch the user of this image only now, because previous commands need to be 
# run as root
# -----------------------------------------------------------------------------
USER ${USER}


# -----------------------------------------------------------------------------
# Install Global node modules
# -----------------------------------------------------------------------------

ARG CORDOVA_VERSION
ENV CORDOVA_VERSION ${CORDOVA_VERSION:-9.0.0}

ARG IONIC_VERSION
ENV IONIC_VERSION ${IONIC_VERSION:-5.4.16}

ARG TYPESCRIPT_VERSION
ENV TYPESCRIPT_VERSION ${TYPESCRIPT_VERSION:-3.8.3}

ARG GULP_VERSION
ENV GULP_VERSION ${GULP_VERSION}

RUN \
  if [ "${PACKAGE_MANAGER}" != "yarn" ]; then \
    export PACKAGE_MANAGER="npm" && \
    npm install -g cordova@"${CORDOVA_VERSION}" && \
    if [ -n "${IONIC_VERSION}" ]; then npm install -g ionic@"${IONIC_VERSION}"; fi && \
    if [ -n "${TYPESCRIPT_VERSION}" ]; then npm install -g typescript@"${TYPESCRIPT_VERSION}"; fi && \
    if [ -n "${GULP_VERSION}" ]; then npm install -g gulp@"${GULP_VERSION}"; fi \
  else \
    yarn global add cordova@"${CORDOVA_VERSION}" && \
    if [ -n "${IONIC_VERSION}" ]; then yarn global add ionic@"${IONIC_VERSION}"; fi && \
    if [ -n "${TYPESCRIPT_VERSION}" ]; then yarn global add typescript@"${TYPESCRIPT_VERSION}"; fi && \
    if [ -n "${GULP_VERSION}" ]; then yarn global add gulp@"${GULP_VERSION}"; fi \
  fi && \
  ${PACKAGE_MANAGER} cache clean --force


# -----------------------------------------------------------------------------
# Create the image.config file for the container to check the build 
# configuration of this container later on 
# -----------------------------------------------------------------------------
RUN \
echo "USER: ${USER}\n\
ANDROID_PLATFORMS_VERSION: ${ANDROID_PLATFORMS_VERSION}\n\
ANDROID_BUILD_TOOLS_VERSION: ${ANDROID_BUILD_TOOLS_VERSION}\n\
NODE_VERSION: ${NODE_VERSION}\n\
NPM_VERSION: ${NPM_VERSION}\n\
PACKAGE_MANAGER: ${PACKAGE_MANAGER}\n\
CORDOVA_VERSION: ${CORDOVA_VERSION}\n\
IONIC_VERSION: ${IONIC_VERSION}\n\
TYPESCRIPT_VERSION: ${TYPESCRIPT_VERSION}\n\
GULP_VERSION: ${GULP_VERSION:-none}\n\
" >> /image.config && \
cat /image.config

# -----------------------------------------------------------------------------
# WORKDIR is the generic /app folder. All volume mounts of the actual project
# code need to be put into /app.
# -----------------------------------------------------------------------------
RUN mkdir -p /app
WORKDIR /app

# -----------------------------------------------------------------------------
# Generate an Ionic default app (do this with root user, since we will not
# have permissions for /app otherwise), install the dependencies
# and add and build android platform
# -----------------------------------------------------------------------------
RUN \
  chown ${USER}:${USER} /app && chmod 777 /app && \
  cd / && \
  ionic start myapp blank --type ionic-angular --no-deps --no-link --no-git && \
  cd /app && \
  ${PACKAGE_MANAGER} install && \
  ionic cordova platform add android --no-resources && \
  ionic cordova build android


# -----------------------------------------------------------------------------
# Just in case you are installing from private git repositories, enable git
# credentials
# -----------------------------------------------------------------------------
RUN git config --global credential.helper store

# -----------------------------------------------------------------------------
# The script start.sh installs package.json and puts a watch on it. This makes
# sure that the project has allways the latest dependencies installed.
# -----------------------------------------------------------------------------
ENTRYPOINT ["/start.sh"]


# -----------------------------------------------------------------------------
# After /start.sh the bash is called.
# -----------------------------------------------------------------------------
CMD ["ionic", "serve", "-b", "-p", "8100", "--address", "0.0.0.0"]

FROM ubuntu:24.04

# Set non-interactive to avoid prompts
ENV DEBIAN_FRONTEND=noninteractive

# Set Java and Maven environment variables
ENV JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
ENV MAVEN_HOME=/opt/apache-maven-3.9.11
ENV GRADLE_HOME=/opt/gradle-9.0.0
ENV PATH=$JAVA_HOME/bin:$MAVEN_HOME/bin:$GRADLE_HOME/bin:$PATH

# Install basic dependencies and tools
RUN apt-get update && apt-get install -y \
    curl \
    sudo \
    git \
    jq \
    libicu-dev \
    ca-certificates \
    wget \
    lsb-release \
    build-essential \
    software-properties-common \
    gnupg \
    unzip \
    zip \
    && rm -rf /var/lib/apt/lists/*

# Install Python 3.11
RUN add-apt-repository -y ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get install -y \
    python3.11 \
    python3.11-venv \
    python3.11-dev \
    python3-pip \
    && update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1 \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js LTS
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - && \
    apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install Playwright browser dependencies for Ubuntu 24.04
# Note: Ubuntu 24.04 uses t64 suffix for many packages due to 64-bit time_t transition
RUN apt-get update && apt-get install -y \
    libnss3 \
    libnspr4 \
    libatk1.0-0t64 \
    libatk-bridge2.0-0t64 \
    libcups2t64 \
    libdrm2 \
    libdbus-1-3 \
    libatspi2.0-0t64 \
    libx11-6 \
    libxcomposite1 \
    libxdamage1 \
    libxext6 \
    libxfixes3 \
    libxrandr2 \
    libgbm1 \
    libxcb1 \
    libxkbcommon0 \
    libpango-1.0-0 \
    libcairo2 \
    libasound2t64 \
    libasound2-data \
    libgtk-3-0t64 \
    libgdk-pixbuf-2.0-0 \
    libgdk-pixbuf2.0-0 \
    libxshmfence1 \
    fonts-liberation \
    fonts-freefont-ttf \
    fonts-ipafont-gothic \
    fonts-noto-color-emoji \
    fonts-tlwg-loma-otf \
    fonts-unifont \
    fonts-wqy-zenhei \
    xfonts-cyrillic \
    xfonts-scalable \
    libxtst6 \
    libxss1 \
    libexpat1 \
    libxcursor1 \
    libxi6 \
    libglib2.0-0t64 \
    libpangocairo-1.0-0 \
    libx11-xcb1 \
    libxrender1 \
    libxinerama1 \
    xvfb \
    && rm -rf /var/lib/apt/lists/*

# Install Playwright globally as root
# DO NOT use install-deps as it will try to install old package names
RUN npm install -g playwright@latest

# Install Java 21 LTS
RUN apt-get update && \
    apt-get install -y openjdk-21-jdk && \
    rm -rf /var/lib/apt/lists/*

# Install Maven 3.9.11 (matching GitHub runners)
RUN wget -q https://dlcdn.apache.org/maven/maven-3/3.9.11/binaries/apache-maven-3.9.11-bin.tar.gz && \
    tar -xzf apache-maven-3.9.11-bin.tar.gz -C /opt && \
    rm apache-maven-3.9.11-bin.tar.gz && \
    ln -s /opt/apache-maven-3.9.11/bin/mvn /usr/local/bin/mvn && \
    ln -s /opt/apache-maven-3.9.11/bin/mvnDebug /usr/local/bin/mvnDebug

# Install Gradle
RUN wget -q -O gradle-9.0.0-bin.zip https://github.com/gradle/gradle-distributions/releases/download/v9.0.0/gradle-9.0.0-bin.zip && \
    unzip -q gradle-9.0.0-bin.zip -d /opt && \
    rm gradle-9.0.0-bin.zip && \
    ln -s /opt/gradle-9.0.0/bin/gradle /usr/local/bin/gradle

# Install .NET SDK
RUN wget -q https://packages.microsoft.com/config/ubuntu/24.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb && \
    dpkg -i packages-microsoft-prod.deb && \
    rm packages-microsoft-prod.deb && \
    apt-get update && \
    apt-get install -y dotnet-sdk-8.0 || true && \
    rm -rf /var/lib/apt/lists/*

# Install Docker
RUN apt-get update && apt-get install -y \
    docker.io \
    docker-compose-v2 \
    && rm -rf /var/lib/apt/lists/*

# Install additional build tools
RUN apt-get update && apt-get install -y \
    ant \
    rsync \
    shellcheck \
    postgresql-client \
    mysql-client \
    && rm -rf /var/lib/apt/lists/*

# Create runner user and add to docker group
RUN useradd -m runner && \
    echo "runner ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    usermod -aG docker runner

USER runner
WORKDIR /home/runner

# Download and extract latest runner
RUN RUNNER_VERSION=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | jq -r '.tag_name' | sed 's/v//') && \
    curl -o actions-runner.tar.gz -L \
    https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz && \
    tar xzf actions-runner.tar.gz && \
    rm actions-runner.tar.gz && \
    sudo ./bin/installdependencies.sh

# Install Playwright browsers as runner user
# Set environment variable to skip OS validation since Ubuntu 24.04 is not officially supported yet
ENV PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=true
RUN npm install playwright && \
    npx playwright install chromium

# Copy and set entrypoint
COPY --chown=runner:runner entrypoint.sh .
RUN chmod +x entrypoint.sh

ENTRYPOINT ["./entrypoint.sh"]
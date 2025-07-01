FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Update system and install basic dependencies
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y \
    wget \
    curl \
    git \
    python3 \
    python3-pip \
    neofetch \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    sudo \
    postgresql \
    postgresql-contrib \
    libpq-dev \
    && apt-get clean

# Install Docker
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update && \
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Install ttyd
RUN wget -qO /bin/ttyd https://github.com/tsl0922/ttyd/releases/download/1.7.3/ttyd.x86_64 && \
    chmod +x /bin/ttyd

# Install Coder
RUN curl -L https://coder.com/install.sh | sh

# Create a non-root user for running Coder
RUN groupadd -f sudo && \
    useradd -m -s /bin/bash -G docker coder && \
    usermod -aG sudo coder && \
    echo "coder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Add neofetch to both users' bashrc
RUN echo "neofetch" >> /root/.bashrc && \
    echo "neofetch" >> /home/coder/.bashrc

# Switch to coder user
USER coder
WORKDIR /home/coder

# Expose Coder's default port
EXPOSE 3000

# Start Coder server
CMD ["coder", "server", "--http-address", "0.0.0.0:3000"]

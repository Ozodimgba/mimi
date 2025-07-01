FROM ubuntu:22.04

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    openssh-server \
    sudo \
    curl \
    wget \
    git \
    vim \
    nano \
    htop \
    build-essential \
    python3 \
    python3-pip \
    nodejs \
    npm \
    zsh \
    ca-certificates \
    gnupg \
    lsb-release \
    && rm -rf /var/lib/apt/lists/*

# Install Docker CLI (useful for development)
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update \
    && apt-get install -y docker-ce-cli \
    && rm -rf /var/lib/apt/lists/*

# Create SSH directory and configure
RUN mkdir /var/run/sshd

# Create a development user
RUN useradd -rm -d /home/dev -s /bin/bash -g root -G sudo -u 1001 dev

# Set password for dev user (change this!)
RUN echo 'dev:devpassword' | chpasswd

# Allow dev user to sudo without password
RUN echo 'dev ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Configure SSH
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
RUN sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
RUN sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config

# Create .ssh directory for dev user
RUN mkdir -p /home/dev/.ssh && chown dev:root /home/dev/.ssh && chmod 700 /home/dev/.ssh

RUN curl -fsSL https://starship.rs/install.sh | sh -s -- --yes
RUN echo 'eval "$(starship init bash)"' >> /home/dev/.bashrc

# Install Oh My Zsh for dev user
USER dev
RUN sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" || true
RUN echo 'eval "$(starship init zsh)"' >> /home/dev/.zshrc
USER root

# Create workspace directory
RUN mkdir -p /workspace && chown dev:root /workspace

# Expose SSH port
EXPOSE 22

# Create startup script
RUN echo '#!/bin/bash\n\
service ssh start\n\
# Keep container running\n\
tail -f /dev/null' > /start.sh && chmod +x /start.sh

# Set working directory
WORKDIR /workspace

# Start SSH service
CMD ["/start.sh"]

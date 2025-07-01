FROM ubuntu:22.04

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive

# Update and install essential packages
RUN apt-get update && apt-get install -y \
    openssh-server \
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
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    sudo \
    zsh \
    && rm -rf /var/lib/apt/lists/*

# Install Docker CLI (useful for development)
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update \
    && apt-get install -y docker-ce-cli \
    && rm -rf /var/lib/apt/lists/*

# Create a development user
RUN useradd -m -s /bin/bash dev \
    && echo "dev:${DEV_PASSWORD:-dev123}" | chpasswd \
    && usermod -aG sudo dev \
    && echo "dev ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Configure SSH for Railway
RUN mkdir /var/run/sshd \
    && echo "root:${ROOT_PASSWORD:-root123}" | chpasswd \
    && sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config \
    && sed -i 's/#Port 22/Port 22/' /etc/ssh/sshd_config \
    && sed -i 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' /etc/pam.d/sshd

# Configure SSH to listen on Railway's assigned port
RUN echo "Port ${PORT:-22}" >> /etc/ssh/sshd_config

# Set up SSH keys directory
RUN mkdir -p /root/.ssh /home/dev/.ssh \
    && chmod 700 /root/.ssh /home/dev/.ssh \
    && chown dev:dev /home/dev/.ssh

# Install Oh My Zsh for better terminal experience
USER dev
RUN sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" --unattended || true
USER root
RUN chsh -s $(which zsh) dev || true

# Install common development tools
RUN npm install -g yarn typescript nodemon ts-node \
    && pip3 install --upgrade pip setuptools wheel

# Create workspace directory
RUN mkdir -p /workspace \
    && chown dev:dev /workspace

# Set working directory
WORKDIR /workspace

# Set up dev user's environment
USER dev
RUN git config --global init.defaultBranch main \
    && echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc \
    && echo 'cd /workspace' >> ~/.bashrc \
    && echo 'export PS1="\[\033[01;32m\]\u@railway\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "' >> ~/.bashrc

# Switch back to root for final setup
USER root

# Create startup script that handles Railway's PORT environment variable
RUN echo '#!/bin/bash\n\
# Use Railway PORT if available, otherwise default to 22\n\
SSH_PORT=${PORT:-22}\n\
echo "Starting SSH server on port $SSH_PORT"\n\
\n\
# Update SSH config with the correct port\n\
sed -i "s/^Port .*/Port $SSH_PORT/" /etc/ssh/sshd_config\n\
\n\
# Generate SSH host keys if they dont exist\n\
ssh-keygen -A\n\
\n\
# Start SSH service\n\
/usr/sbin/sshd -D -p $SSH_PORT\n\
' > /start.sh && chmod +x /start.sh

# Expose the port (Railway will override this)
EXPOSE $PORT

# Start SSH service
CMD ["/start.sh"]

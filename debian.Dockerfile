FROM debian:12 AS base
WORKDIR /usr/local/bin
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y build-essential curl git pipx software-properties-common sudo && \
    apt-get clean autoclean && \
    apt-get autoremove --yes

FROM base AS jobrk
RUN addgroup --gid 1000 jobrk
RUN adduser --gecos jobrk --uid 1000 --gid 1000 --disabled-password jobrk
RUN echo "jobrk ALL=(ALL:ALL) NOPASSWD:ALL" > /etc/sudoers.d/jobrk
USER jobrk
WORKDIR /home/jobrk

FROM jobrk 
RUN pipx install --include-deps ansible
COPY . ./ansible
RUN ./.local/bin/ansible-playbook ./ansible/main.yml
ENV TERM xterm-256color
CMD ["/bin/zsh"]


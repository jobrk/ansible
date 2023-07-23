FROM fedora:37 AS base
WORKDIR /usr/local/bin
RUN dnf update -y && \
    dnf install -y pipx && \
    dnf clean all

FROM base AS jobrk
RUN groupadd -g 1000 jobrk
RUN adduser -u 1000 -g 1000 jobrk
RUN echo "jobrk ALL=(ALL:ALL) NOPASSWD:ALL" > /etc/sudoers.d/jobrk
USER jobrk
WORKDIR /home/jobrk

FROM jobrk 
RUN pipx install --include-deps ansible
COPY . ./ansible
RUN ./.local/bin/ansible-playbook ./ansible/main.yml
ENV TERM xterm-256color
CMD ["/bin/zsh"]


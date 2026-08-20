FROM debian:13 AS base
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
COPY --chown=jobrk . ./ansible
# Run twice: second run must report changed=0 (idempotency gate)
RUN ./.local/bin/ansible-playbook ./ansible/main.yml
RUN ./.local/bin/ansible-playbook ./ansible/main.yml | tee /tmp/second-run.log && \
    grep -E 'changed=0.*failed=0' /tmp/second-run.log
ENV TERM=xterm-256color
CMD ["/bin/zsh"]

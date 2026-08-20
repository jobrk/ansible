FROM fedora:44 AS base
WORKDIR /usr/local/bin
RUN dnf update -y && \
    dnf install -y pipx git sudo && \
    dnf clean all

FROM base AS jobrk
RUN groupadd -g 1000 jobrk
RUN adduser -u 1000 -g 1000 jobrk
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

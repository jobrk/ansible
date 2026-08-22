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
RUN ./.local/bin/ansible-playbook -i ./ansible/inventory.ini ./ansible/main.yml --skip-tags ui
RUN ./.local/bin/ansible-playbook -i ./ansible/inventory.ini ./ansible/main.yml --skip-tags ui | tee /tmp/second-run.log && \
    grep -E 'changed=0.*failed=0' /tmp/second-run.log
RUN /bin/zsh -lic 'bash ~/ansible/tests/smoke.sh'
ENV TERM=xterm-256color
CMD ["/bin/zsh"]

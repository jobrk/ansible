FROM debian:13 AS base
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
    apt-get install -y curl git pipx sudo && \
    apt-get clean

FROM base AS jobrk
RUN adduser --gecos jobrk --disabled-password jobrk
RUN echo "jobrk ALL=(ALL:ALL) NOPASSWD:ALL" > /etc/sudoers.d/jobrk
USER jobrk
WORKDIR /home/jobrk

FROM jobrk
RUN pipx install --include-deps ansible
COPY --chown=jobrk . ./ansible
RUN ./.local/bin/ansible-galaxy collection install -r ./ansible/requirements.yml
RUN ./.local/bin/ansible-playbook -i ./ansible/inventory.ini ./ansible/main.yml --skip-tags ui
RUN ./.local/bin/ansible-playbook -i ./ansible/inventory.ini ./ansible/main.yml --skip-tags ui | tee /tmp/second-run.log && \
    grep -E 'changed=0.*failed=0' /tmp/second-run.log
RUN /bin/zsh -lic 'bash ~/ansible/tests/smoke.sh'
ENV TERM=xterm-256color
CMD ["/bin/zsh"]

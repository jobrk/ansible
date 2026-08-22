FROM debian:13 AS cloud-init-test
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
    apt-get install -y cloud-init sudo && \
    apt-get clean
COPY cloud-init.yml /tmp/cloud-init.yml
RUN cloud-init schema --config-file /tmp/cloud-init.yml
COPY cloud-init.yml /var/lib/cloud/seed/nocloud/user-data
COPY tests/cloud-init-meta-data.yml /var/lib/cloud/seed/nocloud/meta-data
RUN cloud-init clean --logs && \
    cloud-init init --local && \
    cloud-init init && \
    cloud-init modules --mode=config && \
    cloud-init modules --mode=final && \
    cloud-init status --long | grep -q 'status: done' && \
    locale -a | grep -qx en_US.utf8 && \
    grep -qx LANG=en_US.UTF-8 /etc/default/locale && \
    ! grep -ER '^[[:space:]]*AcceptEnv[[:space:]]' /etc/ssh/sshd_config /etc/ssh/sshd_config.d && \
    getent passwd josh >/dev/null && \
    test -s /home/josh/.ssh/authorized_keys && \
    test -x /home/josh/.local/bin/nvim && \
    test -f /home/josh/.local/state/nvim/provisioned && \
    test "$(getent passwd josh | cut -d: -f7)" = /bin/zsh && \
    touch /cloud-init-test-passed

FROM debian:13 AS base
ENV DEBIAN_FRONTEND=noninteractive
COPY --from=cloud-init-test /cloud-init-test-passed /cloud-init-test-passed
RUN apt-get update && \
    apt-get install -y curl git openssh-server pipx sudo && \
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

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
    ! test -x /usr/bin/Hyprland && \
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
RUN git -C ./ansible remote set-url origin https://github.com/jobrk/ansible
RUN ./ansible/bootstrap.sh
RUN ./ansible/bootstrap.sh | tee /tmp/second-run.log && \
    grep -E 'changed=0.*failed=0' /tmp/second-run.log
USER root
RUN grep -qx 'XSession=hyprland' /var/lib/AccountsService/users/jobrk && \
    grep -qx 'vt = 7' /etc/greetd/config.toml && \
    grep -qx 'command = "/usr/sbin/agreety --cmd /usr/bin/start-hyprland"' /etc/greetd/config.toml && \
    test -x /usr/sbin/agreety && \
    test -x /usr/bin/start-hyprland && \
    dpkg-query -W cliphist flatpak hyprland-guiutils hyprland-qtutils hyprpolkitagent \
      mako-notifier qt6-wayland qtwayland5 waybar wl-clipboard xdg-utils && \
    systemctl get-default | grep -qx graphical.target && \
    systemctl is-enabled greetd | grep -qx enabled && \
    setcap -r /usr/bin/Hyprland
USER jobrk
RUN /bin/zsh -lic 'bash ~/ansible/tests/smoke.sh'
ENV TERM=xterm-256color
CMD ["/bin/zsh"]

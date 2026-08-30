FROM ubuntu:26.04 AS base
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
    apt-get install -y curl git pipx sudo && \
    apt-get clean

FROM base AS jobrk
RUN adduser --gecos jobrk --disabled-password jobrk
# Exercise Ansible's password-based fallback from sudo-rs to sudo.ws.
RUN echo 'jobrk:testpass' | chpasswd
RUN echo "jobrk ALL=(ALL:ALL) ALL" > /etc/sudoers.d/jobrk
USER jobrk
WORKDIR /home/jobrk

FROM jobrk
RUN pipx install --include-deps ansible
COPY --chown=jobrk . ./ansible
RUN git -C ./ansible remote set-url origin https://github.com/jobrk/ansible
RUN --mount=type=secret,id=GITHUB_TOKEN,uid=1000 \
    (sleep 5; printf 'testpass\n') | script -qec './ansible/bootstrap.sh' /dev/null
RUN --mount=type=secret,id=GITHUB_TOKEN,uid=1000 \
    (sleep 5; printf 'testpass\n') | script -qec './ansible/bootstrap.sh' /tmp/second-run.log && \
    grep -E 'changed=0.*failed=0' /tmp/second-run.log
USER root
RUN grep -qx 'XSession=hyprland' /var/lib/AccountsService/users/jobrk && \
    grep -qx 'vt = 7' /etc/greetd/config.toml && \
    grep -qx 'command = "/usr/sbin/agreety --cmd /usr/bin/start-hyprland"' /etc/greetd/config.toml && \
    test -x /usr/sbin/agreety && \
    test -x /usr/bin/start-hyprland && \
    dpkg-query -W cliphist flatpak ghostty hyprland-qtutils hyprpolkitagent mako-notifier qt6-wayland \
      qtwayland5 waybar wl-clipboard xdg-utils && \
    systemctl get-default | grep -qx graphical.target && \
    systemctl is-enabled greetd | grep -qx enabled
USER jobrk
RUN SMOKE_CONTAINER=1 /bin/zsh -lic 'bash ~/ansible/tests/smoke.sh'
ENV TERM=xterm-256color
CMD ["/bin/zsh"]

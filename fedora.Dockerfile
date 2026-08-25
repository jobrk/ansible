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
RUN --mount=type=secret,id=GITHUB_TOKEN \
    ./.local/bin/ansible-playbook -i ./ansible/inventory.ini ./ansible/main.yml
RUN --mount=type=secret,id=GITHUB_TOKEN \
    ./.local/bin/ansible-playbook -i ./ansible/inventory.ini ./ansible/main.yml | tee /tmp/second-run.log && \
    grep -E 'changed=0.*failed=0' /tmp/second-run.log
USER root
RUN grep -qx 'XSession=hyprland' /var/lib/AccountsService/users/jobrk && \
    grep -qx 'vt = 1' /etc/greetd/config.toml && \
    grep -qx 'command = "/usr/bin/agreety --cmd /usr/bin/start-hyprland"' /etc/greetd/config.toml && \
    grep -qx 'user = "greetd"' /etc/greetd/config.toml && \
    test -x /usr/bin/agreety && \
    test -x /usr/bin/start-hyprland && \
    rpm -q cliphist flatpak hyprland-guiutils hyprpolkitagent mako qt5-qtwayland qt6-qtwayland \
      waybar wl-clipboard xdg-utils && \
    systemctl get-default | grep -qx graphical.target && \
    systemctl is-enabled greetd | grep -qx enabled
USER jobrk
RUN SMOKE_CONTAINER=1 /bin/zsh -lic 'bash ~/ansible/tests/smoke.sh'
ENV TERM=xterm-256color
CMD ["/bin/zsh"]

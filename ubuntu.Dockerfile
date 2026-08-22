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
RUN (sleep 5; printf 'testpass\n') | script -qec './ansible/bootstrap.sh' /dev/null
RUN (sleep 5; printf 'testpass\n') | script -qec './ansible/bootstrap.sh' /tmp/second-run.log && \
    grep -E 'changed=0.*failed=0' /tmp/second-run.log
USER root
RUN grep -qx 'XSession=i3' /var/lib/AccountsService/users/jobrk && \
    test -L /etc/systemd/system/display-manager.service
USER jobrk
RUN /bin/zsh -lic 'bash ~/ansible/tests/smoke.sh'
ENV TERM=xterm-256color
CMD ["/bin/zsh"]

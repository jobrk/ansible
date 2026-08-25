# A machine an administrator has provisioned (compilers, git, pipx) where the
# user has no sudo at all — sudo is not even installed. Exercises the
# user-space fallbacks: release binaries into ~/.local/bin, Stow built from
# source, and the bash-to-zsh login handoff.
FROM fedora:44 AS base
WORKDIR /usr/local/bin
RUN dnf update -y && \
    dnf install -y cmake curl fontconfig-devel g++ gcc git make perl pipx \
      pkg-config python3 tmux unzip xz zsh && \
    dnf clean all

FROM base AS jobrk
RUN groupadd -g 1000 jobrk
RUN adduser -u 1000 -g 1000 jobrk
USER jobrk
WORKDIR /home/jobrk

FROM jobrk
RUN pipx install --include-deps ansible
COPY --chown=jobrk . ./ansible
RUN ./.local/bin/ansible-playbook -i ./ansible/inventory.ini ./ansible/main.yml --tags all,handoff --skip-tags become,ui
RUN ./.local/bin/ansible-playbook -i ./ansible/inventory.ini ./ansible/main.yml --tags all,handoff --skip-tags become,ui | tee /tmp/second-run.log && \
    grep -E 'changed=0.*failed=0' /tmp/second-run.log
RUN export PATH="$HOME/.local/bin:$PATH" && \
    for command in bat delta direnv fd fzf jq pipx rg stow; do \
      command -v "$command" > /dev/null || { echo "missing: $command"; exit 1; }; \
    done && \
    fzf --version && rg --version | head -1 && stow --version | head -1
RUN test -x ~/.local/bin/stow && test -x ~/.local/bin/fzf
RUN test -L ~/.zshrc && test -L ~/.config/nvim
RUN grep -q 'exec zsh' ~/.bash_profile
ENV TERM=xterm-256color
CMD ["/bin/zsh"]

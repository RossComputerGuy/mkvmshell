pkgs: prev: with pkgs;
let
  qemu-common = import "${pkgs.path}/nixos/lib/qemu-common.nix" {
    inherit pkgs;
    inherit (pkgs) lib;
  };
in
{
  mkVMShell = drv: mkShell (rec {
    name = drv.name or "vm-shell";

    QEMU_OPTS = [
      "-m 512"
    ] ++ lib.optional (drv ? QEMU_OPTS) drv.QEMU_OPTS;

    origBuilder = writeShellScript ("${name}-init") ''
      if [[ ! -n "$dontBindHome" ]]; then
        export PATH=${util-linux}/bin:${coreutils}/bin

        mkdir -p "$HOME"
        mount -t 9p home "$HOME" -o trans=virtio,version=9p2000.L,msize=131072,mode=ro
      fi

      if [[ ! -n "$dontBindProfiles" ]]; then
        export PATH=${util-linux}/bin:${coreutils}/bin

        mkdir -p /etc/profiles
        mount -t 9p etc-profiles /etc/profiles -o trans=virtio,version=9p2000.L,msize=131072,mode=ro

        mkdir -p /etc/static/profiles
        mount -t 9p etc-static-profiles /etc/static/profiles -o trans=virtio,version=9p2000.L,msize=131072,mode=ro
      fi

      if [[ ! -n "$dontBindNixOS" ]]; then
        export PATH=${util-linux}/bin:${coreutils}/bin

        mkdir -p /run/current-system
        mount -t 9p nixos-system /run/current-system -o trans=virtio,version=9p2000.L,msize=131072,mode=ro
      fi

      source /tmp/xchg/saved-env
      echo "$HOSTNAME" >/proc/sys/kernel/hostname

      if [[ -n "$dontSetUser" ]]; then
        export USER_UID=$(id -u)
        export USER_GID=$(id -g)
      else
        echo "$USER:x:$USER_UID:$USER_GID::$HOME:$SHELL" >> /etc/passwd

        chown "$USER_UID:$USER_GID" /dev/${qemu-common.qemuSerialDevice}
      fi

      exec ${busybox}/bin/setuidgid $USER_UID:$USER_GID \
        ${writeShellScript "${name}-shell" ''
          source /tmp/xchg/saved-env

          export name=${name}
          export shellHook=${drv.shellHook or ""}

          export OLD_PWD=$PWD
          export OLD_PATH=$PATH
          unset QEMU_OPTS

          cd $OLD_PWD
          unset OLD_PWD

          exec ${busybox}/bin/setsid ${bashInteractive}/bin/bash --init-file ${writeShellScript "${name}-shinit" ''
            source ${stdenv}/setup
            export PATH=$PATH:$OLD_PATH
            unset OLD_PATH

            if [[ -e $HOME/.bashrc ]]; then
              source $HOME/.bashrc
            fi
          ''} < /dev/${qemu-common.qemuSerialDevice} &> /dev/${qemu-common.qemuSerialDevice}
        ''}
    '';

    shellHook = ''
      if [[ ! -e /etc/profiles ]]; then
        export dontBindProfiles=1
      fi

      if [[ ! -e /run/current-system ]]; then
        export dontBindNixOS=1
      fi

      export HOSTNAME=$(hostname)

      if [[ ! -n "$dontSetUser" ]]; then
        export USER_UID=$(id -u)
        export USER_GID=$(id -g)
      fi

      mkdir -p $TMPDIR/xchg
      export > $TMPDIR/xchg/saved-env
      echo "declare -x PS1=\"$PS1\"" >> $TMPDIR/xchg/saved-env

      if [[ ! -n "$dontBindHome" ]]; then
        export QEMU_OPTS="$QEMU_OPTS -virtfs local,path=$HOME,security_model=none,mount_tag=home,readonly=on"
      fi

      if [[ ! -n "$dontBindProfiles" ]]; then
        export QEMU_OPTS="$QEMU_OPTS -virtfs local,path=/etc/profiles,security_model=none,mount_tag=etc-profiles,readonly=on"
        export QEMU_OPTS="$QEMU_OPTS -virtfs local,path=/etc/static/profiles,security_model=none,mount_tag=etc-static-profiles,readonly=on"
      fi

      if [[ ! -n "$dontBindNixOS" ]]; then
        export QEMU_OPTS="$QEMU_OPTS -virtfs local,path=/run/current-system,security_model=none,mount_tag=nixos-system,readonly=on"
      fi

      ${pkgs.vmTools.qemuCommandLinux}

      if ! test -e $TMPDIR/xchg/in-vm-exit; then
        echo "Virtual machine didn't produce an exit code."
        exit 1
      fi

      exitCode=$(cat $TMPDIR/xchg/in-vm-exit)
      exit "$exitCode"
    '';
  } // builtins.removeAttrs drv [ "name" "shellHook" "QEMU_OPTS" "origBuilder" ]);
}

pkgs: prev: with pkgs;
let
  qemu-common = import "${pkgs.path}/nixos/lib/qemu-common.nix" {
    inherit pkgs;
    inherit (pkgs) lib;
  };
in
{
  mkNixOSShell = drv: mkShell (rec {
    name = drv.name or "nixos-shell";

    QEMU_OPTS = [
      "-m 512"
    ] ++ lib.optional (drv ? QEMU_OPTS) drv.QEMU_OPTS;

    origBuilder = writeShellScript ("${name}-shell") ''
      if [[ ! -n "$dontBindHome" ]]; then
        export PATH=${util-linux}/bin:${coreutils}/bin

        mkdir -p "$HOME"
        mount -t 9p home "$HOME" -o trans=virtio,version=9p2000.L,msize=131072,mode=ro
      fi

      source /tmp/xchg/saved-env

      export name=${name}
      export shellHook=${drv.shellHook or ""}

      export OLD_PWD=$PWD
      unset QEMU_OPTS

      cd $OLD_PWD
      unset OLD_PWD

      source ${stdenv}/setup
      exec ${busybox}/bin/setsid ${bashInteractive}/bin/bash < /dev/${qemu-common.qemuSerialDevice} &> /dev/${qemu-common.qemuSerialDevice}
    '';

    shellHook = ''
      mkdir -p $TMPDIR/xchg
      export > $TMPDIR/xchg/saved-env
      echo "declare -x \"PS1=$PS1\"" >> $TMPDIR/xchg/saved-env

      if [[ ! -n "$dontBindHome" ]]; then
        export QEMU_OPTS="$QEMU_OPTS -virtfs local,path=$HOME,security_model=none,mount_tag=home,readonly=on"
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

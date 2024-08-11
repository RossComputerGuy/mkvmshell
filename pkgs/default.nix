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
        mount -t 9p home "$HOME" -o trans=virtio,version=9p2000.L,msize=131072
      fi

      export shellHook=${drv.shellHook or ""}

      source ${stdenv}/setup
      exec ${busybox}/bin/setsid ${bashInteractive}/bin/bash < /dev/${qemu-common.qemuSerialDevice} &> /dev/${qemu-common.qemuSerialDevice}
    '';

    shellHook = ''
      mkdir -p $TMPDIR/xchg
      export > $TMPDIR/xchg/saved-env

      if [[ ! -n "$dontBindHome" ]]; then
        export QEMU_OPTS="$QEMU_OPTS -virtfs local,path=$HOME,security_model=none,mount_tag=home"
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

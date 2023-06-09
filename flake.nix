{
  description = ''
    Own Smart Home decentralized wired project based on stm32 controllers
  '';
  inputs = {
    nixpkgs.url = "nixpkgs";
    stm32.url = github:ein-shved/nix-stm32;
    stm32.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = { self, stm32, nixpkgs } :
  let
    name = "WiredHome";
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
    findTty = pkgs.writeShellScriptBin "findTty" ''
      set -e
      function getoneof() {
        files="$(eval echo "$*")"
        nfiles="$(echo "$files" | wc -w)"
        if [ x"$nfiles" == x"1" ] && [ -e "$files" ]; then
          echo "$files"
          exit 0
        else
          echo "Found several files for operation: $*" >&2
        fi
        exit 1
      }
      tty="$1";
      if [ -z "$tty" ]; then
        if ! tty=$(getoneof '/dev/ttyUSB?'); then
          if ! tty=$(getoneof '/dev/ttyACM?'); then
            echo "No suitable tty device found. Please specify one" >&2;
            exit 1;
          fi
        fi
      fi
      echo "$tty"
    '';
    stm32stty = pkgs.writeShellScriptBin "stm32stty" ''
      set -e
      tty="$(${findTty}/bin/findTty "$@")"
      ${pkgs.coreutils}/bin/stty -F "$tty" 115200 -icrnl
    '';
    stm32catty = pkgs.writeShellScriptBin "stm32catty" ''
      set -e
      tty="$(${findTty}/bin/findTty "$@")"
      ${stm32stty}/bin/stm32stty "$tty" && exec cat "$tty"
    '';
    cantest =
    let
      cantest = pkgs.runCommandCC "cantest" {
          src = ./Host/cantest.c;
        } ''
          gcc -o cantest $src
          install -D cantest $out/bin/cantest
        '';
    in pkgs.writeShellScriptBin "cantest" ''
      set -e
      canable="''${1-$(find /dev/serial/by-id/ -iname '*canable*' -print -quit)}"
      canable="$(readlink -f "$canable")"
      iface="''${2-slcan0}"

      if ! ip l show "$iface" 2>/dev/null | grep '\<UP\>' -q; then
        sudo ${pkgs.can-utils}/bin/slcand -o -s6 "$canable" "$iface"
        sudo ip l set "$iface" up
      fi

      exec ${cantest}/bin/cantest $iface
    '';

    firmware = stm32.mkFirmware {
      inherit name;
      mcu = stm32.mcus.stm32f103;
      src = ./.;
    };
  in firmware // {
    inherit stm32catty stm32stty;
    scripts = pkgs.symlinkJoin {
      name = "${name}-scripts";
      paths = [
        firmware.scripts
        stm32catty
        stm32stty
        cantest
      ];
    };
  };
}

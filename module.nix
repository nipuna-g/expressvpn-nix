{ config, lib, pkgs, ... }:

let
  cfg = config.services.expressvpn-qt;
  expressvpn = pkgs.expressvpn-qt;
in {
  options.services.expressvpn-qt = {
    enable = lib.mkEnableOption "ExpressVPN daemon (Qt GUI)";
  };

  config = lib.mkIf cfg.enable {
    # Make pkgs.expressvpn-qt resolve even if the consumer didn't apply the
    # overlay themselves — importing this module is enough.
    nixpkgs.overlays = [ (import ./overlay.nix) ];

    # The daemon derives its install dir from argv[0] (the /opt path systemd
    # passes), so it reads/writes /opt/expressvpn/{var,etc}. It also authorizes
    # connecting clients by reading their /proc/<pid>/exe and comparing it to
    # /opt/expressvpn/bin/expressvpn-client.
    #
    # bin/ must therefore be REAL files at that path: if it were a symlink into
    # the Nix store, the kernel would canonicalize the client's /proc/self/exe
    # to the /nix/store path, the comparison would fail, and the daemon would
    # reject the GUI ("Unauthorized client connection") — leaving it stuck on
    # the loading screen. lib/plugins/qml/share are read-only, so symlinks are
    # fine for those. var/ and etc/ are writable state.
    # The daemon shells out to /bin/bash to run iptables rules.
    # NixOS only provides /bin/sh by default.
    system.activationScripts.expressvpn = {
      text = ''
        ln -sfn ${pkgs.bash}/bin/bash /bin/bash
        ln -sfn ${pkgs.iproute2}/bin/ip /usr/bin/ip
        ln -sfn ${pkgs.systemd}/bin/systemctl /usr/bin/systemctl
        ln -sfn ${pkgs.systemd}/bin/resolvectl /usr/bin/resolvectl

        install -dm755 /opt/expressvpn
        ln -sfn ${expressvpn}/lib     /opt/expressvpn/lib
        ln -sfn ${expressvpn}/plugins /opt/expressvpn/plugins
        ln -sfn ${expressvpn}/qml     /opt/expressvpn/qml
        ln -sfn ${expressvpn}/share   /opt/expressvpn/share

        if [ "$(cat /opt/expressvpn/.store-path 2>/dev/null)" != "${expressvpn}" ]; then
          rm -rf /opt/expressvpn/bin
          cp -r ${expressvpn}/libexec /opt/expressvpn/bin
          chmod -R a+rX /opt/expressvpn/bin
          printf '%s' "${expressvpn}" > /opt/expressvpn/.store-path
        fi

        install -dm755 /opt/expressvpn/var
        install -dm755 /opt/expressvpn/etc
      '';
      deps = [];
    };

    environment.systemPackages = [ expressvpn ];

    users.groups.expressvpn = {};
    users.groups.expressvpnhnsd = {};

    # Ensure tun and wireguard kernel modules are available for VPN protocols
    boot.kernelModules = [ "tun" "wireguard" ];

    systemd.services.expressvpn = {
      description = "ExpressVPN daemon";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      # ExecStart is a fixed /opt path, so the unit text doesn't change when the
      # package version bumps -- nixos-rebuild would leave the daemon stopped
      # while the activation script swaps the binaries underneath it. Tie the
      # unit to the store path so a version bump actually restarts the daemon.
      restartTriggers = [ "${expressvpn}" ];
      # The daemon shells out to these tools by name (resolved via PATH) to set
      # up routing, the kill switch and to load the wireguard module.
      path = with pkgs; [ iptables iproute2 kmod procps gawk ];
      serviceConfig = {
        ExecStart = "/opt/expressvpn/bin/expressvpn-daemon";
        Restart = "on-failure";
        # Daemon manages network interfaces and routing — must run as root
        User = "root";
      };
    };
  };
}

# expressvpn-nix

Nix flake packaging the ExpressVPN 14.x Linux client (Qt GUI + CLI) for NixOS.

## Usage

Add the flake as an input and enable the module:

```nix
{
  inputs.expressvpn-nix.url = "github:nipuna/expressvpn-nix";

  # In your NixOS configuration:
  imports = [ expressvpn-nix.nixosModules.default ];
  services.expressvpn-qt.enable = true;
}
```

Then activate your account and connect:

```sh
expressvpnctl activate
expressvpnctl connect
```

Or launch the **ExpressVPN** GUI from your application menu.

## What's included

- `packages.default` (`expressvpn-qt`) — the patched ExpressVPN package.
- `nixosModules.default` — runs the daemon as a systemd service and wires up the
  `/opt/expressvpn` paths the daemon and GUI expect.
- `overlays.default` — exposes `pkgs.expressvpn-qt`.

## Updating

Bump `version` and `hash` in [`package.nix`](package.nix):

```sh
nix-prefetch-url https://www.expressvpn.works/clients/linux/expressvpn-linux-universal-<version>_release.run
```

Current version: **14.2.0.13656**.

## License

The packaging is provided as-is; the ExpressVPN client itself is unfree
proprietary software subject to ExpressVPN's own license.

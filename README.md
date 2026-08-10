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

A weekly GitHub Actions workflow (`.github/workflows/update.yml`) checks
ExpressVPN's installers API for a newer Linux build and opens a PR bumping
`version` and `hash` in [`package.nix`](package.nix) once it verifies the new
version builds.

To update by hand, run the same script the workflow uses:

```sh
./update.sh   # needs curl, jq, and nix on PATH
```

Current version: **14.2.0.13656**.

## CI

`.github/workflows/build.yml` builds `expressvpn-qt` and runs `nix flake check`
on every push and pull request.

## License

The packaging is provided as-is; the ExpressVPN client itself is unfree
proprietary software subject to ExpressVPN's own license.

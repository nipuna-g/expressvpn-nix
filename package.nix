{ lib, stdenv, fetchurl, autoPatchelfHook, coreutils,
  glib, zlib, brotli,
  libxkbcommon, libglvnd, fontconfig, freetype, dbus,
  libxau, libxdmcp, libSM, libICE, wayland, libcap_ng,
  gnugrep, gawk, iproute2, findutils }:

stdenv.mkDerivation rec {
  pname = "expressvpn";
  version = "14.2.0.13656";

  src = fetchurl {
    url = "https://www.expressvpn.works/clients/linux/expressvpn-linux-universal-${version}_release.run";
    hash = "sha256-nXcO3GVIoXmU/RVxTFAwqPV2dnG3ayEXqIT31I2T8ss=";
  };

  nativeBuildInputs = [ autoPatchelfHook ];

  # System libs not bundled in the .run package
  buildInputs = [
    stdenv.cc.cc.lib  # libstdc++.so.6, libatomic.so.1
    glib              # libglib-2.0.so.0, libgthread-2.0.so.0
    zlib              # libz.so.1
    brotli            # libbrotlidec.so.1
    libxkbcommon      # libxkbcommon.so.0 (expressvpn-client GUI)
    libglvnd          # libGLX.so.0, libOpenGL.so.0, libEGL.so.1
    fontconfig        # libfontconfig.so.1
    freetype          # libfreetype.so.6
    dbus              # libdbus-1.so.3
    libxau            # libXau.so.6
    libxdmcp          # libXdmcp.so.6
    libSM             # libSM.so.6 (bundled libqxcb.so platform plugin)
    libICE            # libICE.so.6 (bundled libqxcb.so platform plugin)
    wayland           # libwayland-client.so.0, libwayland-cursor.so.0
    libcap_ng         # libcap_ng.so.0 (expressvpn-openvpn)
  ];

  unpackPhase = ''
    sh $src --noexec --target src
  '';

  installPhase = ''
    runHook preInstall

    local base=src/x64/expressvpnfiles

    mkdir -p $out/bin $out/libexec $out/lib $out/plugins $out/qml $out/share

    # Real ELF binaries go to libexec — the activation script copies these to
    # /opt/expressvpn/bin. They must not live in $out/bin or the exec wrapper
    # below would copy itself there and call itself recursively.
    cp -r $base/bin/. $out/libexec/

    # Shell wrapper for the CLI: exec into the /opt copy so /proc/self/exe
    # becomes /opt/expressvpn/bin/expressvpnctl (what the daemon auth checks).
    cat > $out/bin/expressvpnctl << 'EOF'
#!/bin/sh
exec /opt/expressvpn/bin/expressvpnctl "$@"
EOF
    chmod +x $out/bin/expressvpnctl
    cp -r $base/lib/. $out/lib/
    cp -r $base/plugins/. $out/plugins/
    cp -r $base/qml/. $out/qml/
    cp -r $base/share/. $out/share/

    # Desktop entry and icon for the GUI client.
    #
    # We must NOT wrap expressvpn-client: the daemon authorizes connecting
    # clients by reading /proc/<pid>/exe and checking the binary name
    # (LocalSocketIPCServer::isClientAllowedToConnect). A makeWrapper shim
    # renames the real binary to .expressvpn-client-wrapped, so the daemon
    # sees the wrong name, logs "Unauthorized client connection, will ignore."
    # and closes the socket — leaving the GUI stuck on its loading screen.
    #
    # Instead we clear the conflicting Qt env vars in the launcher's Exec line
    # via `env -u`. The launcher then execs the real, correctly-named binary,
    # so /proc/self/exe stays /nix/store/.../bin/expressvpn-client.
    #
    # Why clear them: the KDE session points QT_PLUGIN_PATH at system Qt 6.11
    # plugins, which crash when loaded against the bundled Qt 6.5.9. Clearing
    # it forces Qt to use the bundled plugins from qt.conf.
    install -D src/x64/installfiles/app-icon.png \
      $out/share/icons/hicolor/256x256/apps/expressvpn.png

    install -Dm644 src/x64/installfiles/expressvpn.desktop \
      $out/share/applications/expressvpn.desktop
    substituteInPlace $out/share/applications/expressvpn.desktop \
      --replace-fail \
        "env XDG_SESSION_TYPE=X11 /opt/expressvpn/bin/expressvpn-client" \
        "${coreutils}/bin/env -u QT_PLUGIN_PATH -u QT_QPA_PLATFORMTHEME -u KDE_FULL_SESSION XDG_SESSION_TYPE=X11 /opt/expressvpn/bin/expressvpn-client"

    # Lightway's he_execute runs openvpn-updown.sh without the --path arg
    # that OpenVPN/WireGuard pass, leaving the script with no PATH. Inject
    # one right after the shebang so grep/tr/realpath/ip/awk are always found.
    sed -i "2i export PATH=${coreutils}/bin:${gnugrep}/bin:${gawk}/bin:${iproute2}/bin:${findutils}/bin:\$PATH" \
      $out/libexec/openvpn-updown.sh

    runHook postInstall
  '';

  postInstall = ''
    # Let autoPatchelfHook find bundled libs in $out/lib and plugin .so files
    addAutoPatchelfSearchPath $out/libexec
    addAutoPatchelfSearchPath $out/lib
    addAutoPatchelfSearchPath $out/plugins
  '';

  # The .run bundles its own Qt6/ssl/icu but omits libraries for optional QML
  # modules (virtual keyboard, lottie, state machine, etc.). Those plugins are
  # only loaded at runtime for specific GUI features; the daemon and CLI don't
  # need them. Setting true avoids having to enumerate every missing lib.
  autoPatchelfIgnoreMissingDeps = true;

  meta = {
    description = "ExpressVPN client for Linux (Qt GUI)";
    homepage = "https://www.expressvpn.com";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "expressvpnctl";
  };
}

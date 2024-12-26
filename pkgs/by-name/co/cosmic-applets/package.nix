{
  dbus,
  fetchFromGitHub,
  glib,
  just,
  lib,
  libcosmicAppHook,
  libinput,
  nix-update-script,
  pkg-config,
  pulseaudio,
  rustPlatform,
  stdenv,
  udev,
  util-linux,
  wayland,
  xkeyboard_config,
}:

rustPlatform.buildRustPackage {
  pname = "cosmic-applets";
  version = "epoch-1.0.0-alpha.1";

  src = fetchFromGitHub {
    owner = "pop-os";
    repo = "cosmic-applets";
    rev = "refs/tags/epoch-1.0.0-alpha.1";
    hash = "sha256-4KaMG7sKaiJDIlP101/6YDHDwKRqJXHdqotNZlPhv8Q=";
  };

  useFetchCargoVendor = true;
  cargoHash = "sha256-f5OV//qzWQqIvq8BNtd2H1dWl7aqR0WJwmdimL4wcKQ=";

  nativeBuildInputs = [
    just
    libcosmicAppHook
    pkg-config
    util-linux
  ];

  buildInputs = [
    dbus
    glib
    libinput
    pulseaudio
    udev
    wayland
  ];

  dontUseJustBuild = true;
  dontUseJustCheck = true;

  justFlags = [
    "--set"
    "prefix"
    (placeholder "out")
    "--set"
    "target"
    "${stdenv.hostPlatform.rust.cargoShortTarget}/release"
  ];

  postInstall = ''
    libcosmicAppWrapperArgs+=(--set-default X11_BASE_RULES_XML ${xkeyboard_config}/share/X11/xkb/rules/base.xml)
    libcosmicAppWrapperArgs+=(--set-default X11_EXTRA_RULES_XML ${xkeyboard_config}/share/X11/xkb/rules/base.extras.xml)
  '';

  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--version-regex"
      "epoch-(.*)"
    ];
  };

  meta = with lib; {
    homepage = "https://github.com/pop-os/cosmic-applets";
    description = "Applets for the COSMIC Desktop Environment";
    license = licenses.gpl3Only;
    maintainers = with maintainers; [
      nyabinary
      qyliss
      thefossguy
    ];
    platforms = platforms.linux;
  };
}

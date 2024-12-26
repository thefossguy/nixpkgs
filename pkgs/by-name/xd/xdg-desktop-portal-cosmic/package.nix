{
  fetchFromGitHub,
  gst_all_1,
  lib,
  libcosmicAppHook,
  mesa,
  nix-update-script,
  pipewire,
  pkg-config,
  rustPlatform,
  wayland,
}:

rustPlatform.buildRustPackage rec {
  pname = "xdg-desktop-portal-cosmic";
  version = "epoch-1.0.0-alpha.4";

  src = fetchFromGitHub {
    owner = "pop-os";
    repo = "xdg-desktop-portal-cosmic";
    rev = "refs/tags/epoch-1.0.0-alpha.4";
    hash = "sha256-4FdgavjxRKbU5/WBw9lcpWYLxCH6IJr7LaGkEXYUGbw=";
  };

  useFetchCargoVendor = true;
  cargoHash = "sha256-FgfUkU9sv5mq4+pou2myQn6+DkLzPacjUhQ4pL8hntM=";

  separateDebugInfo = true;

  nativeBuildInputs = [
    libcosmicAppHook
    pkg-config
    rustPlatform.bindgenHook
  ];

  buildInputs = [
    mesa
    pipewire
    wayland
  ];
  checkInputs = [ gst_all_1.gstreamer ];

  env.VERGEN_GIT_SHA = src.rev;

  postInstall = ''
    mkdir -p $out/share/{dbus-1/services,icons,xdg-desktop-portal/portals}
    cp -r data/icons $out/share/icons/hicolor
    cp data/*.service $out/share/dbus-1/services/
    cp data/cosmic-portals.conf $out/share/xdg-desktop-portal/
    cp data/cosmic.portal $out/share/xdg-desktop-portal/portals/
  '';

  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--version-regex"
      "epoch-(.*)"
    ];
  };

  meta = with lib; {
    homepage = "https://github.com/pop-os/xdg-desktop-portal-cosmic";
    description = "XDG Desktop Portal for the COSMIC Desktop Environment";
    license = licenses.gpl3Only;
    maintainers = with maintainers; [
      nyabinary
      thefossguy
    ];
    mainProgram = "xdg-desktop-portal-cosmic";
    platforms = platforms.linux;
  };
}

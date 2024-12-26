{
  fetchFromGitHub,
  lib,
  libcosmicAppHook,
  libinput,
  mesa,
  nix-update-script,
  pkg-config,
  rustPlatform,
  udev,
  wayland,
}:

rustPlatform.buildRustPackage {
  pname = "cosmic-workspaces-epoch";
  version = "epoch-1.0.0-alpha.2";

  src = fetchFromGitHub {
    owner = "pop-os";
    repo = "cosmic-workspaces-epoch";
    rev = "refs/tags/epoch-1.0.0-alpha.2";
    hash = "sha256-z3xQ6Vgqkm8hYLo2550NbFRkTMRQ0F9zn85iobnykH5=";
  };

  useFetchCargoVendor = true;
  cargoHash = "sha256-QRBgFTXPWQ0RCSfCA2WpBs+vKTFD7Xfz60cIDtbYb5Y=";

  nativeBuildInputs = [
    libcosmicAppHook
    pkg-config
  ];

  buildInputs = [
    libinput
    mesa
    udev
    wayland
  ];

  postInstall = ''
    mkdir -p $out/share/{applications,icons/hicolor/scalable/apps}
    cp data/*.desktop $out/share/applications/
    cp data/*.svg $out/share/icons/hicolor/scalable/apps/
  '';

  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--version-regex"
      "epoch-(.*)"
    ];
  };

  meta = with lib; {
    homepage = "https://github.com/pop-os/cosmic-workspaces-epoch";
    description = "Workspaces Epoch for the COSMIC Desktop Environment";
    mainProgram = "cosmic-workspaces";
    license = licenses.gpl3Only;
    maintainers = with maintainers; [
      nyabinary
      thefossguy
    ];
    platforms = platforms.linux;
  };
}

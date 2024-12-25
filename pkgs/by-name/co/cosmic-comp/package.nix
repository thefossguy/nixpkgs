{
  fetchFromGitHub,
  lib,
  libcosmicAppHook,
  libinput,
  mesa,
  nix-update-script,
  pixman,
  pkg-config,
  rustPlatform,
  seatd,
  stdenv,
  systemd,
  udev,
  useSystemd ? lib.meta.availableOn stdenv.hostPlatform systemd,
  useXWayland ? true,
  wayland,
  xwayland,
}:

rustPlatform.buildRustPackage {
  pname = "cosmic-comp";
  version = "epoch-1.0.0-alpha.2";

  src = fetchFromGitHub {
    owner = "pop-os";
    repo = "cosmic-comp";
    rev = "refs/tags/epoch-1.0.0-alpha.2";
    hash = "sha256-IbGMp+4nRg4v5yRvp3ujGx7+nJ6wJmly6dZBXbQAnr8=";
  };

  useFetchCargoVendor = true;
  cargoHash = "sha256-4ahdQ0lQbG+lifGlsJE0yci4j8pR7tYVsMww9LyYyAA=";

  separateDebugInfo = true;

  nativeBuildInputs = [
    libcosmicAppHook
    pkg-config
  ];

  buildInputs = [
    libinput
    mesa
    pixman
    seatd
    udev
    wayland
  ] ++ lib.optionals useSystemd [ systemd ];

  # only default feature is systemd
  buildNoDefaultFeatures = !useSystemd;

  makeFlags = [
    "prefix=${placeholder "out"}"
    "CARGO_TARGET_DIR=target/${stdenv.hostPlatform.rust.cargoShortTarget}"
  ];

  dontCargoInstall = true;

  preFixup = lib.optionalString useXWayland ''
    libcosmicAppWrapperArgs+=(--prefix PATH : ${lib.makeBinPath [ xwayland ]})
  '';

  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--version-regex"
      "epoch-(.*)"
    ];
  };

  meta = with lib; {
    homepage = "https://github.com/pop-os/cosmic-comp";
    description = "Compositor for the COSMIC Desktop Environment";
    mainProgram = "cosmic-comp";
    license = licenses.gpl3Only;
    maintainers = with maintainers; [
      nyabinary
      qyliss
      thefossguy
    ];
    platforms = platforms.linux;
  };
}

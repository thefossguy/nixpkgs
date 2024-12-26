{
  cmake,
  cosmic-randr,
  expat,
  fetchFromGitHub,
  fontconfig,
  freetype,
  just,
  lib,
  libcosmicAppHook,
  libinput,
  nix-update-script,
  pipewire,
  pkg-config,
  pulseaudio,
  rustPlatform,
  stdenv,
  udev,
  util-linux,
  wayland,
  xkeyboard_config,
}:

let
  libcosmicAppHook' = (libcosmicAppHook.__spliced.buildHost or libcosmicAppHook).override {
    includeSettings = false;
  };
in

rustPlatform.buildRustPackage {
  pname = "cosmic-settings";
  version = "epoch-1.0.0-alpha.1";

  src = fetchFromGitHub {
    owner = "pop-os";
    repo = "cosmic-settings";
    rev = "refs/tags/epoch-1.0.0-alpha.1";
    hash = "sha256-gTzZvhj7oBuL23dtedqfxUCT413eMoDc0rlNeqCeZ6E=";
  };

  useFetchCargoVendor = true;
  cargoHash = "sha256-zMHJc6ytbOoi9E47Zsg6zhbQKObsaOtVHuPnLAu36I4=";

  nativeBuildInputs = [
    cmake
    just
    libcosmicAppHook'
    pkg-config
    rustPlatform.bindgenHook
    util-linux
  ];

  buildInputs = [
    expat
    fontconfig
    freetype
    libinput
    pipewire
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
    "bin-src"
    "target/${stdenv.hostPlatform.rust.cargoShortTarget}/release/cosmic-settings"
  ];

  postInstall = ''
    libcosmicAppWrapperArgs+=(--prefix PATH : ${lib.makeBinPath [ cosmic-randr ]})
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
    homepage = "https://github.com/pop-os/cosmic-settings";
    description = "Settings for the COSMIC Desktop Environment";
    license = licenses.gpl3Only;
    maintainers = with maintainers; [
      nyabinary
      thefossguy
    ];
    platforms = platforms.linux;
    mainProgram = "cosmic-settings";
  };
}

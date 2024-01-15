{
  lib,
  fetchFromGitHub,
  bash,
  rustPlatform,
  just,
  dbus,
  rust,
  stdenv,
  xdg-desktop-portal-cosmic,
}:
rustPlatform.buildRustPackage rec {
  pname = "cosmic-session";
  version = "0-unstable-2023-01-14";

  src = fetchFromGitHub {
    owner = "pop-os";
    repo = pname;
    rev = "d16404f4982c723f087aacefc30f699c89ee2f58";
    sha256 = "sha256-B+6JZLpq7ohRndVrxW1ZWhcYKv0HxB+sWleajDOzpCw=";
  };

  cargoLock = {
    lockFile = ./Cargo.lock;
    outputHashes = {
      "cosmic-notifications-util-0.1.0" = "sha256-GmTT7SFBqReBMe4GcNSym1YhsKtFQ/0hrDcwUqXkaBw=";
      "launch-pad-0.1.0" = "sha256-tnbSJ/GP9GTnLnikJmvb9XrJSgnUnWjadABHF43L1zc=";
    };
  };

  postPatch = ''
    substituteInPlace Justfile \
        --replace '#!/usr/bin/env' "#!$(command -v env)" \
        --replace 'target/release/cosmic-session' "target/${
          rust.lib.toRustTargetSpecShort stdenv.hostPlatform
        }/release/cosmic-session"
    substituteInPlace data/start-cosmic \
        --replace '#!/bin/bash' "#!${lib.getBin bash}/bin/bash" \
        --replace '/usr/bin/cosmic-session' "$out/bin/cosmic-session" \
        --replace '/usr/bin/dbus-run-session' "${
          lib.getBin dbus
        }/bin/dbus-run-session"
    substituteInPlace data/cosmic.desktop --replace '/usr/bin/start-cosmic' "$out/bin/start-cosmic"
  '';

  nativeBuildInputs = [ just ];

  dontUseJustBuild = true;

  justFlags = [
    "--set"
    "prefix"
    (placeholder "out")
    "--set"
    "xdp_cosmic"
    xdg-desktop-portal-cosmic
  ];

  passthru.providedSessions = [ "cosmic" ];

  meta = with lib; {
    homepage = "https://github.com/pop-os/cosmic-session";
    description = "Session manager for the COSMIC desktop environment";
    license = licenses.gpl3Only;
    mainProgram = "cosmic-session";
    maintainers = with maintainers; [
      a-kenji
      nyanbinary
    ];
    platforms = platforms.linux;
  };
}

{ fetchFromGitHub
, lib
, rustPlatform
}:

rustPlatform.buildRustPackage rec {
  pname = "nixos-needsreboot";
  version = "0.1.5";

  src = fetchFromGitHub {
    owner = "thefossguy";
    repo = "nixos-needsreboot";
    rev = "${version}";
    hash = "sha256-rVH89tir0DIBRaU1jbDEUytaFFJTVSw/Tmcdr1KOJ5w=";
  };

  cargoHash = "sha256-Q6eSB4jS+gy/zxSUy2x3MeWYrryvbo97UI8+5GSrvE0=";

  meta = with lib; {
    description = "Determine if you need to reboot your NixOS machine";
    homepage = "https://github.com/thefossguy/nixos-needsreboot";
    license = licenses.gpl2Only;
    maintainers = with maintainers; [ thefossguy ];
    mainProgram = "nixos-needsreboot";
  };
}

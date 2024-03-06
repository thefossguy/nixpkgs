{ stdenv
, lib
, fetchFromGitHub
}:

stdenv.mkDerivation rec {
  pname = "rkbin";
  version = "2023.07.26-${gitShort}";

  gitCommit = "b4558da0860ca48bf1a571dd33ccba580b9abe23";
  gitShort  = "b4558da";

  src = fetchFromGitHub {
    owner = "rockchip-linux";
    repo = "rkbin";
    rev = "${gitCommit}";
    hash = "sha256-KUZQaQ+IZ0OynawlYGW99QGAOmOrGt2CZidI3NTxFw8=";
  };

  installPhase = ''
    mkdir $out
    mv bin doc $out/
  '';

  dontConfigure = true;
  dontBuild = true;
  dontFixup = true;

  meta = with lib; {
    description = "Rockchip proprietary bootloader blobs";
    homepage = "https://github.com/rockchip-linux/rkbin";
    license = licenses.unfree;
    maintainers = with maintainers; [ thefossguy ];
    platforms = [ "aarch64-linux" ];
  };
}

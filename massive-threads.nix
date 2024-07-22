{ stdenv, pkgs, lib }:

with pkgs;

stdenv.mkDerivation {
  name = "massivethreads";
  src = fetchFromGitHub {
    owner = "massivethreads";
    repo = "massivethreads";
    rev = "v1.00";
    sha256 = "sha256-0CNXqc5jEsOw6H2QQj0e0Akl1z+sn8ooFwnb+YXrIzU=";
  };

  patches = [
    (fetchpatch {
      url = "https://github.com/massivethreads/massivethreads/commit/827587939ff2f57efe5936fd65b2e1349057b2d3.patch";
      sha256 = "sha256-9jleivJpV9eXmVZg5U962lAIrxLYWaugvQZ7XnTy0eY="; 
    })
  ];

  configurePhase = ''
    ./configure --prefix=$out
  '';

  installFlags = "PREFIX=${placeholder "out"}";

  meta = with lib; {
    description = "Light weight thread library";
    homepage = "https://github.com/massivethreads/massivethreads";
    platforms = platforms.linux;
  };
}

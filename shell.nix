{ pkgs ? import <nixpkgs> {} }:
pkgs.stdenv.mkDerivation {
  name = "hi";

  buildInputs = (with pkgs; [

  ]) ++ [(import ./daps.nix {})];
}

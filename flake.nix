{
  description = "learn.lorenzo.sh — a self-taught learning log, built with mdBook";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs =
    { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in
    {
      # The single source of truth for the mdBook toolchain. CI runs
      # `nix develop -c mdbook build` against this same lock, so the deployed
      # site is byte-identical to what `mdbook serve` shows locally.
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          mdbook
          mdbook-mermaid
        ];
      };
    };
}

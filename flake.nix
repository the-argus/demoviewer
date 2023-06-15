{
  description = "C++ Hello World";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    ...
  }: let
    supportedSystems = let
      inherit (flake-utils.lib) system;
    in [
      system.aarch64-linux
      system.x86_64-linux
    ];
  in
    flake-utils.lib.eachSystem supportedSystems (system: let
      pkgs = import nixpkgs {inherit system;};
    in {
      packages = {
        zig = pkgs.callPackage ./nix/zig.nix {
          llvmPackages = pkgs.llvmPackages_16;
        };
        default = self.packages.${system}.zig;
      };

      devShell =
        pkgs.mkShell.override
        {
          stdenv = pkgs.clangStdenv;
        }
        {
          packages =
            (with pkgs; [
              self.packages.${system}.zig
              llvmPackages_16.lldb

              lzlib

              libGL
            ])
            ++ (with pkgs.xorg; [
              libX11
              libXrandr
              libXinerama
              libXcursor
              libXi
            ]);
        };

      formatter = pkgs.alejandra;
    });
}

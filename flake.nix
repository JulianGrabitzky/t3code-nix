{
  description = "Nix flake for T3 Code stable and nightly desktop builds";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      versions = builtins.fromJSON (builtins.readFile ./versions.json);
      overlay = final: _prev: {
        t3code-stable = final.callPackage ./package.nix {
          release = versions.stable;
        };
        t3code-nightly = final.callPackage ./package.nix {
          release = versions.nightly;
        };
        t3code = final.t3code-stable;
      };
      mkApp = drv: {
        type = "app";
        program = "${drv}/bin/t3code";
        meta = drv.meta;
      };
    in
    flake-utils.lib.eachSystem [ "x86_64-linux" ]
      (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ overlay ];
          };
        in
        {
          packages = {
            default = pkgs.t3code-stable;
            t3code = pkgs.t3code-stable;
            t3code-stable = pkgs.t3code-stable;
            t3code-nightly = pkgs.t3code-nightly;
          };

          apps = {
            default = mkApp pkgs.t3code-stable;
            t3code = mkApp pkgs.t3code-stable;
            t3code-stable = mkApp pkgs.t3code-stable;
            t3code-nightly = mkApp pkgs.t3code-nightly;
          };

          checks = {
            stable = pkgs.t3code-stable;
            nightly = pkgs.t3code-nightly;
          };

          devShells.default = pkgs.mkShell {
            packages = with pkgs; [ jq nixpkgs-fmt ];
          };
        })
    // {
      overlays.default = overlay;
    };
}

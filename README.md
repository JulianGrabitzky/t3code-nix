# t3code-nix

Nix packaging for the [T3 Code](https://github.com/pingdotgg/t3code) desktop app.

## Packages

- `t3code` / `t3code-stable` — latest pinned stable release
- `t3code-nightly` — latest pinned nightly release

Run either channel:

```bash
nix run github:JulianGrabitzky/t3code-nix#t3code-stable
nix run github:JulianGrabitzky/t3code-nix#t3code-nightly
```

Use as a NixOS flake input:

```nix
inputs.t3code-nix = {
  url = "github:JulianGrabitzky/t3code-nix";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Then install one channel:

```nix
environment.systemPackages = [
  inputs.t3code-nix.packages.${pkgs.system}.t3code-nightly
];
```

Use `t3code-stable` instead to switch back to stable. Both packages install the normal T3 Code desktop launcher, so install only one channel at a time.

The update workflow checks upstream every six hours and opens a PR when stable or nightly changes.

# AGENTS.md

## Repository

This is a personal NixOS + Home Manager dotfiles repository.

## Important Context

- Active NixOS configurations are `vbox` and `minipc`.
- `main` exists under `hosts/main`, but is commented out in `flake.nix` until its hardware configuration is ready.
- Active Home Manager configuration is `myHome`.
- The primary user is `kaka`.
- Do not change `system.stateVersion` or `home.stateVersion` unless explicitly requested.
- Do not weaken SSH, Tailscale, or firewall settings without explicit confirmation.

## Validation

Prefer checking changes with:

```bash
nix eval .#nixosConfigurations --apply 'builtins.attrNames'
nix eval .#homeConfigurations --apply 'builtins.attrNames'
nix build .#nixosConfigurations.vbox.config.system.build.toplevel
nix build .#nixosConfigurations.minipc.config.system.build.toplevel
nix build .#homeConfigurations.myHome.activationPackage
```

## Editing Guidelines

- Follow the existing module layout under `hosts/common`, `hosts/<host>`, and `home`.
- Put shared NixOS settings in `hosts/common`.
- Put host-specific hardware, GPU, and desktop choices in `hosts/<host>`.
- Put user-level packages and dotfiles in `home`.
- Keep README focused on human-facing usage and installation notes.

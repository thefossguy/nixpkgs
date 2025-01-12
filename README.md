# README

This branch will be maintained to keep up with nixpkgs with the sole purpose
to maintain a simple, out-of-tree patch to enable ARM64 Linux kernel with the
pagesize of 16KB.

The author is doing this to improve Apple Silicon support in nixpkgs and
a 16KB pagesize is a hardware requirement. It also benefits owners of SBC
that can take advantage of this, like the A76 cores found in the
Raspberry Pi 5 and other RK3588-SoC based boards.

You can either use this branch as your nixpkgs (is a patched mirror of the
**`master`** branch) input or you can do the following and keep using the
upstream nixpkgs source.
```nix
# **ONLY MAINTAINED FOR `linux_latest` AND `linux_testing`**
kernelPackages = lib.mkForce (pkgs.linuxPackagesFor (pkgs.linux_latest.override {
  argsOverride = {
    structuredExtraConfig = ; {
      ARM64_16K_PAGES = lib.kernel.yes;
    };
  };
}));

```

If you are on a slow machine but would still like to participate in possible
bug hunting, please employ the following binary cache. I will try to keep it
up-to-date.

```nix
nix.settings = {
  extra-substituters = [ "https://thefossguy.cachix.org" ];
  extra-trusted-public-keys = [ "thefossguy.cachix.org-1:/gMdFQnu+BtfjSYsnxZbtNdA2s4EX3mvNFWkqovpN24=" ];
};
```

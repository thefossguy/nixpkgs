{
  system ? builtins.currentSystem,
  config ? { },
  pkgs ? import ../.. { inherit system config; },
}@args:

with pkgs.lib;

let
  patchedPkgs = pkgs.extend (
    final: prev: {
      kernelPackagesExtensions = prev.kernelPackagesExtensions ++ [
        (
          finalKernelPackages: _:
          let
            finalKernel = finalKernelPackages.kernel;
          in
          {
            hello-world = final.stdenv.mkDerivation {
              name = "hello-module";

              nativeBuildInputs = finalKernel.moduleBuildDependencies;
              makeFlags = finalKernel.commonMakeFlags ++ [
                # Variable refers to the local Makefile.
                "KDIR=${finalKernel.dev}/lib/modules/${finalKernel.modDirVersion}/build"
                # Variable of the Linux src tree's main Makefile.
                "INSTALL_MOD_PATH=$(out)"
              ];

              buildFlags = [ "modules" ];
              installTargets = [ "modules_install" ];

              src = ./hello-world-src;
            };
          }
        )
      ];
    }
  );

  testsForLinuxPackages =
    linuxPackages:
    (import ../make-test-python.nix (
      { pkgs, ... }:
      {
        name = "kernel-${linuxPackages.kernel.version}";
        meta = with pkgs.lib.maintainers; {
          maintainers = [
            atemu
            ma27
          ];
        };

        nodes.machine =
          { config, ... }:
          {
            # we could/would do something like below, but linuxPackages comes from outside
            # the machine closure, so an overlay doesn't apply to the kernelPackages.
            # nixpkgs.overlays = [
            #   (final: prev: {
            #     kernelPackagesExtensions = prev.kernelPackagesExtensions ++ [ helloWorldExtension ];
            #   })
            # ]

            boot.kernelPackages = linuxPackages;

            boot.extraModulePackages = [ config.boot.kernelPackages.hello-world ];

            boot.kernelModules = [ "hello" ];
          };

        testScript = ''
          assert "Linux" in machine.succeed("uname -s")
          assert "${linuxPackages.kernel.modDirVersion}" in machine.succeed("uname -a")

          assert "Hello world!" in machine.succeed("dmesg")
        '';
      }
    ) args);

  mk64kKernel =
    kernelPackage:
    patchedPkgs.linuxKernel.packagesFor (
      kernelPackage.override {
        structuredExtraConfig = {
          ARM64_64K_PAGES = kernel.yes;
        };
      }
    );

  kernels64k = attrsets.optionalAttrs (pkgs.stdenv.hostPlatform.system == "aarch64-linux") {
    linux_default_64k = mk64kKernel patchedPkgs.linux;
    linux_latest_64k = mk64kKernel patchedPkgs.linux_latest;
    linux_testing_64k = mk64kKernel patchedPkgs.linux_testing;
  };

  kernels =
    patchedPkgs.linuxKernel.vanillaPackages
    // {
      inherit (patchedPkgs.linuxKernel.packages)

        linux_testing
        ;
    }
    // kernels64k;

in
mapAttrs (_: lP: testsForLinuxPackages lP) kernels
// {
  passthru = {
    inherit testsForLinuxPackages;

    # Useful for development testing of all Kernel configs without building full Kernel
    configfiles = mapAttrs (_: lP: lP.kernel.configfile) kernels;

    testsForKernel = kernel: testsForLinuxPackages (patchedPkgs.linuxPackagesFor kernel);
  };
}

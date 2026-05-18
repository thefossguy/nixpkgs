{
  config,
  lib,
  testName,
  enableAutologin,
  enableXWayland,
  ...
}:

let
  emptyPDF = config.node.pkgs.stdenvNoCC.mkDerivation {
    name = "empty-pdf";
    dontUnpack = true;
    nativeBuildInputs = [ config.node.pkgs.imagemagick ];
    buildPhase = ''
      magick xc:none -page Letter empty.pdf
    '';
    installPhase = ''
      mkdir $out
      mv empty.pdf $out/empty.pdf
    '';
  };
  env_COSMIC_READER_EMPTY_PDF = "COSMIC_READER_EMPTY_PDF=${emptyPDF}/empty.pdf";
  env_POLKIT_AGENT_HELPER_PATH = "POLKIT_AGENT_HELPER_PATH=${config.node.pkgs.polkit.out}/lib/polkit-1/polkit-agent-helper-1";
  user = config.nodes.machine.users.users.alice;
  root_user = config.nodes.machine.users.users.root;
  log_file_path = "/home/${user.name}/${testName}";
in

{
  name = testName;

  meta.maintainers = lib.teams.cosmic.members;

  nodes.machine = {
    imports = [ ../common/user-account.nix ];

    services = {
      # For `cosmic-store` to be added to `environment.systemPackages`
      # and for it to work correctly because Flatpak is a runtime
      # dependency of `cosmic-store`.
      flatpak.enable = true;

      displayManager.cosmic-greeter.enable = true;
      desktopManager.cosmic = {
        enable = true;
        xwayland.enable = enableXWayland;
      };
    };

    services.displayManager.autoLogin = lib.mkIf enableAutologin {
      enable = true;
      user = "alice";
    };

    users.users = {
      alice.extraGroups = [ "systemd-journal" ];

      root.password = user.password;
      root.hashedPasswordFile = lib.mkForce null;
    };

    environment.systemPackages = with config.node.pkgs; [
      # These two packages are used to check if a window was opened
      # under the COSMIC session or not. Kinda important.
      # TODO: Move the check from the test module to
      # `nixos/lib/test-driver/src/test_driver/machine.py` so more
      # Wayland-only testing can be done using the existing testing
      # infrastructure.
      jq
      lswt
      (pkgs.makeAutostartItem {
        name = "cosmicTest";
        package = (
          pkgs.makeDesktopItem {
            name = "cosmicTest";
            desktopName = "COSMIC NixOS VM test (${testName})";
            exec = "env ${env_COSMIC_READER_EMPTY_PDF} ${env_POLKIT_AGENT_HELPER_PATH} ${pkgs.python3}/bin/python3 ${./test-script.py} ${log_file_path}";
          }
        );
      })
    ];

    # So far, all COSMIC tests launch a few GUI applications. In doing
    # so, the default allocated memory to the guest of 1024M quickly
    # poses a very high risk of an OOM-shutdown which is worse than an
    # OOM-kill. Because now, the test failed, but not for a genuine
    # reason, but an OOM-shutdown. That's an inconclusive failure
    # which might possibly mask an actual failure. Not enabling
    # systemd-oomd because we need said applications running for a
    # few seconds. So instead, bump the allocated memory to the guest
    # from 1024M to 4x; 4096M.
    virtualisation.memorySize = 4096;
  };

  testScript =
    { nodes, ... }:
    ''
      #testName: ${testName}
      import sys
    ''
    + (
      if enableAutologin then
        ''
          with subtest("cosmic-greeter initialisation"):
              machine.wait_for_unit("graphical.target", timeout=120)
        ''
      else
        ''
          from time import sleep

          machine.wait_for_unit("graphical.target", timeout=120)
          machine.wait_until_succeeds("pgrep --uid ${toString config.nodes.machine.users.users.cosmic-greeter.name} --full cosmic-greeter", timeout=30)
          # Sleep for 10 seconds for ensuring that `greetd` loads the
          # password prompt for the login screen properly.
          sleep(10)

          with subtest("cosmic-session login"):
              machine.send_chars("${user.password}\n", delay=0.2)
        ''
    )
    + ''

      with subtest("xdg autostart support in cosmic"):
          machine.wait_for_unit("app-cosmicTest@autostart.service", user="${user.name}", timeout=60)

      exit_code = 0
      try:
          machine.wait_for_file("${log_file_path}.pkexec_started", timeout=400)
          machine.send_chars("${root_user.password}\n", delay=0.2)
      except Exception:
          exit_code = 1
      try:
          machine.wait_for_file("${log_file_path}.done", timeout=300)
      except Exception:
          exit_code = 1

      # The log file is created in the very beginning of the test
      # script's execution. If we are here, it means that the
      # `wait_for_unit`'s "guard" on the test script's autostart unit
      # plus the 630 second combined timeout of other two
      # `wait_for_file`s, make it extremely likely for the log file to
      # be present.
      machine.copy_from_machine("${log_file_path}.log")
      machine.shutdown()

      with open(machine.out_dir / "${testName}.log") as test_log_file:
          contents = test_log_file.read()
          print(contents)
          if any("Z [ERROR] [L:" in line for line in contents.splitlines()):
              exit_code = 1
      sys.exit(exit_code)
    '';
}

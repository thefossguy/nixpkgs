#!/usr/bin/env python3
import argparse
import logging
import os
import pathlib
import subprocess
import time


def parse_cli_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--cosmic-reader-pdf",
        required=True,
        type=str,
        help="The PDF that the `cosmic-reader` should open for testing",
    )
    parser.add_argument(
        "--log-file-path",
        required=True,
        type=str,
        help="The path to the log file (without the '.log' suffix/extension)",
    )
    parser.add_argument(
        "--polkit-agent-helper-path",
        required=True,
        type=str,
        help="The path to the polkit agent helper (`${pkgs.polkit.out}/lib/polkit-1/polkit-agent-helper-1`)",
    )
    parser.add_argument(
        "--root-user-password", required=True, type=str, help="The root user's password"
    )
    parser.add_argument(
        "--ydotool-bin-path",
        required=True,
        type=str,
        help="The path to the ydotool derivation's bin directory (`${pkgs.ydotool}/bin`)",
    )
    args = parser.parse_args()
    return args


def start_ydotool_daemon(cli_args: argparse.Namespace) -> tuple[str, subprocess.Popen]:
    xdg_runtime_dir = os.getenv("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}"
    ydotool_daemon_socket_path = f"{xdg_runtime_dir}/.ydotool_socket"
    ydotool_daemon_process = subprocess.Popen(
        [
            f"{cli_args.ydotool_bin_path}/ydotoold",
            "--socket-path",
            ydotool_daemon_socket_path,
            "--mouse-off",
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return ydotool_daemon_socket_path, ydotool_daemon_process


def wait_for_cosmic_notification_watcher() -> None:
    logging.info("=" * 80)
    logging.info("Waiting for COSMIC notification watcher start")

    notification_watcher_wait_deadline = time.monotonic() + 360
    notification_watcher_exists = False
    while time.monotonic() < notification_watcher_wait_deadline:
        busctl_process = subprocess.run(
            ["busctl", "--user", "status", "com.system76.CosmicStatusNotifierWatcher"],
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        if busctl_process.returncode == 0:
            notification_watcher_exists = True
            break
        else:
            time.sleep(1)
    notification_watcher_msg = "Waiting for the COSMIC notification watcher"
    if notification_watcher_exists:
        logging.info(f"{notification_watcher_msg} passed")
    else:
        logging.error(f"{notification_watcher_msg} failed")


def perform_polkit_authentication_test(
    cli_args: argparse.Namespace,
    ydotool_daemon_socket_path: str,
    ydotool_daemon_process: subprocess.Popen,
) -> None:
    logging.info("=" * 80)
    logging.info("Performing polkit authentication test")

    polkit_test_passed = False
    polkit_test_command = [
        "pkexec",
        "--disable-internal-agent",
        "bash",
        "-c",
        "echo -n 'polkit test was successful'",
    ]
    logging.info(f"Running: {polkit_test_command}")
    polkit_test_process = subprocess.Popen(
        polkit_test_command,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )

    polkit_popup_deadline = time.monotonic() + 60
    pop_up_msg = "the pop-up for polkit password authentication"
    encountered_polkit_authentication_popup = False
    while time.monotonic() < polkit_popup_deadline:
        polkit_popup_check_process = subprocess.run(
            [
                "pgrep",
                "-afx",
                f"{cli_args.polkit_agent_helper_path} --socket-activated",
            ],
            check=False,
        )
        if polkit_popup_check_process.returncode == 0:
            encountered_polkit_authentication_popup = True
            logging.info(f"Noticed {pop_up_msg}")
            if ydotool_daemon_process.poll() == None:
                ydotool_process = subprocess.run(
                    [
                        "env",
                        f"YDOTOOL_SOCKET={ydotool_daemon_socket_path}",
                        f"{cli_args.ydotool_bin_path}/ydotool",
                        "type",
                        "--key-delay=500",
                        f"{cli_args.root_user_password}\n",
                    ],
                    check=False,
                )
                ydotool_msg = (
                    "the root user's password in the pop-up for polkit authentication"
                )
                if ydotool_process.returncode == 0:
                    logging.info(f"ydotool typed {ydotool_msg}")
                else:
                    logging.error(f"ydtool did not type {ydotool_msg}")
            else:
                logging.error(
                    "The ydotool daemon exited for some reason before it could be used"
                )
            break
        time.sleep(1)
    if not encountered_polkit_authentication_popup:
        logging.error(f"Did not notice {pop_up_msg}")


    polkit_test_process_stdout = ""
    polkit_test_process_stderr = ""
    try:
        polkit_test_process_stdout, polkit_test_process_stderr = (
            polkit_test_process.communicate(timeout=45)
        )
    except subprocess.TimeoutExpired:
        polkit_test_process.kill()
        polkit_test_process_stdout, polkit_test_process_stderr = (
            polkit_test_process.communicate()
        )

    logging.info(f"polkit stdout: '{polkit_test_process_stdout}'")
    logging.info(f"polkit stderr: '{polkit_test_process_stderr}'")

    if polkit_test_process_stdout:
        logging.info(f"pkexec command stdout: {polkit_test_process_stdout}")
        polkit_test_passed = "polkit test was successful" in polkit_test_process_stdout
    else:
        logging.warning("Could not capture stdout from the polkit test command")

    if polkit_test_passed:
        logging.info("The polkit authentication test passed")
    else:
        logging.error("The polkit authentication test failed")


def perform_gui_application_test(cli_args: argparse.Namespace) -> None:
    logging.info("=" * 80)
    logging.info("Performing test to launch GUI applications")

    gui_apps_to_test = {
        "com.system76.CosmicEdit": [
            "cosmic-edit",
        ],
        "com.system76.CosmicFiles": [
            "cosmic-files",
        ],
        "com.system76.CosmicPlayer": [
            "cosmic-player",
        ],
        "com.system76.CosmicReader": [
            "cosmic-reader",
            cli_args.cosmic_reader_pdf,
        ],
        "com.system76.CosmicSettings": [
            "cosmic-settings",
        ],
        "com.system76.CosmicStore": [
            "cosmic-store",
        ],
        "com.system76.CosmicTerm": [
            "cosmic-term",
        ],
    }

    for gui_app_id, gui_app_command in gui_apps_to_test.items():
        logging.info(f"Running: {gui_app_command}")
        gui_app_bg_process = subprocess.Popen(
            gui_app_command,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        gui_app_bg_process_deadline = time.monotonic() + 30
        gui_app_is_running = False

        while time.monotonic() < gui_app_bg_process_deadline and not gui_app_is_running:
            lswt_process = subprocess.run(
                [
                    "lswt",
                    "--custom",
                    "a",
                ],
                check=False,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
            )
            lswt_process_stdout = lswt_process.stdout.strip()
            if lswt_process_stdout:
                if gui_app_id in lswt_process_stdout.splitlines():
                    gui_app_is_running = True
            time.sleep(1)
        pkill_process = subprocess.run(
            ["pkill", gui_app_command[0]],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )

        log_message = (
            f"The GUI application test for '{gui_app_command[0]}' ({gui_app_id})"
        )
        if gui_app_is_running:
            logging.info(f"{log_message} passed")
        else:
            logging.error(f"{log_message} failed")


def main() -> None:
    cli_args = parse_cli_args()
    logging.basicConfig(
        level=logging.INFO,
        format=f"%(asctime)sZ [%(levelname)s] [L:%(lineno)d] %(message)s",
        datefmt="%H:%M:%S",
        handlers=[
            logging.StreamHandler(),
            logging.FileHandler(f"{cli_args.log_file_path}.log", mode="w"),
        ],
    )
    logging.Formatter.converter = time.gmtime
    logging.info(f"Logging to '{cli_args.log_file_path}.log'")

    ydotool_daemon_socket_path, ydotool_daemon_process = start_ydotool_daemon(cli_args)
    wait_for_cosmic_notification_watcher()
    perform_polkit_authentication_test(
        cli_args, ydotool_daemon_socket_path, ydotool_daemon_process
    )
    perform_gui_application_test(cli_args)

    pathlib.Path(f"{cli_args.log_file_path}.done").touch()


if __name__ == "__main__":
    main()

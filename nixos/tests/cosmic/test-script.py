#!/usr/bin/env python3
import logging
import os
import pathlib
import subprocess
import sys
import time


log_file_path = sys.argv[1]
if log_file_path.endswith(".log"):
    log_file_path = log_file_path[:-4]
log_file_name = f"{log_file_path}.log"


def wait_for_orca() -> None:
    logging.info("=" * 80)
    logging.info("Waiting for Orca (screen reader) to start")

    orca_deadline = time.monotonic() + 300
    orca_test_passed = False
    while time.monotonic() < orca_deadline:
        pgrep_process = subprocess.run(
            [
                "pgrep",
                "--uid",
                str(os.getuid()),
                "--full",
                "orca",
            ],
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        if pgrep_process.returncode == 0:
            orca_test_passed = True
            break
        else:
            time.sleep(1)
    orca_msg = "Waiting for the Orca screen reader"
    if orca_test_passed:
        logging.info(f"{orca_msg} passed")
    else:
        logging.error(f"{orca_msg} failed")


def perform_polkit_authentication_test() -> None:
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
        stderr=subprocess.DEVNULL,
        text=True,
    )

    polkit_popup_deadline = time.monotonic() + 60
    while time.monotonic() < polkit_popup_deadline:
        polkit_popup_check_process = subprocess.run(
            [
                "pgrep",
                "-afx",
                f"{os.getenv('POLKIT_AGENT_HELPER_PATH')} --socket-activated",
            ],
            check=False,
        )
        if polkit_popup_check_process.returncode == 0:
            pathlib.Path(f"{log_file_path}.pkexec_started").touch()
            break
        time.sleep(1)

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


def perform_gui_application_test() -> None:
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
            os.getenv("COSMIC_READER_EMPTY_PDF"),
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

        while time.monotonic < gui_app_bg_process_deadline and not gui_app_is_running:
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
    logging.basicConfig(
        level=logging.INFO,
        format=f"%(asctime)sZ [%(levelname)s] [L:%(lineno)d] %(message)s",
        datefmt="%H:%M:%S",
        handlers=[
            logging.StreamHandler(),
            logging.FileHandler(log_file_name, mode="w"),
        ],
    )
    logging.Formatter.converter = time.gmtime
    logging.info(f"Logging to '{log_file_name}'")

    wait_for_orca()
    perform_polkit_authentication_test()
    perform_gui_application_test()
    pathlib.Path(f"{log_file_path}.done").touch()


if __name__ == "__main__":
    main()

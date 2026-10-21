import argparse
import json
import sys
import time
from pathlib import Path

from selenium import webdriver
from selenium.common.exceptions import WebDriverException
from selenium.webdriver.edge.options import Options

from browser_common import (
    assert_browser_available,
    debugger_address,
    load_config,
    wait_for_editor,
    write_status,
)


def wait_for_zip(directory: Path, timeout: int) -> Path:
    deadline = time.monotonic() + timeout
    previous = {}
    while time.monotonic() < deadline:
        if not list(directory.glob("*.crdownload")):
            for archive in directory.glob("*.zip"):
                size = archive.stat().st_size
                if size > 0 and previous.get(archive) == size:
                    return archive
                previous[archive] = size
        time.sleep(1)
    raise TimeoutError("Timed out waiting for the Overleaf ZIP.")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", required=True, type=Path)
    parser.add_argument("--browser-id", required=True)
    parser.add_argument("--download-directory", required=True, type=Path)
    parser.add_argument("--result-file", required=True, type=Path)
    parser.add_argument("--status-file", type=Path)
    args = parser.parse_args()

    config = load_config(args.config)
    address = debugger_address(config, args.browser_id)
    assert_browser_available(address)
    args.download_directory.mkdir(parents=True, exist_ok=True)
    status = args.status_file.resolve() if args.status_file else None

    options = Options()
    options.debugger_address = address
    driver = webdriver.Edge(options=options)
    original = driver.current_window_handle
    download_tab = None
    try:
        driver.get(config["overleaf"]["projectUrl"])
        wait_for_editor(driver, config, status, args.browser_id)
        driver.execute_cdp_cmd(
            "Browser.setDownloadBehavior",
            {"behavior": "allow", "downloadPath": str(args.download_directory.resolve())},
        )
        write_status(status, "downloading", "Downloading the Overleaf ZIP.", args.browser_id)
        driver.switch_to.new_window("tab")
        download_tab = driver.current_window_handle
        try:
            driver.get(config["overleaf"]["downloadUrl"])
        except WebDriverException as exc:
            if "ERR_ABORTED" not in str(exc):
                raise
        archive = wait_for_zip(
            args.download_directory,
            int(config["browser"]["operationTimeoutSeconds"]),
        )
        args.result_file.write_text(json.dumps({"archivePath": str(archive.resolve())}), encoding="utf-8")
        write_status(status, "downloaded", f"Downloaded {archive.name}.", args.browser_id)
    finally:
        if download_tab and download_tab in driver.window_handles:
            driver.switch_to.window(download_tab)
            driver.close()
        if original in driver.window_handles:
            driver.switch_to.window(original)
        driver.service.stop()
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:
        print(f"Download failed: {exc}", file=sys.stderr)
        sys.exit(1)

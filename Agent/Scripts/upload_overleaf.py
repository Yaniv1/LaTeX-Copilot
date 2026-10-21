import argparse
import sys
from pathlib import Path

from selenium import webdriver
from selenium.common.exceptions import ElementClickInterceptedException, TimeoutException
from selenium.webdriver.common.by import By
from selenium.webdriver.edge.options import Options
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.ui import WebDriverWait

from browser_common import (
    assert_browser_available,
    debugger_address,
    load_config,
    wait_for_editor,
    write_status,
)


def click(driver, locator, timeout: int, non_interactive: bool) -> None:
    while True:
        element = WebDriverWait(driver, timeout).until(EC.element_to_be_clickable(locator))
        try:
            element.click()
            return
        except ElementClickInterceptedException:
            if non_interactive:
                raise RuntimeError("A browser dialog is blocking the upload controls.")
            input("Dismiss the blocking browser dialog, then press Enter...")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", required=True, type=Path)
    parser.add_argument("--browser-id", required=True)
    parser.add_argument("--paper-directory", required=True, type=Path)
    parser.add_argument("--status-file", type=Path)
    parser.add_argument("--non-interactive", action="store_true")
    args = parser.parse_args()

    config = load_config(args.config)
    address = debugger_address(config, args.browser_id)
    assert_browser_available(address)
    status = args.status_file.resolve() if args.status_file else None
    timeout = int(config["browser"]["operationTimeoutSeconds"])
    options = Options()
    options.debugger_address = address
    driver = webdriver.Edge(options=options)
    try:
        driver.get(config["overleaf"]["projectUrl"])
        wait_for_editor(driver, config, status, args.browser_id)
        if not args.non_interactive:
            input("Dismiss Overleaf notifications, then press Enter to upload...")
        click(driver, (By.ID, "toolbar-menu-bar-item-file"), timeout, args.non_interactive)
        click(
            driver,
            (By.XPATH, "//*[@role='menuitem' and normalize-space()='Upload file']"),
            timeout,
            args.non_interactive,
        )
        directory_input = None
        for selector in (
            "input[type='file'][webkitdirectory]",
            "input[type='file'][directory]",
        ):
            try:
                directory_input = WebDriverWait(driver, 15).until(
                    EC.presence_of_element_located((By.CSS_SELECTOR, selector))
                )
                break
            except TimeoutException:
                continue
        if directory_input is None:
            raise RuntimeError("Overleaf did not expose a folder upload input.")
        write_status(status, "uploading", "Uploading the local Paper directory.", args.browser_id)
        directory_input.send_keys(str(args.paper_directory.resolve()))
        WebDriverWait(driver, timeout).until(lambda _: not directory_input.is_displayed())
        write_status(status, "completed", "Browser upload completed.", args.browser_id)
        if not args.non_interactive:
            input("Verify the uploaded project, then press Enter to disconnect Selenium...")
    finally:
        driver.service.stop()
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:
        print(f"Upload failed: {exc}", file=sys.stderr)
        sys.exit(1)

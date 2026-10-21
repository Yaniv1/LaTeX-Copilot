import json
import os
import time
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

from selenium.common.exceptions import NoSuchElementException, TimeoutException
from selenium.webdriver.common.by import By


def load_config(path: Path) -> dict:
    with path.open("r", encoding="utf-8-sig") as handle:
        return json.load(handle)


def write_status(path: Path | None, phase: str, message: str, browser_id: str) -> None:
    if path is None:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(
        json.dumps(
            {
                "phase": phase,
                "message": message,
                "browserId": browser_id,
                "processId": os.getpid(),
                "updatedAtUtc": datetime.now(timezone.utc).isoformat(),
            },
            indent=2,
        ),
        encoding="utf-8",
    )
    temporary.replace(path)


def debugger_address(config: dict, browser_id: str) -> str:
    browser = config["browser"]
    if browser_id != browser["browserId"]:
        raise RuntimeError(f"Browser ID {browser_id!r} is not configured for this paper.")
    return f'{browser["debuggingAddress"]}:{int(browser["debuggingPort"])}'


def assert_browser_available(address: str) -> None:
    try:
        with urllib.request.urlopen(f"http://{address}/json/version", timeout=5) as response:
            payload = json.load(response)
    except Exception as exc:
        raise RuntimeError("The persistent browser is unavailable.") from exc
    if not payload.get("webSocketDebuggerUrl"):
        raise RuntimeError("The persistent browser debugging endpoint is not ready.")


def fill_account_if_visible(driver, account: str) -> None:
    for selector in (
        "input[type='email']",
        "input[name='email']",
        "input[name='loginfmt']",
        "input[autocomplete='username']",
    ):
        try:
            element = driver.find_element(By.CSS_SELECTOR, selector)
        except NoSuchElementException:
            continue
        if element.is_displayed() and element.is_enabled() and not element.get_attribute("value"):
            element.send_keys(account)
            return


def wait_for_editor(driver, config: dict, status_file: Path | None, browser_id: str) -> None:
    deadline = time.monotonic() + int(config["browser"]["authenticationTimeoutSeconds"])
    announced = False
    while time.monotonic() < deadline:
        try:
            toolbar = driver.find_element(By.ID, "toolbar-menu-bar-item-file")
            if toolbar.is_displayed() and toolbar.is_enabled():
                return
        except NoSuchElementException:
            pass
        fill_account_if_visible(driver, config["overleaf"].get("account", ""))
        if not announced:
            write_status(status_file, "awaiting_authentication", "Waiting for browser authentication.", browser_id)
            print("Complete authentication and MFA only in the persistent browser.", flush=True)
            announced = True
        time.sleep(1)
    raise TimeoutException("Timed out waiting for the authenticated Overleaf editor.")

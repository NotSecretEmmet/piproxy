#!/home/pi/pienv/bin/python
import argparse
import subprocess
from rich import print

from huawei_lte_api.Client import Client
from huawei_lte_api.Connection import Connection

import sys
import os

venv_path = "/home/pi/pienv"
if sys.prefix != venv_path:
    activate_this = os.path.join(venv_path, "bin/activate_this.py")
    with open(activate_this) as f:
        exec(f.read(), {"__file__": activate_this})


NETWORK_TYPES: dict[str, str] = {
    "0": "Invalid",
    "1": "GSM",
    "2": "GPRS",
    "3": "EDGE",
    "4": "WCDMA",
    "5": "HSDPA",
    "6": "HSUPA",
    "7": "HSPA",
    "8": "TDSCDMA",
    "9": "HSPA+",
    "10": "EVDO Rev.0",
    "11": "EVDO Rev.A",
    "12": "EVDO Rev.B",
    "13": "1xRTT",
    "14": "UMB",
    "15": "1xEVDV",
    "16": "3xRTT",
    "17": "HSPA+ 64QAM",
    "18": "HSPA+ MIMO",
    "19": "LTE",
    "101": "LTE",
}


def get_gateway_from_iface(iface: str) -> str:
    cmd = ["ip", "route", "show", "dev", iface]
    try:
        routes = subprocess.check_output(cmd, text=True).splitlines()
        for line in routes:
            if "via" in line:
                return line.split("via")[1].split()[0].strip()
    except Exception as e:
        raise RuntimeError(f"Could not detect gateway for {iface}: {e}")

    raise RuntimeError(f"No gateway found for interface {iface}")


def safe_call(f, default=None):
    try:
        return f()
    except:
        return default


def print_modem_status(gateway: str):
    print(f"[bold cyan]Connecting to modem at http://{gateway}/[/bold cyan]")
    try:
        with Connection(f"http://{gateway}/") as conn:
            client = Client(conn)

            info = safe_call(client.device.information, {})
            basic = safe_call(client.monitoring.status, {})
            notify = safe_call(client.monitoring.check_notifications, {})
            signal = safe_call(client.device.signal, {})  # some modems support this
            traffic = safe_call(client.monitoring.traffic_statistics, {})

    except Exception as e:
        print(f"[bold red]Failed to connect to modem: {e}[/bold red]")
        return

    print("\n[bold green]=== DEVICE INFORMATION ===[/bold green]")
    print(f"[yellow]Model:[/yellow] {info.get('DeviceName', 'N/A')}")
    print(f"[yellow]IMEI:[/yellow] {info.get('Imei', 'N/A')}")
    print(f"[yellow]Software:[/yellow] {info.get('SoftwareVersion', 'N/A')}")
    print(f"[yellow]Hardware:[/yellow] {info.get('HardwareVersion', 'N/A')}")

    print("\n[bold green]=== NETWORK STATUS ===[/bold green]")
    net_type = basic.get("CurrentNetworkTypeEx", basic.get("CurrentNetworkType", "N/A"))
    net_type_label = NETWORK_TYPES.get(str(net_type), f"Unknown ({net_type})")
    print(f"[yellow]Network Type:[/yellow] {net_type_label}")

    print(f"[yellow]Operator:[/yellow] {basic.get('FullName', 'N/A')}")
    print(f"[yellow]Roaming:[/yellow] {basic.get('RoamingStatus', 'N/A')}")

    print("\n[bold green]=== SIGNAL ===[/bold green]")

    # Merge signal fields from all possible sources
    merged = {}
    for source in (basic, notify, signal):
        if isinstance(source, dict):
            merged.update({k.lower(): v for k, v in source.items()})

    def pick(*names):
        for name in names:
            if name.lower() in merged and merged[name.lower()] not in ("", None):
                return merged[name.lower()]
        return "N/A"

    print(f"[yellow]RSRP:[/yellow] {pick('rsrp', 'rssi', 'signalstrength')}")
    print(f"[yellow]RSRQ:[/yellow] {pick('rsrq')}")
    print(f"[yellow]RSSI:[/yellow] {pick('rssi', 'signalstrength')}")
    print(f"[yellow]SINR:[/yellow] {pick('sinr', 'cinr')}")

    print("\n[bold green]=== TRAFFIC ===[/bold green]")
    print(
        f"[yellow]Upload (MB):[/yellow] {int(traffic.get('CurrentUpload', 0)) / (1024 * 1024):.2f}"
    )
    print(
        f"[yellow]Download (MB):[/yellow] {int(traffic.get('CurrentDownload', 0)) / (1024 * 1024):.2f}"
    )

    print("\n[bold green]=== IP ADDRESSES ===[/bold green]")
    print(f"[yellow]WAN IP:[/yellow] {pick('wanipaddress')}")
    print(f"[yellow]Local IP:[/yellow] {pick('localipaddress')}")

    print("\n[bold blue]Status query finished successfully.[/bold blue]\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Print modem status using interface name"
    )
    parser.add_argument(
        "--iface", required=True, help="usb interface (usb0, usb1, etc.)"
    )
    args = parser.parse_args()

    gateway = get_gateway_from_iface(args.iface)
    print(f"[bold blue]Detected gateway for {args.iface}: {gateway}[/bold blue]")

    print_modem_status(gateway)

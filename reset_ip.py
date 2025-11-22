#!/home/pi/pienv/bin/python
import argparse
import os
import subprocess
import sys
import time

import requests
from huawei_lte_api.Client import Client
from huawei_lte_api.Connection import Connection
from huawei_lte_api.enums.net import LTEBandEnum, NetworkBandEnum, NetworkModeEnum
from rich import print

venv_path = "/home/pi/pienv"
if sys.prefix != venv_path:
    activate_this = os.path.join(venv_path, "bin/activate_this.py")
    with open(activate_this) as f:
        exec(f.read(), {"__file__": activate_this})


def get_gateway_from_iface(iface: str) -> str:
    """
    Detect the gateway IP for a given interface (usb0, usb1, etc.)
    Uses routing table to find the default gateway for that interface.
    """
    try:
        cmd = ["ip", "route", "show", "dev", iface]
        routes = subprocess.check_output(cmd, text=True).splitlines()

        for line in routes:
            # patterns:
            # default via 192.168.8.1 dev usb0
            if "via" in line:
                gw = line.split("via")[1].split()[0].strip()
                return gw

        raise RuntimeError("No gateway found for interface")
    except Exception as e:
        raise RuntimeError(f"Failed to get gateway for {iface}: {e}")


def reset_ip(
    gateway: str, proxy_host: str = None, proxy_port: int = None, timeout: float = 5.0
):
    print(f"[cyan]Connecting to modem at {gateway}[/cyan]")

    proxies = None
    if proxy_host and proxy_port:
        proxies = {
            "http": f"http://{proxy_host}:{proxy_port}",
            "https": f"http://{proxy_host}:{proxy_port}",
        }

    try:
        with Connection(url=f"http://{gateway}/", timeout=timeout) as connection:
            client = Client(connection)

            # Fetch current mode
            mode_resp = client.net.net_mode()
            current_mode = mode_resp.get(
                "NetworkMode", NetworkModeEnum.MODE_4G_3G_AUTO.value
            )

            new_mode = (
                NetworkModeEnum.MODE_4G_ONLY
                if current_mode != NetworkModeEnum.MODE_4G_ONLY.value
                else NetworkModeEnum.MODE_4G_3G_AUTO
            )

            print("[yellow]Toggling network mode to reset IP…[/yellow]")
            client.net.set_net_mode(
                lteband=LTEBandEnum.ALL,
                networkband=NetworkBandEnum.ALL,
                networkmode=new_mode,
            )

            time.sleep(2.0)
            print("[green]Reset command sent[/green]")

    except Exception as e:
        print(f"[red]Failed to reset modem at {gateway}: {e}[/red]")
        return

    if proxies:
        try:
            r = requests.get("https://icanhazip.com", proxies=proxies, timeout=10)
            print("[bold green]New Proxy IP:[/bold green]", r.text.strip())
        except Exception as e:
            print(f"[red]Failed to fetch proxy IP: {e}[/red]")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Reset modem IP using interface name")
    parser.add_argument(
        "--iface", required=True, help="Interface name (usb0, usb1, etc.)"
    )
    parser.add_argument("--timeout", type=float, default=5.0, help="HiLink timeout")
    parser.add_argument("--proxy-host", type=str, help="Proxy host")
    parser.add_argument("--proxy-port", type=int, help="Proxy port")
    args = parser.parse_args()

    gateway = get_gateway_from_iface(args.iface)
    print(f"[blue]Detected gateway for {args.iface}: {gateway}[/blue]")

    reset_ip(
        gateway=gateway,
        proxy_host=args.proxy_host,
        proxy_port=args.proxy_port,
        timeout=args.timeout,
    )

import time
from rich import print

from huawei_lte_api.Client import Client
from huawei_lte_api.Connection import Connection
from huawei_lte_api.enums.net import LTEBandEnum, NetworkBandEnum, NetworkModeEnum

import requests

proxies = {
    "http": "http://admin:admin@192.168.1.93:3128",
    "https:": "http://admin:admin@192.168.1.93:3128",
}


def main(gateway: str, timeout: float = 5.0):
    print(f"Connecting to {gateway}")
    with Connection(url=f"http://{gateway}/", timeout=timeout) as connection:
        lte_client = Client(connection)
        # print(lte_client.device.information())
        # print("Resetting network...")
        net_mode_response = lte_client.net.net_mode()
        net_mode = net_mode_response.get(
            "NetworkMode", NetworkModeEnum.MODE_4G_3G_AUTO.value
        )
        new_net_mode = (
            NetworkModeEnum.MODE_4G_ONLY
            if not net_mode == NetworkModeEnum.MODE_4G_ONLY.value
            else NetworkModeEnum.MODE_4G_3G_AUTO
        )
        time.sleep(0.1)
        lte_client.net.set_net_mode(
            lteband=LTEBandEnum.ALL,
            networkband=NetworkBandEnum.ALL,
            networkmode=new_net_mode,
        )
        time.sleep(2.0)


if __name__ == "__main__":
    r = requests.get(url="https://icanhazip.com", proxies=proxies)
    print(r.content)
    import argparse

    parser = argparse.ArgumentParser(
        description="Reset IP address of a 4G modem with HiLink interface"
    )
    parser.add_argument(
        "--gateway",
        type=str,
        default="192.168.8.1",
        required=False,
        help="modem gateway address",
    )
    parser.add_argument(
        "--timeout",
        type=float,
        required=False,
        default=5.0,
        help="modem connection timeout in seconds (default=5.0)",
    )
    args = parser.parse_args()
    main(gateway=args.gateway, timeout=args.timeout)

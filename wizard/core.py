import paramiko
import warnings
import time
import getpass

warnings.filterwarnings(action="ignore", module=".*paramiko.*")

texts = {
    "ip": "Enter ip address: ",
    "user": "Enter username[{username}]: ",
    "password": "Enter password: ",
    "install": "Select installation preset(all/frontend/backend/none): ",
    "store_email": "Enter email to use for your Bitcart Store Auth: ",
    "store_pass": "Enter password to use for your Bitcart Store Auth: ",
    "store_id": "Enter id of the store used in your Bitcart Store[1]: ",
    "onedomain_mode": "Do you want to enter one domain mode(default domain preset)?(Y/N) ",
    "alldomain": "Enter root domain for all services: ",
    "api_domain": "Enter domain for Bitcart Merchants API: ",
    "admin_domain": "Enter domain for Bitcart Admin Panel: ",
    "frontend_domain": "Enter domain for Bitcart Store: ",
    "cryptos": "Which cryptos to add[btc]: ",
    "reverseproxy": "Which reverseproxy to use[nginx-https]: ",
    "additional_components": "Which additional components to add[none]:",
    "start_bitcart": "Do you want to start bitcart?(Y/N) ",
}

defaults = {
    "user": getpass.getuser(),
    "install": "all",
    "store_id": "1",
    "onedomain_mode": "Y",
    "cryptos": "btc",
    "reverseproxy": "nginx-https",
    "additional_components": "",
    "start_bitcart": "Y",
}

checks = [
    {
        "vars": ["store_email", "store_pass", "store_id"],
        "args": ["install"],
        "check": lambda x: x in ["frontend", "all"],
    },
    {
        "vars": ["alldomain"],
        "args": ["onedomain_mode"],
        "check": lambda x: verify_install_bitcart(x),
    },
    {
        "vars": ["api_domain", "admin_domain", "frontend_domain"],
        "args": ["onedomain_mode"],
        "check": lambda x: not verify_install_bitcart(x),
    },
    {
        "vars": ["api_domain"],
        "args": ["install"],
        "check": lambda x: x in ["frontend", "backend", "all"],
    },
    {
        "vars": ["admin_domain", "frontend_domain"],
        "args": ["install"],
        "check": lambda x: x in ["frontend", "all"],
    },
]


def connect(
    ip,
    user,
    password,
    print_func,
    start_bitcart=True,
    install="all",
    cryptos="btc",
    additional_components="",
    reverseproxy="nginx-https",
    alldomain="",
    admin_domain="",
    api_domain="",
    frontend_domain="",
    store_email="",
    store_pass="",
    store_id=1,
):
    print_func("Starting installation, please wait...")
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(ip, username=user, password=password, timeout=10)
    transport = client.get_transport()
    channel = transport.open_session()
    commands = f"""
sudo apt install git
sudo rm -rf bitcart-docker
git clone https://github.com/bitcartcc/bitcart-docker
cd bitcart-docker
export BITCART_INSTALL={install}
export BITCART_CRYPTOS={cryptos}
export BITCART_REVERSEPROXY={reverseproxy}
export BITCART_ADDITIONAL_COMPONENTS={additional_components}
    """
    protocol = "https://" if reverseproxy == "nginx-https" else "http://"
    if alldomain:
        api_domain = "api." + alldomain
        frontend_domain = alldomain
        admin_domain = "admin." + alldomain
    commands += f"""
export BITCART_HOST={api_domain}
export BITCART_FRONTEND_HOST={frontend_domain}
export BITCART_ADMIN_HOST={admin_domain}
export BITCART_ADMIN_URL={protocol+api_domain}
export BITCART_FRONTEND_URL={protocol+api_domain}
"""
    commands += "./setup.sh\n"
    if start_bitcart:
        commands += "./start.sh\n"
    channel.exec_command(commands)
    channel.recv_exit_status()
    channel.close()
    print_func("Setup done.")
    if start_bitcart:
        print_func("Successfully started bitcart!")
    print_func("Done.")
    client.close()


def verify_install_bitcart(start):
    if start in ["Yes", "yes", "YES", "Y", "y"]:
        return True
    else:
        return False

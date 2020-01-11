import paramiko
import warnings
import time

warnings.filterwarnings(action="ignore", module=".*paramiko.*")


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
git clone https://github.com/MrNaif2018/bitcart-docker
cd bitcart-docker
export BITCART_INSTALL={install}
export BITCART_CRYPTOS={cryptos}
export BITCART_REVERSEPROXY={reverseproxy}
export BITCART_ADDITIONAL_COMPONENTS={additional_components}
export BITCART_FRONTEND_EMAIL={store_email}
export BITCART_FRONTEND_PASSWORD={store_pass}
export BITCART_FRONTEND_STORE={store_id}
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

import getpass
import core


ip = input("Enter ip address: ")
user = input("Enter username[" + getpass.getuser() + "]: ") or getpass.getuser()
password = getpass.getpass("Enter password: ")
install = input("Select installation preset(all/frontend/backend/none): ") or "all"
store_email = ""
store_pass = ""
store_id = 1
if install in ["frontend", "all"]:
    store_email = input("Enter email to use for your Bitcart Store Auth: ")
    store_pass = getpass.getpass("Enter password to use for your Bitcart Store Auth: ")
    store_id = input("Enter id of the store used in your Bitcart Store[1]: ") or "1"
onedomain_mode = input(
    "Do you want to enter one domain mode(default domain preset)?(Y/N) "
)
domain = ""
api_domain = ""
admin_domain = ""
frontend_domain = ""
if core.verify_install_bitcart(onedomain_mode):
    domain = input("Enter root domain for all services: ")
else:
    if install in ["backend", "all"]:
        api_domain = input("Enter domain for Bitcart Merchants API: ")
    if install in ["frontend", "all"]:
        if install == "frontend":
            api_domain = input("Enter url of Bitcart Merchants API: ")
        admin_domain = input("Enter domain for Bitcart Admin Panel: ")
        frontend_domain = input("Enter domain for Bitcart Store: ")
cryptos = input("Which cryptos to add[btc]: ") or "btc"
reverseproxy = input("Which reverseproxy to use[nginx-https]: ") or "nginx-https"
additional_components = input("Which additional components to add[none]:") or ""
start = input("Do you want to start bitcart?(Y/N) ") or "Y"
core.connect(
    ip,
    user,
    password,
    print,
    core.verify_install_bitcart(start),
    install,
    cryptos,
    additional_components,
    reverseproxy,
    domain,
    admin_domain,
    api_domain,
    frontend_domain,
    store_email,
    store_pass,
    store_id,
)

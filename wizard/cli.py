import getpass
import core


ip = input("Enter ip address: ")
user = input("Enter username["+getpass.getuser()+"]: ")
if not user:
    user = getpass.getuser()
password = getpass.getpass("Enter password: ")
domain = input("Enter domain(optional, enter for none): ")
start = input("Do you want to start bitcart?(Y/N) ")
core.connect(ip, user, password, print,
             core.verify_install_bitcart(start), domain)

import getpass
from core import connect


ip = input("Enter ip address: ")
user = input("Enter username["+getpass.getuser()+"]: ")
if not user:
    user = getpass.getuser()
password = getpass.getpass("Enter password: ")
domain = input("Enter domain(optional, enter for none): ")
connect(ip, user, password, print, input, domain)

import paramiko
import warnings
import time
warnings.filterwarnings(action='ignore', module='.*paramiko.*')


def connect(ip, user, password, print_func, start_bitcart=True, domain=""):
    print_func("Starting installation, please wait...")
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(ip, username=user, password=password, timeout=10)
    transport = client.get_transport()
    channel = transport.open_session()
    channel.exec_command('''
    sudo apt install git screen
    sudo rm -rf bitcart-docker
    docker-compose down
    git clone https://github.com/MrNaif2018/bitcart-docker
    cd bitcart-docker
    export BITCART_HOST='''+domain+'''
    ./setup.sh
    ''')
    channel.recv_exit_status()
    channel.close()
    print_func("Setup done.")
    if start_bitcart:
        channel = transport.open_session()
        channel.exec_command('''
            screen -dm bash -c "cd bitcart-docker;./start.sh"
        ''')
        print_func("Successfully started bitcart!")
    print_func("Done.")
    client.close()


def verify_install_bitcart(start):
    if start in ["Yes", "yes", "Y", "y"]:
        return True
    else:
        return False

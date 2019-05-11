import paramiko
import warnings
import time
warnings.filterwarnings(action='ignore', module='.*paramiko.*')


def connect(ip, user, password, print_func, input_func, domain=""):
    print_func("Starting installation, please wait...")
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(ip, username=user, password=password)
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
    start = input_func("Do you want to start bitcart now?(Y/N) ")
    if start in ["Yes", "yes", "Y", "y"]:
        channel = transport.open_session()
        channel.exec_command('''
            screen -dm bash -c "cd bitcart-docker;./start.sh"
        ''')
    else:
        print_func("Done.")
    client.close()

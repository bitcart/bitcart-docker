# bitcart-docker

Docker images now available!

Using provided scripts(easy)
----------------------------
Now, to install bitcart, if you're on linux system(these scripts for windows will be added soon), 
you won't even need to install docker in most cases, script will do it for you!
So, now, to download, set up, and run your bitcart instance, simply run these 4 commands:

    git clone https://github.com/MrNaif2018/bitcart-docker
    cd bitcart-docker
    export BITCART_HOST=yourdomain
    ./setup.sh
    ./start.sh

Install from docker hub(stable)
------------------------------

Simply run

    docker pull mrnaif/bitcart
    
for downloading image.
To run it, use the following command(pulling is done automaticly):

    docker-compose up

    
Development builds
------------------

First, you will need to download latest version of repository and apply some adjustments.
You will also need to create .env file with approciate settings.
You can find .env file specification at main repository.
So, first run  

    ./dev-setup.sh
  
which will download git, clone repository and make needed adjustments. 
If you can't use this shell script, do it manually, 
you can always contact us in our support groups.

After that your environment is ready, simply run

    docker-compose -f docker-compose.dev.yml build 
    
to build the image(bitcart main image), or just run

    docker-compose -f docker-compose.dev.yml up --build
    
to build image and start the containers.

Live demo
---------
Now we have live demo available at https://demo.bitcartcc.tk/
Note that it isn't designed for using, it is for testing and seeing what is it.
Note that our project is still in early alpha stage, so a lot will be changed.

Guide: how demo was set up
--------------------------
**UPDATE**
Now demo can be setup just like so:

    sudo apt install git
    git clone https://github.com/MrNaif2018/bitcart-docker
    cd bitcart-docker
    export BITCART_HOST=yourhost
    ./setup.sh
    ./start.sh
    
Or, use our brand new wizard:

    wget https://github.com/MrNaif2018/bitcart-docker/releases/download/0.0.1/bitcart-cli && ./bitcart-cli
    
It will launch interactive wizard, which you can use to install bitcart on your server.
    
**OLD GUIDE:**
   
This guide will show how the live demo was set up.
You can use this guide to set up your own bitcart instance.
Our server already has everything we needed as it isn't a new server.
But you will need to install some dependences:
First, this guide assumes that you have ubuntu-like distibution. On our server ubuntu 18.04 was used.
Install docker to run our docker containers:
https://docs.docker.com/install/
We used the following guide:
https://docs.docker.com/install/linux/docker-ce/ubuntu/
If you have any problems when setting up, you can always contact us at our telegram group:
https://t.me/bitcartcc
Then, install nginx and certbot(for using https://yourdomain.tld, and not some.ip.address.here:8000, it is optional):

    sudo apt install nginx certbot python-certbot-nginx 
    
Next, install git to clone our repository(optional, but recommended, without it updates won't work,
you will need to download archive then and extract it)
    
    sudo apt install git
    
Dependences installation finished at that point.

Then, in some folder you want, run:

    git clone https://github.com/MrNaif2018/bitcart-docker
    cd bitcart-docker

It will download repository and change directory to downloaded folder.

Now, for simplicity we won't use systemd or something like that to run our instance, let's use screen:

    sudo apt install screen
    
Then, run screen:

    sudo screen
    
Press enter on appeared screen to enter some type of container.
Now, let's run our bitcart instance!

    sudo docker-compose up
    
From now, it will download all images and set up database and other things.
So from now main setup is done, you can skip recommended nginx setup part.
You will be able to access your instance at
http://your.server.ip.address:8000

Nginx setup(optional)
--------------------
So, first of all you will need your domain to get ssl cerificate for it.
We used free .tk domains from freenom(https://www.freenom.com)
Get your domain here, and then in "My domains" section, select your domain settings and
press "Manage freenom DNS" button
You will need to create A record to your ip address to make your server "own" that domain.
That's how we did it in freenom:
http://i.imgur.com/rXjVoXE.png
Then, wait for a few minutes for DNS changes to apply.
After that, get your ssl certificate:

    sudo certbot --nginx -d yourdomain.tld
   
It will obtain certificate, if there will be some error about NXDOMAIN or A record, wait some more for
DNS changes to apply.
When it asks about modifying webserver configuration, we suggest to answer 2(modify webserver
configuration to make it work only in https).
After that, go to nginx config directory:
    
    cd /etc/nginx/sites-enabled
    
And open file named "default" in your favourite editor, I used joe:

    joe default
    
Next, find a server block with your domain, it will look like so:
http://i.imgur.com/E0XmZg0.png
server_name will be your domain name you had given to certbot with -d parameter, in our case demo.bitcartcc.tk
Comment out using # or delete the line with try_files, and instead write

    proxy_pass http://localhost:8000;

So it will look as on screen or similar.
Next, save your file(how to save the file is not included in this tutorial)).
And run 
    
    sudo nginx -t
    
To check if your config is correct, if not I suggest to first look for
default~ file (note the tilde at end) and remove it using:
    
    sudo rm default~
    
Try again, it might work, if not, you can always contact us in our group.
Then, restart nginx:

    sudo systemctl reload nginx
    
And congratulations! You will now be able to access your bitcart instance at
https://yourdomain.tld!
That's the end of the guide. Note that in future we may include nginx with our docker images, and the whole setup is actually just

    sudo docker-compose up
    
Others can be counted as a "bonus".

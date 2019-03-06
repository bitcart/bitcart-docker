# bitcart-docker

Docker images now available!

Install from docker hub(stable)
------------------------------

Simply run

    docker pull mrnaif/bitcart
    
Development builds
------------------

First, you will need to download latest version of repository and apply some adjustments.
You will also need to create .env file with approciate settings.
You can find .env file specification at main repository.
So, first run  

    ./setup.sh
  
which will download git, clone repository and make needed adjustments. 
If you can't use this shell script, do it manually, 
you can always contact us in our support groups.

After that your environment is ready, simply run

    docker-compose -f docker-compose.dev.yml build 
    
to build the image(bitcart main image), or just run

    docker-compose -f docker-compose.dev.yml up --build
    
to build image and start the containers.

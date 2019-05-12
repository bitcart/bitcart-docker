This directory is for bitcart installers, which provide easiest ever installation.
There are 3 versions of installers at the moment:
- console
- gui(qt)
- telegram(bot)

To launch any of these versions, you will need to install it's dependencies.
You can find them in requirements folder of current directory.
So, for example, to install dependencies for console version, which is called
cli.py, you will need to run

    pip3 install -r requirements/cli.txt
  
The same for other files.
Telegram bot versions requires python >= 3.7, others require a supported python 3 version(3.6 and more recommended).
To run telegram bot, you'll need bot token, get it from @BotFather on telegram.
After that, run telegram bot using

    python3 telegram.py
  
It will ask you for telegram token.
Or, set TELEGRAM_TOKEN environment variable:

On Linux(Mac OS):

    export TELEGRAM_TOKEN=mytoken
  
On Windows:

    set TELEGRAM_TOKEN=mytoken
    

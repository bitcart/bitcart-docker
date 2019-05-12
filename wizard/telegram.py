import logging

from aiogram import Bot, Dispatcher, executor, types
from aiogram.dispatcher import FSMContext
from aiogram.contrib.fsm_storage.memory import MemoryStorage
from aiogram.contrib.fsm_storage.redis import RedisStorage
from aiogram.dispatcher.filters.state import State, StatesGroup
from aiogram.utils.markdown import code
import asyncio
import core
import traceback
import functools
import os
import sys


def get_or_ask(var, ask=False, cast=str):
    value = os.environ.get(var)
    if value:
        return value
    else:
        if ask:
            value = input("Enter {}: ".format(var))
            try:
                value = cast(value)
            except (ValueError, TypeError):
                print("Invalid value entered for {}, must be type {}".format(var, cast))
                sys.exit(1)
            return value
        else:
            print("Please set {} environment variable".format(var))
            sys.exit(1)


API_TOKEN = get_or_ask("TELEGRAM_TOKEN", ask=True)

# Configure logging
logging.basicConfig(level=logging.INFO)

# Initialize bot and dispatcher
bot = Bot(token=API_TOKEN, parse_mode="markdown")
storage = MemoryStorage()
dp = Dispatcher(bot, storage=storage)


class Install(StatesGroup):
    ip = State()
    user = State()
    password = State()
    domain = State()
    start = State()


@dp.message_handler(commands=["start", "help"])
async def echo(message: types.Message):
    await bot.send_message(message.chat.id, '''Hello!
I am Bitcart installation bot. I will help you to install bitcart on your server!
Type /install for me to ask you installation details!''')


@dp.message_handler(commands=["install"])
async def install(message: types.Message):
    await Install.ip.set()
    await bot.send_message(message.chat.id, "Send me your server ip address:")


@dp.message_handler(state=Install.ip)
async def process_ip(message: types.Message, state: FSMContext):
    async with state.proxy() as data:
        data['ip'] = message.text

    await Install.next()
    await bot.send_message(message.chat.id, "User:")


@dp.message_handler(state=Install.user)
async def process_user(message: types.Message, state: FSMContext):
    async with state.proxy() as data:
        data['user'] = message.text

    await Install.next()
    await bot.send_message(message.chat.id, "Password:")


@dp.message_handler(state=Install.password)
async def process_password(message: types.Message, state: FSMContext):
    async with state.proxy() as data:
        data['password'] = message.text

    await Install.next()
    await bot.send_message(message.chat.id, "Domain:")


@dp.message_handler(state=Install.domain)
async def process_domain(message: types.Message, state: FSMContext):
    async with state.proxy() as data:
        data['domain'] = message.text
    await Install.next()
    await bot.send_message(message.chat.id, "Do you want to start bitcart after installation?(Y/N)")


@dp.message_handler(state=Install.start)
async def process_start(message: types.Message, state: FSMContext):
    async with state.proxy() as data:
        data['start'] = message.text
        try:
            await bot.send_message(message.chat.id, "Starting installation, please wait...")
            core.connect(data['ip'], data['user'], data['password'], functools.partial(
                print, file=open(os.devnull, 'w')), core.verify_install_bitcart(data['start']), data['domain'])
            if core.verify_install_bitcart(data['start']):
                await bot.send_message(message.chat.id, "Successfully started bitcart!")
            else:
                await bot.send_message(message.chat.id, "Successfully installed bitcart!")
        except Exception:
            await bot.send_message(message.chat.id, "Error connecting to server/installing.\n"+code(traceback.format_exc().splitlines()[-1]))
        data.state = None


if __name__ == '__main__':
    executor.start_polling(dp)

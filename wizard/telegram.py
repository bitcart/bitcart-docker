import functools
import logging
import os
import sys
import traceback

import core
from aiogram import Bot, Dispatcher, executor, types
from aiogram.contrib.fsm_storage.memory import MemoryStorage
from aiogram.dispatcher import FSMContext
from aiogram.dispatcher.filters.state import State, StatesGroup
from aiogram.utils.markdown import hcode


def get_or_ask(var, ask=False, cast=str):
    value = os.environ.get(var)
    if value:
        return value
    else:
        if ask:
            value = input(f"Enter {var}: ")
            try:
                value = cast(value)
            except (ValueError, TypeError):
                print(f"Invalid value entered for {var}, must be type {cast}")
                sys.exit(1)
            return value
        else:
            print(f"Please set {var} environment variable")
            sys.exit(1)


API_TOKEN = get_or_ask("TELEGRAM_TOKEN", ask=True)

# Configure logging
logging.basicConfig(level=logging.INFO)

# Initialize bot and dispatcher
bot = Bot(token=API_TOKEN, parse_mode="html")
storage = MemoryStorage()
dp = Dispatcher(bot, storage=storage)


Install = type("Install", (StatesGroup,), {key: State() for key in core.texts.keys()})
states = list(core.texts.keys())
texts = list(core.texts.values())
for ind, item in enumerate(texts):
    if item == core.texts["user"]:
        texts[ind] = "Enter username: "


@dp.message_handler(commands=["start", "help"])
async def echo(message: types.Message):
    await bot.send_message(
        message.chat.id,
        """Hello!
I am Bitcart installation bot. I will help you to install bitcart on your server!
Type /install for me to ask you installation details!""",
    )


@dp.message_handler(commands=["install"])
async def install(message: types.Message):
    await getattr(Install, states[0]).set()
    await bot.send_message(message.chat.id, texts[0])


def make_func(name, pos):
    async def process(message: types.Message, state: FSMContext):
        cont = True
        skip = 0
        install = None
        async with state.proxy() as data:
            value = message.text
            if not value:
                value = core.defaults.get(states[pos], "")
            if states[pos] in core.defaults and value.lower() == "default":
                value = core.defaults.get(states[pos], "")
            data[states[pos]] = value
            if "install" in data:
                install = data["install"]
            for check in core.checks:
                if states[pos + 1] in check["vars"]:
                    args = [data[key] for key in check["args"]]
                    if not check["check"](*args):
                        cont = False
                        skip += len(check["vars"])
                        break
        if cont:
            await Install.next()
        else:
            if install not in ["backend", "frontend", "all"] and states[pos + skip + 1] == "api_domain":
                skip += 3
            for _ in range(skip + 1):
                await Install.next()
        await bot.send_message(message.chat.id, texts[pos + skip + 1])

    process.__name__ = name
    return process


pos = 0
for var, text in list(core.texts.items())[:-1]:
    dp.message_handler(state=getattr(Install, var))(make_func(f"process_{var}", pos))
    pos += 1


@dp.message_handler(state=Install.start_bitcart)
async def process_start(message: types.Message, state: FSMContext):
    async with state.proxy() as data:
        data["start_bitcart"] = core.defaults["start_bitcart"] if message.text == "default" else message.text
        try:
            await bot.send_message(message.chat.id, "Starting installation, please wait...")
            kwargs = {key: data[key] for key in core.texts if key in data}
            kwargs["print_func"] = functools.partial(print, file=open(os.devnull, "w"))
            kwargs.pop("onedomain_mode", None)
            core.connect(**kwargs)
            if core.verify_install_bitcart(data["start_bitcart"]):
                await bot.send_message(message.chat.id, "Successfully started bitcart!")
            else:
                await bot.send_message(message.chat.id, "Successfully installed bitcart!")
        except Exception:
            await bot.send_message(
                message.chat.id,
                "Error connecting to server/installing.\n" + hcode(traceback.format_exc().splitlines()[-1]),
            )
        data.state = None


if __name__ == "__main__":
    executor.start_polling(dp)

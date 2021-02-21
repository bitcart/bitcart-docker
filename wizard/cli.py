import getpass

import core

for var, text in core.texts.items():
    cont = True
    for check in core.checks:
        if var in check["vars"]:
            args = [globals()[key] for key in check["args"]]
            if not check["check"](*args):
                cont = False
                break
    if not cont:
        continue
    text = text.format(username=getpass.getuser())
    if var in ["password", "store_pass"]:
        val = getpass.getpass(text)
    else:
        val = input(text)
    val = val or core.defaults.get(var, "")
    globals()[var] = val
kwargs = {key: globals()[key] for key in core.texts if key in globals()}
kwargs["print_func"] = print
kwargs.pop("onedomain_mode", None)
core.connect(**kwargs)

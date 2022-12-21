for org in modules/*; do
    if [[ -d "$org" && ! -L "$org" ]]; then
        for plugin in "$org"/*; do
            if [[ -d "$plugin" && ! -L "$plugin" ]]; then
                echo "Installing $plugin"
                # check if file  exists first
                if [ -f "$plugin/requirements.txt" ]; then
                    pip install -r "$plugin/requirements.txt"
                fi
            fi
        done
    fi
done

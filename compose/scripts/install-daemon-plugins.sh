for org in modules/*; do
    if [[ -d "$org" && ! -L "$org" ]]; then
        for plugin in "$org"/*; do
            if [[ -d "$plugin" && ! -L "$plugin" ]]; then
                echo "Installing $plugin"
                # Copy all dirs to daemons folder
                cp -r $plugin/* daemons/
                # apply all patches from patches dir
                if [[ -d "$plugin/patches" ]]; then
                    for patch in "$plugin/patches"/*; do
                        if [ -f "$patch" ]; then
                            git apply "$patch"
                        fi
                    done
                fi
            fi
        done
    fi
done

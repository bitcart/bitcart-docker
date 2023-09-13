found=false
for org in modules/*; do
    if [ -d "$org" ]; then
        for plugin in "$org"/*; do
            if [ -d "$plugin" ]; then
                if [ "$plugin" = "modules/@bitcart/core" ]; then
                    continue
                fi
                found=true
                echo "Installing $plugin"
                if [ -f "$plugin/package.json" ]; then
                    cd "$plugin"
                    yarn
                    cd $OLDPWD
                fi
            fi
        done
    fi
done

if [ "$found" = false ]; then
    echo "No plugins found"
else
    echo "Plugins installed, re-building"
    yarn build
    yarn cache clean
fi

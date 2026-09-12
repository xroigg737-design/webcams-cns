#!/bin/bash
# Setup Avui Regu? — Clona el repo i obre Claude Code
# Ús: curl -sL https://raw.githubusercontent.com/xroigg737-design/webcams-cns/master/setup.sh | bash

REPO="https://github.com/xroigg737-design/webcams-cns.git"
DIR="webcams-cns"

if [ -d "$DIR" ]; then
    echo "Actualitzant repo existent..."
    cd "$DIR" && git pull origin master
else
    echo "Clonant repo..."
    git clone "$REPO" && cd "$DIR"
fi

echo ""
echo "Llest! Ara executa:"
echo "  cd $DIR && claude"

#!/bin/bash
# ---------------------------------------------------------------
# Desplega la versió de DESENVOLUPAMENT d'Avui Regu al servidor AWS
#   → https://i-xr.duckdns.org/avui-regu-dev/
#
# NO toca producció:
#   - GitHub Pages (xroigg737-design.github.io/webcams-cns) queda igual
#   - /var/www/html/avui-regu del servidor queda igual
#
# Ús:  ./deploy-dev.sh          (ràpid, sense vídeos)
#      ./deploy-dev.sh --full   (inclou la carpeta video/, 22 MB)
# ---------------------------------------------------------------
set -e
cd "$(dirname "$0")"

KEY=~/AWS/claus/la-meva-clau-ubuntu.pem
REMOTE="ubuntu@13.63.16.49"
REMOTE_DIR="/var/www/html/avui-regu-dev/"
ST=$(mktemp -d)
trap 'rm -rf "$ST"' EXIT

echo "Preparant còpia dev..."
cp index.html cockpit.html regu.html 404.html favicon.ico manifest.json paleta-windy.html "$ST/"
cp -r img "$ST/"
[ "$1" = "--full" ] && cp -r video "$ST/"

python3 - "$ST" <<'PY'
import sys, os
st = sys.argv[1]
p = os.path.join(st, 'index.html')
s = open(p).read()
# Sense service worker: en dev sempre volem l'últim canvi, sense caché
a = s.find("    <script>\n    if ('serviceWorker' in navigator)")
if a != -1:
    b = s.index("</script>", a) + len("</script>\n")
    s = s[:a] + "    <!-- Service worker desactivat en l'entorn de desenvolupament -->\n" + s[b:]
# Marca DEV visible
import re
s = re.sub(r'<div class="subtitle">(v[0-9.]+)</div>',
           r'<div class="subtitle">\1 &middot; <span style="color:#ffd740;font-weight:800;letter-spacing:2px;">DEV</span></div>', s)
s = s.replace('<title>Avui Regu ? - Sitges</title>', '<title>Avui Regu ? - Sitges [DEV]</title>')
open(p, 'w').write(s)
PY

echo "Pujant a $REMOTE_DIR ..."
rsync -az --info=stats1 -e "ssh -i $KEY" "$ST/" "$REMOTE:$REMOTE_DIR"
echo "Fet → https://i-xr.duckdns.org/avui-regu-dev/"

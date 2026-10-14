#!/usr/bin/env bash
# =====================================================================
#  Layout "Italiano (Mac 2016 - perfeito)" para Ubuntu
#  Reproduz o teclado italiano Mac (etiqueta "US 2016-MAC-IT")
#
#  Uso:
#     bash instalar-teclado-it-mac.sh            -> instala e ativa
#     bash instalar-teclado-it-mac.sh --remover  -> desinstala
#
#  AltGr = tecla Alt direita (option direito)
# =====================================================================
set -euo pipefail

LAYOUT="itmacpro"
DESC="Italian (Mac 2016, perfect)"
SYM_DIR="/usr/share/X11/xkb/symbols"
RULES_DIR="/usr/share/X11/xkb/rules"

# ---------------------------------------------------------------------
# Remoção
# ---------------------------------------------------------------------
if [[ "${1:-}" == "--remover" ]]; then
    sudo rm -f "$SYM_DIR/$LAYOUT"
    for f in evdev.xml base.xml; do
        [[ -f "$RULES_DIR/$f.bak-$LAYOUT" ]] && sudo cp "$RULES_DIR/$f.bak-$LAYOUT" "$RULES_DIR/$f"
    done
    if command -v gsettings >/dev/null; then
        gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'it')]"
    fi
    command -v setxkbmap >/dev/null && setxkbmap it 2>/dev/null || true
    echo "Layout removido. Voltou para Italiano padrão."
    exit 0
fi

# ---------------------------------------------------------------------
# 1) Arquivo de símbolos
# ---------------------------------------------------------------------
echo ">> Gravando $SYM_DIR/$LAYOUT"
sudo tee "$SYM_DIR/$LAYOUT" >/dev/null <<'EOF'
// Italiano Mac 2016 - layout "perfeito"
//  [ normal, Shift, AltGr, AltGr+Shift ]
default partial alphanumeric_keys
xkb_symbols "basic" {

    name[Group1] = "Italian (Mac 2016, perfect)";

    // ---- Linha dos números -------------------------------------
    key <TLDE> { [ less,        greater,     backslash,   bar         ] };
    key <AE01> { [ 1,           exclam                                ] };
    key <AE02> { [ 2,           quotedbl                              ] };
    key <AE03> { [ 3,           sterling                              ] };
    key <AE04> { [ 4,           dollar                                ] };
    key <AE05> { [ 5,           percent                               ] };
    key <AE06> { [ 6,           ampersand                             ] };
    key <AE07> { [ 7,           slash                                 ] };
    key <AE08> { [ 8,           parenleft                             ] };
    key <AE09> { [ 9,           parenright                            ] };
    key <AE10> { [ 0,           equal                                 ] };
    key <AE11> { [ apostrophe,  question,    grave                    ] };
    key <AE12> { [ igrave,      asciicircum, asciitilde               ] };

    // ---- Linha QWERTY ------------------------------------------
    key <AD01> { [ q, Q ] };
    key <AD02> { [ w, W ] };
    key <AD03> { [ e, E,        EuroSign                              ] };
    key <AD04> { [ r, R ] };
    key <AD05> { [ t, T ] };
    key <AD06> { [ y, Y ] };
    key <AD07> { [ u, U ] };
    key <AD08> { [ i, I ] };
    key <AD09> { [ o, O ] };
    key <AD10> { [ p, P ] };
    key <AD11> { [ egrave,      eacute,      bracketleft,  braceleft  ] };
    key <AD12> { [ plus,        asterisk,    bracketright, braceright ] };
    key <BKSL> { [ ugrave,      section                               ] };

    // ---- Linha ASDF --------------------------------------------
    key <AC01> { [ a, A ] };
    key <AC02> { [ s, S ] };
    key <AC03> { [ d, D ] };
    key <AC04> { [ f, F ] };
    key <AC05> { [ g, G ] };
    key <AC06> { [ h, H ] };
    key <AC07> { [ j, J ] };
    key <AC08> { [ k, K ] };
    key <AC09> { [ l, L ] };
    key <AC10> { [ ograve,      ccedilla,    at                       ] };
    key <AC11> { [ agrave,      degree,      numbersign               ] };

    // ---- Linha ZXCV --------------------------------------------
    key <AB01> { [ z, Z ] };
    key <AB02> { [ x, X ] };
    key <AB03> { [ c, C ] };
    key <AB04> { [ v, V ] };
    key <AB05> { [ b, B ] };
    key <AB06> { [ n, N ] };
    key <AB07> { [ m, M ] };
    key <AB08> { [ comma,       semicolon                             ] };
    key <AB09> { [ period,      colon                                 ] };
    key <AB10> { [ minus,       underscore                            ] };

    // Se o kernel reportar a tecla do "<" como LSGT (comum em Mac)
    key <LSGT> { [ less,        greater,     backslash,   bar         ] };

    include "level3(ralt_switch)"
};
EOF

# ---------------------------------------------------------------------
# 2) Registrar o layout (para aparecer em Configurações > Teclado)
# ---------------------------------------------------------------------
for f in evdev.xml base.xml; do
    XML="$RULES_DIR/$f"
    [[ -f "$XML" ]] || continue
    [[ -f "$XML.bak-$LAYOUT" ]] || sudo cp "$XML" "$XML.bak-$LAYOUT"
    echo ">> Registrando em $XML"
    sudo python3 - "$XML" "$LAYOUT" "$DESC" <<'PY'
import sys
path, name, desc = sys.argv[1:4]
s = open(path, encoding="utf-8").read()
if f"<name>{name}</name>" not in s:
    block = f"""    <layout>
      <configItem>
        <name>{name}</name>
        <shortDescription>it</shortDescription>
        <description>{desc}</description>
        <languageList><iso639Id>ita</iso639Id></languageList>
      </configItem>
    </layout>
  </layoutList>"""
    s = s.replace("</layoutList>", block.strip(), 1)
    open(path, "w", encoding="utf-8").write(s)
PY
done

# Limpa cache de mapas compilados
sudo rm -f /var/lib/xkb/*.xkm 2>/dev/null || true

# ---------------------------------------------------------------------
# 3) Ativar
# ---------------------------------------------------------------------
if command -v gsettings >/dev/null; then
    echo ">> Ativando no GNOME"
    gsettings set org.gnome.desktop.input-sources sources "[('xkb', '$LAYOUT')]"
fi
if [[ "${XDG_SESSION_TYPE:-}" == "x11" ]] && command -v setxkbmap >/dev/null; then
    setxkbmap "$LAYOUT"
fi

echo
echo "Pronto! Layout '$DESC' ativo."
echo "Se estiver no Wayland e não mudar na hora, faça logout/login."
echo "Após atualização do pacote xkb-data, rode este script de novo."

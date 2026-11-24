#!/usr/bin/env bash
# gnome-debloat — corta serviços do Fedora Workstation (GNOME) por grupos numerados.
# Uso: sudo ./gnome-debloat.sh [--dry-run] [--list] <grupos>   (ex: 1,3,8 | all)
# 'all' roda só os grupos seguros (marcados com *); os outros precisam ser pedidos.
# Sem restore automático:
#   sudo dnf install $(cat /var/lib/gnome-debloat/removed.txt)
#   sudo systemctl unmask $(cat /var/lib/gnome-debloat/mascarados.txt)
#   sudo systemctl --global unmask $(cat /var/lib/gnome-debloat/mascarados-user.txt)
#   sudo rm -f $(cat /var/lib/gnome-debloat/arquivos.txt)
set -uo pipefail
LOG_DIR=${LOG_DIR:-/var/lib/gnome-debloat}
NFT_REGRAS=${NFT_REGRAS:-/etc/nftables/gnome-debloat.nft}
NFT_CONF=${NFT_CONF:-/etc/sysconfig/nftables.conf}

# Papel fixo na sessão, no login ou nos repos: nunca saem (mesmo se pedidos).
readonly PROTECTED=(
  gnome-shell gnome-session gnome-settings-daemon gnome-control-center gdm mutter
  NetworkManager polkit accountsservice udisks2 gvfs xdg-desktop-portal
  xdg-desktop-portal-gnome xdg-desktop-portal-gtk switcheroo-control geoclue2
  evolution-data-server pipewire wireplumber dbus-broker systemd sudo dnf5 rpm
  glibc kernel-core ibus rtkit
)
readonly GRUPOS=(
  ''
  '1* servicos    auditd, ModemManager, systemd-homed, unbound-anchor, mcelog, mdraid, iscsi, sssd-kcm'
  '2* energia     troca tuned + tuned-ppd pelo power-profiles-daemon (pulado se o TLP estiver instalado)'
  '3* gnome-sw    GNOME Software não sobe mais no login (abre sob demanda)'
  '4* indexador   localsearch (tracker): para de indexar'
  '5* a11y        orca e speech-dispatcher (leitor de tela)'
  '6* vmguest     open-vm-tools, virtualbox-guest-additions, spice-vdagent (só em máquina física)'
  '7  calendario  evolution-data-server (agenda/contatos de fundo) — só mascara'
  '8  print       cups, hplip, filtros e o aviso de impressora'
  '9  avahi       mDNS/DNS-SD (descoberta de impressora e nomes .local)'
  '10 tempo       troca chrony pelo systemd-timesyncd (sem NTS)'
  '11 firewall    troca o firewalld (daemon python) por regras nftables equivalentes'
  '12 ibus-motores ibus-typing-booster (python residente) e motores asiáticos não usados'
  '13 smartcard   pcscd + opensc (leitor de cartão/token); o gsd-smartcard do GNOME continua'
)
# Ganho em MB de PSS no idle, medido em VM Fedora 45 com reboot (docs/servicos-gnome.md); ruído ~4 MB.
declare -A GANHO=([1]=10 [2]=31 [3]=330 [4]=10 [5]=0 [6]='0 (VM)' [7]=46 [8]=8 [9]='0 (ruído)' [10]=0 [11]=27 [12]=77 [13]=1)
declare -A PERDA=(
  [1]='trilha de auditoria (auditd); modem 3G/4G, usuário systemd-homed e RAID por software ficam se estiverem em uso'
  [2]='o tuning do tuned (governor, ALPM do disco, powersave de áudio, sysctl); sobra o seletor de perfil do ppd'
  [3]='aviso de atualização e refresh em segundo plano; abrir o app continua funcionando'
  [4]='busca de arquivos por conteúdo e por tag no Nautilus/Shell, fotos e músicas indexadas'
  [5]='leitor de tela e fala sintetizada'
  [6]='área de transferência, resize e mouse integrados do hypervisor (a máquina virtual é detectada e o grupo é pulado)'
  [7]='eventos no menu de data, GNOME Calendar/Contacts/Evolution e sincronização de agenda das contas online'
  [8]='imprimir e escanear com driver HP/Gutenprint; o aviso de impressora some'
  [9]='achar impressora e compartilhamento na rede por nome; resolução de host.local'
  [10]='NTS e a precisão do chrony (timesyncd é só SNTP)'
  [11]='a zona FedoraWorkstation: sobra ssh, mDNS e dhcpv6 de entrada, portas 1025-65535 fecham; perde firewall-config/cmd'
  [12]='digitação com sugestão/emoji por texto (typing-booster) e entrada chinês/japonês/coreano/indiano se você usa; o ibus e o teclado normal ficam'
  [13]='login e PIV/PKCS#11 com cartão ou token (YubiKey PIV, e-CPF/e-CNPJ no navegador); GPG por smartcard usa scdaemon direto e pode precisar do pcscd'
)

dry=0
usage() { sed -n '2,/^set -/p' "$0" | sed '$d'; echo
  local i; for i in $(seq 1 $(( ${#GRUPOS[@]} - 1 ))); do
    printf '%s\n     ganha ~%s MB | perde: %s\n' "${GRUPOS[$i]}" "${GANHO[$i]}" "${PERDA[$i]}"; done; }

# registra o que foi feito, para o restore
log() { [ "$dry" = 1 ] || { mkdir -p "$LOG_DIR"; printf '%s\n' "${@:2}" >> "$LOG_DIR/$1"; }; }
run() { if [ "$dry" = 1 ]; then echo "  [dry] $*"; else "$@"; fi; }

# mascara unit de sistema (para na hora). Só se a unit existe e não está mascarada.
mask() { local u
  for u in "$@"; do
    systemctl cat "$u" >/dev/null 2>&1 || continue
    [ "$(systemctl is-enabled "$u" 2>/dev/null)" = masked ] && continue
    run systemctl mask --now "$u" >/dev/null 2>&1 && { log mascarados.txt "$u"; echo "  mask $u"; }
  done; }
# mascara unit de usuário para todos os usuários (vale no próximo login)
mask_user() { local u
  for u in "$@"; do
    [ -e "/usr/lib/systemd/user/$u" ] || continue
    [ -L "/etc/systemd/user/$u" ] && continue
    run systemctl --global mask "$u" >/dev/null 2>&1 && { log mascarados-user.txt "$u"; echo "  mask --global $u"; }
  done; }
# remove pacotes que existem e não estão na PROTECTED. Pacote exigido por outro some junto
# só se o dnf pedir (--assumeyes): por isso a conferência de protegidos vem antes.
remove() { local p keep=() prot
  for p in "$@"; do
    rpm -q "$p" >/dev/null 2>&1 || continue
    for prot in "${PROTECTED[@]}"; do [ "$p" = "$prot" ] && { echo "  PROTEGIDO: $p fica"; continue 2; }; done
    keep+=("$p")
  done
  [ "${#keep[@]}" -gt 0 ] || return 0
  # derrubaria um protegido? então o dnf recusa sozinho (protected_packages do gnome-shell)
  if [ "$dry" = 1 ]; then echo "  [dry] dnf remove ${keep[*]}"; return 0; fi
  # o dnf5 grava a lista exata, dependentes incluídos
  dnf remove --assumeyes "${keep[@]}" 2>&1 | tee /tmp/gnome-debloat-dnf.log | tail -3
  log removed.txt "${keep[@]}"; }
vm() { [ "$(systemd-detect-virt 2>/dev/null)" != none ]; }

g1() { # auditd tem RefuseManualStop: mask vale no próximo boot. audit-rules (oneshot) fica,
  # senão o journald audita cada syscall.
  mask auditd.service ModemManager.service systemd-homed.service systemd-homed-activate.service \
       systemd-homed-firstboot.service unbound-anchor.timer mcelog.service raid-check.timer \
       mdmonitor.service iscsid.socket iscsiuio.socket iscsi-starter.service iscsi-onboot.service \
       sssd-kcm.socket; }
g2() { rpm -q power-profiles-daemon >/dev/null 2>&1 && return 0
  # o UFWPS tira o ppd de propósito quando instala o TLP (os dois brigam pelo governor/EPP)
  rpm -q tlp >/dev/null 2>&1 && { echo "  TLP instalado: o ppd não entra, pulado"; return 0; }
  # tuned-ppd provê o mesmo ppd-service: --allowerasing troca um pelo outro
  run dnf install --assumeyes --allowerasing power-profiles-daemon 2>&1 | tail -2
  log removed.txt tuned-ppd; log instalados.txt power-profiles-daemon
  remove tuned
  run systemctl enable --now power-profiles-daemon.service >/dev/null 2>&1; }
g3() { # mask quebraria o app: o D-Bus ativa o gnome-software.service. Copia o target sem o Wants:
  # o serviço deixa de subir no login mas segue ativável ao abrir o app (copia não recebe update do pacote).
  local alvo=gnome-session-services.target
  [ -e "/etc/systemd/user/$alvo" ] && return 0
  grep -q '^Wants=gnome-software.service' "/usr/lib/systemd/user/$alvo" || return 0
  if [ "$dry" = 1 ]; then echo "  [dry] /etc/systemd/user/$alvo sem Wants=gnome-software.service"; return 0; fi
  mkdir -p /etc/systemd/user
  sed '/^Wants=gnome-software.service/d' "/usr/lib/systemd/user/$alvo" > "/etc/systemd/user/$alvo"
  log arquivos.txt "/etc/systemd/user/$alvo"; echo "  target sem gnome-software"; }
g4() { mask_user localsearch-3.service localsearch-control-3.service; }
g5() { remove orca speech-dispatcher speech-dispatcher-espeak-ng espeak-ng brltty; }
g6() { vm && [ -z "${FORCE_VM:-}" ] && { echo "  máquina virtual detectada: pulado"; return 0; }
  remove open-vm-tools open-vm-tools-desktop virtualbox-guest-additions spice-vdagent spice-webdavd qemu-guest-agent; }
g7() { mask_user evolution-source-registry.service evolution-calendar-factory.service \
       evolution-addressbook-factory.service evolution-alarm-notify.service; }
g8() { remove cups cups-filters cups-browsed hplip gutenprint-cups bluez-cups
  mask_user org.gnome.SettingsDaemon.PrintNotifications.service; }
g9() { mask avahi-daemon.service avahi-daemon.socket; }
g10() { run systemctl enable --now systemd-timesyncd.service >/dev/null 2>&1; mask chronyd.service
  remove chrony; }
g11() { local p
  rpm -q nftables >/dev/null 2>&1 || run dnf install --assumeyes nftables >/dev/null 2>&1
  # as portas que o usuário abriu além do padrão da zona Workstation: avisa, não migra
  for p in $(firewall-cmd --list-ports 2>/dev/null); do [ "$p" = 1025-65535/tcp ] || [ "$p" = 1025-65535/udp ] || echo "  AVISO: porta $p aberta no firewalld não migrou"; done
  if [ "$dry" != 1 ]; then
    mkdir -p "$(dirname "$NFT_REGRAS")"
    cat > "$NFT_REGRAS" <<'NFT'
table inet gnome_debloat
delete table inet gnome_debloat
table inet gnome_debloat {
  chain input {
    type filter hook input priority filter; policy drop;
    ct state established,related accept
    ct state invalid drop
    iif lo accept
    meta l4proto { icmp, ipv6-icmp } accept
    tcp dport 22 accept
    udp dport 5353 accept
    udp dport 546 accept
  }
  chain forward { type filter hook forward priority filter; policy drop; }
}
NFT
    grep -q "$NFT_REGRAS" "$NFT_CONF" 2>/dev/null || echo "include \"$NFT_REGRAS\"" >> "$NFT_CONF"
    nft -f "$NFT_REGRAS" && systemctl enable nftables.service >/dev/null 2>&1
  fi
  mask firewalld.service
  remove firewalld python3-firewall firewall-config firewall-applet; }

# o typing-booster fica residente (~100 MB) mesmo sem estar nas fontes de entrada; nada o exige.
# Só sai o que não está em org.gnome.desktop.input-sources: motores do ibus em uso são mantidos.
g12() { local e p fontes
  fontes=$(sudo -u "${SUDO_USER:-root}" gsettings get org.gnome.desktop.input-sources sources 2>/dev/null)
  for p in ibus-typing-booster ibus-anthy ibus-hangul ibus-libpinyin ibus-m17n ibus-chewing; do
    e=${p#ibus-}; [[ "$fontes" == *"$e"* ]] && { echo "  $p em uso nas fontes de entrada: fica"; continue; }
    remove "$p"; done; }

# pcsc-lite-libs fica: o gsd-smartcard do GNOME e o p11-kit ligam nela. Só some o daemon e o módulo PKCS#11.
g13() { remove pcsc-lite opensc; }

grupos=()
for a in "$@"; do case "$a" in
  --dry-run) dry=1 ;; --list|-h|--help) usage; exit 0 ;;
  all) grupos+=(1 2 3 4 5 6) ;;
  *) IFS=, read -ra x <<<"$a"; grupos+=("${x[@]}") ;; esac; done
[ "${#grupos[@]}" -gt 0 ] || { usage; exit 1; }
[ "$dry" = 1 ] || [ "$(id -u)" = 0 ] || { echo "rode com sudo"; exit 1; }

for g in "${grupos[@]}"; do
  [[ "$g" =~ ^([1-9]|1[0-3])$ ]] || { echo "grupo inválido: $g"; exit 1; }
  echo "== grupo $g: $(sed 's/  */ /g' <<<"${GRUPOS[$g]}" | cut -d' ' -f2)"
  "g$g"
done
echo "pronto. Reinicie para os serviços de usuário e o auditd saírem da memória."

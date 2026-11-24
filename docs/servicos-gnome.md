# Serviços do Fedora Workstation (GNOME): o que sai e o que fica

Medido em VM Fedora 45 Workstation limpa (QEMU/KVM, 4 GB, AMD passthrough). PSS somado de todos os processos no idle,
com reboot e ~170 s de espera antes de cada medição; ruído ~4 MB. Script: `gnome-debloat.sh` (`--list`, `--dry-run`,
`all` = grupos 1–6). Restore: cabeçalho do script (estado em `/var/lib/gnome-debloat/`).

Total com todos os grupos: **1218 → 679 MB (−539 MB, −44%)**.

## Grupos

| Grupo | O que faz | Ganho (MB) | Em `all` | Perde |
|---|---|---|---|---|
| 1 servicos | mascara auditd, ModemManager, systemd-homed, unbound-anchor, mcelog, mdraid, iscsi, sssd-kcm | 10 | sim | trilha de auditoria; modem, homed e RAID se em uso |
| 2 energia | tuned + tuned-ppd → power-profiles-daemon (mesma API D-Bus) | 31 | sim | tuning do tuned; pulado se o TLP está instalado |
| 3 gnome-sw | gnome-software deixa de subir no login (abre sob demanda) | 330 | sim | refresh e aviso de update em segundo plano |
| 4 indexador | mascara localsearch (tracker) | 10 | sim | busca por conteúdo |
| 5 a11y | remove orca, speech-dispatcher | 0 (só disco) | sim | leitor de tela |
| 6 vmguest | remove agentes de VM (pulado em VM) | 0 | sim | integração do hypervisor |
| 7 calendario | mascara evolution-source-registry e factories | 46 | não | agenda no menu de data, Calendar/Contacts |
| 8 print | remove cups, hplip, filtros | 8 | não | impressão/escaneamento |
| 9 avahi | mascara avahi | ~1 | não | descoberta mDNS (impressora, .local) |
| 10 tempo | chrony → systemd-timesyncd | ~1 | não | NTS |
| 11 firewall | firewalld → tabela nftables equivalente | 27 | não | zona FedoraWorkstation (portas 1025-65535 fecham) |
| 12 ibus-motores | remove ibus-typing-booster e motores CJK/indic fora das fontes de entrada | 77 | não | digitação com sugestão/emoji, CJK |
| 13 smartcard | remove pcsc-lite + opensc (mantém pcsc-lite-libs) | ~1 | não | login/PIV/PKCS#11 com cartão ou token |

Por que alguns dão ~0: orca, speech-dispatcher e agentes de VM não rodam no idle (ganho só em disco, e a VM QEMU
não tem vbox/vmware/spice); avahi (~1 MB) e chrony (~2 MB, trocado por timesyncd ~1 MB) estão no ruído.

**Grupo 3.** Mascarar `gnome-software.service` quebra o app: o D-Bus (`org.gnome.Software.service`,
`SystemdService=gnome-software.service`) o ativa por essa unit. Em vez disso o script copia
`gnome-session-services.target` para `/etc/systemd/user` sem o `Wants=gnome-software.service`. Verificado: após o
reboot o processo não existe; uma chamada D-Bus o ativa (183 MB + dnf5daemon-server) e o app abre. A cópia não recebe
updates do pacote; o restore apaga o arquivo.

**Grupo 12.** A/B com reinstalação entre as medições: com typing-booster 758 MB, sem 681 MB. É um processo Python
residente (~100 MB) mesmo com as fontes de entrada só em `xkb us`. Nada o exige; remove 21 pacotes (196 MB em disco).

## Não removidos (PROTECTED ou sem ganho)

| Serviço | Motivo |
|---|---|
| geoclue2, evolution-data-server, switcheroo-control | o dnf recusa: derrubaria o gnome-shell (via goa, gvfs, udisks2) |
| mdadm | exigido pelo udisks2 |
| NetworkManager, polkit, accountsservice, udisks2, xdg-desktop-portal-gtk/gnome | papel fixo na sessão |
| Xwayland, mutter-x11-frames, ibus-x11 | sobem só quando existe cliente X11 (não ficam no idle); medidos só enquanto um app X11 estava aberto |
| gvfs-afc/gphoto2/mtp/smb | ~1 MB; perde iPhone/câmera/Android/SMB |
| colord, gssproxy, upower, uresourced, systemd-oomd, wpa_supplicant | 2–3 MB e têm dependentes (gsd, nfs, NM-wifi) |
| gnome-software, firewalld, cups | cascatas: cups arrasta hplip/bluez-cups/gutenprint; avahi arrasta nss-mdns |

## Conflitos com o UFWPS.sh

| Ponto do UFWPS.sh | Conflito? |
|---|---|
| TLP (`remove power-profiles-daemon tuned tuned-ppd`, depois `install tlp`) | **Sim, no grupo 2.** O pacote tlp conflita só com tuned e laptop-mode-tools, mas ppd e TLP disputam governor/EPP. O g2 agora pula se o TLP está instalado (testado). Se o g2 rodar antes, o UFWPS remove o ppd por conta própria |
| `dnf group upgrade core` (core inclui firewalld) | Não: `--assumeno` só mostra upgrades, nada reinstalado após o g11 |
| `dnf update`, `upgrade @multimedia`, `autoremove` | Não: nenhum pacote removido volta (verificado em dry-run) |
| Opção de manter/remover gnome-software | Não: o g3 só edita o target; sem o pacote o Wants= é inócuo |
| `NetworkManager-wait-online` desativado, `set-local-rtc 0` | Não |
| TLP mascara systemd-rfkill; g1 mascara ModemManager | Não |

Ressalva: `dnf group install core` (instalação nova, não upgrade) reinstalaria firewalld. O UFWPS não faz isso.

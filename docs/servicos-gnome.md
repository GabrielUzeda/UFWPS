# Serviços do Fedora Workstation 45 (GNOME): o que sai e o que fica

Adaptado do método do rakuos-cosmic-debloat. Medido numa VM KVM com Fedora 45 Workstation
stock (GNOME Shell 51, 4 GB), **PSS no idle após reboot** (170 s de espera), um grupo por vez,
acumulado. Baseline: **1218 MB**, ruído ~4 MB. Final com os 11 grupos: **753 MB** (-465 MB, -38%).
Smoke após cada grupo: gnome-shell de pé, notificações, NetworkManager conectado, sem unit falha,
hora sincronizada. Dependências conferidas com `dnf remove --assumeno` (cascata) no stock.

Uso: `sudo ./gnome-debloat.sh --list | --dry-run all | 1,3,8`. `all` = grupos 1 a 6.

## Grupos

| # | Grupo | MB | O que muda | Perde |
|---|---|---|---|---|
| 1 | servicos | 10 | mask: auditd, ModemManager, systemd-homed, unbound-anchor, mcelog (já falhava), raid-check/mdmonitor, iscsi, sssd-kcm | auditoria, modem, RAID/iSCSI se em uso |
| 2 | energia | 31 | `power-profiles-daemon` no lugar de tuned + tuned-ppd (mesma API `net.hadess.PowerProfiles`, o `--allowerasing` troca) | tuning do tuned |
| 3 | gnome-sw | 330 | gnome-software deixa de subir no login; abre sob demanda pelo D-Bus. Inclui o dnf5daemon-server que ele puxa (348 MB de pico) | aviso de update em segundo plano |
| 4 | indexador | 10 | mask localsearch-3 | busca por conteúdo |
| 5 | a11y | 0 | remove orca/speech-dispatcher/brltty | leitor de tela (ganho só em disco) |
| 6 | vmguest | 0 | remove guest tools; pulado dentro de VM | integração do hypervisor |
| 7* | calendario | 46 | mask evolution-source/calendar/addressbook/alarm | eventos no menu de data, Calendar/Contacts |
| 8* | print | 8 | remove cups, hplip, filtros (29 pacotes) | imprimir/escanear |
| 9* | avahi | ~0 | mask avahi | descoberta de impressora/`.local` |
| 10* | tempo | 0 | systemd-timesyncd no lugar do chrony | NTS |
| 11* | firewall | 27 | nftables (ssh, mDNS, dhcpv6 de entrada) no lugar do firewalld | zona Workstation (portas 1025-65535 fecham), firewall-cmd |

\* fora do `all`: perdem função visível ou mudam postura de segurança.

## O que NÃO pode sair (testado, o dnf recusa por proteger o gnome-shell)

| Pacote | Quem exige |
|---|---|
| switcheroo-control | gnome-shell (Requires) |
| geoclue2 | gnome-settings-daemon |
| evolution-data-server | gnome-shell (libecal, libedataserver). Só dá para mascarar os serviços (grupo 7) |
| udisks2 | gvfs, gnome-online-accounts |
| NetworkManager, polkit, accountsservice, xdg-desktop-portal-gtk/gnome, ibus | sessão (ibus: gnome-shell/IME) |
| localsearch (pacote) | gnome-classic-session, papers-nautilus; por isso só mask |

## Armadilhas encontradas no teste

- **Mascarar `gnome-software.service` quebra o app**: o D-Bus ativa o app pela mesma unit
  (`NameHasNoOwner`). O `Wants=` está dentro de `gnome-session-services.target`; o grupo 3 copia o target
  sem essa linha para `/etc/systemd/user/` (a cópia não recebe update do pacote). As chaves do
  gsettings (`allow-updates`, `download-updates`) não param o daemon: testado, sem ganho.
- `mdadm`, `cups`, `avahi`, `ibus` e `gnome-boxes` arrastam outros pacotes: cups leva hplip/bluez-cups,
  avahi leva nss-mdns/hplip/spice-webdavd, remover `iscsi-initiator-utils` leva o gnome-boxes.
  `libvirt*` (~30 sockets) só sai com o gnome-boxes (154 pacotes), por isso nenhum grupo mexe nisso.
- auditd tem `RefuseManualStop`: o mask só vale no próximo boot. `audit-rules` fica.
- tuned-ppd provê `ppd-service`: sem `--allowerasing` o dnf não troca.
- Troca de firewall só foi validada em regras de entrada; portas extras abertas no firewalld
  são avisadas, não migradas.

## Restore

```
sudo dnf install $(cat /var/lib/gnome-debloat/removed.txt)
sudo systemctl unmask $(cat /var/lib/gnome-debloat/mascarados.txt)
sudo systemctl --global unmask $(cat /var/lib/gnome-debloat/mascarados-user.txt)
sudo rm -f $(cat /var/lib/gnome-debloat/arquivos.txt)
```

## Não testado

Hardware real: laptop (TLP, bateria), modem, upower, bluetooth. NVIDIA. Medição foi AMD/VM sem GPU.

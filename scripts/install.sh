#!/usr/bin/env bash
# ============================================================================
#  Instalador SLSsteam + CloudRedirect pt-BR — port fiel do h3adcr-b
#  (Deadboy666/h3adcr-b headcrab.sh) com o CloudRedirect deste repositorio.
#
#  Logica IDENTICA ao h3adcr-b: mesma ordem de etapas, mesmos cortes por
#  distro, mesmo pin de cliente, mesmos manifestos/dgsc/client.sh e o mesmo
#  launcher steam.sh (INJECT_SLS via LD_AUDIT + INJECT_CR via LD_PRELOAD).
#  A unica substituicao e o CloudRedirect: em vez do .so/CLI da release
#  h3adcr-b e do app flatpak de OAuth, usa o cloud_redirect.so deste repo
#  (com CrashGuard + StopWorkers) e a UI Qt6 nativa dele para o login.
#
#  Uso:  ./scripts/install.sh
# ============================================================================
set -uo pipefail

# ── Cabecalho: versao compativel do cliente ────────────────────────────────
HeadcrabCompatibleClientVer=1791918634

# ── Caminhos ───────────────────────────────────────────────────────────────
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
ApplicationDirectory=$HOME/.local/share/applications
IconDirectory=$HOME/.local/share/icons/hicolor/48x48/apps
SteamInstallDir=$HOME/.steam/steam
FlatpakCloudRedirectDir=$HOME/.var/app/com.valvesoftware.Steam/.local/share/CloudRedirect
FlatpakSteamInstallDir=$HOME/.var/app/com.valvesoftware.Steam/.steam/steam
FlatpakSLSsteamInstallDir=$HOME/.var/app/com.valvesoftware.Steam/.local/share/SLSsteam
FlatpakSLSsteamConfigDir=$HOME/.var/app/com.valvesoftware.Steam/.config/SLSsteam
CloudRedirectDir=$HOME/.local/share/CloudRedirect
CloudRedirectAppDir=$HOME/.local/share/CloudRedirect/app
SLSsteamInstallDir=$HOME/.local/share/SLSsteam
SLSsteamConfigDir=$HOME/.config/SLSsteam
InstallDir=$SCRIPT_DIR/SLSsteam_Download/bin
Headcrab_Downgrader_Path=$HOME/.headcrab

# ── URLs (h3adcr-b) + CloudRedirect deste repo ────────────────────────────
Headcrab_Downgrade_URL="http://localhost:1666/"
LinuxClientManifest="https://runn.i.ng/Deadboy666/SteamTracking/refs/heads/headcrab/ClientManifest/steam_client_ubuntu12"
DeckClientManifest="https://runn.i.ng/Deadboy666/SteamTracking/refs/heads/headcrab/ClientManifest/steam_client_steamdeck_stable_ubuntu12"
Headcrab_Native="https://runn.i.ng//Deadboy666/h3adcr-b-modul3s/refs/heads/main/headcrab_native.sh"
Headcrab_Native_CR="https://runn.i.ng//Deadboy666/h3adcr-b-modul3s/refs/heads/cr-test/headcrab_native.sh"
Headcrab_Flatpak="https://runn.i.ng//Deadboy666/h3adcr-b-modul3s/refs/heads/main/headcrab_flatpak.sh"
Headcrab_Flatpak_CR="https://runn.i.ng//Deadboy666/h3adcr-b-modul3s/refs/heads/cr-test/headcrab_flatpak.sh"
Headcrab_Client="https://runn.i.ng//Deadboy666/SteamTracking/refs/heads/master/ClientExtracted/steam.sh"
dgsc="https://github.com/Deadboy666/h3adcr-b-modul3s/raw/refs/heads/main/dgsc"
dlm="https://github.com/Deadboy666/h3adcr-b-modul3s/raw/refs/heads/main/dlm"
Sources="https://cdn.jsdelivr.net/gh/Deadboy666/h3adcr-b-modul3s@refs/heads/main/stable-sources.txt"
Headcrab_Updater="https://cdn.jsdelivr.net/gh/Deadboy666/h3adcr-b-modul3s@refs/heads/main/headcrab.desktop"
Headcrab_Icon="https://cdn.jsdelivr.net/gh/Deadboy666/h3adcr-b-modul3s@refs/heads/main/headcrab.png"

# CloudRedirect: o binario 32-bit (com CrashGuard) e o CLI deste repositorio.
REPO_CR="https://github.com/LucianoSkx/SLSSteamTools-BR.git"
CR_BRANCH="${CR_BRANCH:-master}"
CR_RAW="https://raw.githubusercontent.com/LucianoSkx/SLSSteamTools-BR/$CR_BRANCH"
CloudRedirectLib="$CR_RAW/cloud_redirect.so"
CloudRedirectCLI="$CR_RAW/cloud_redirect_cli"
REPO_RAW="$CR_RAW"
SHA256_DGSC="08951d8e998d97dc4a35cb9376c888b98fa5dfb3dbf03d2fc96299403fd00422"
SHA256_NETSOCK="0c9d0fd5e5f7aa90a67f6afaa2959bdd0f2ee87505909c3e31bdd899e080cf52"

# ── Cores ──────────────────────────────────────────────────────────────────
c_reset='\033[0m'; c_green='\033[1;32m'; c_yellow='\033[1;33m'
c_red='\033[1;31m'; c_cyan='\033[1;36m'; c_bold='\033[1m'
info()  { printf "${c_cyan}[info]${c_reset} %s\n" "$*"; }
ok()    { printf "${c_green}[ ok ]${c_reset} %s\n" "$*"; }
warn()  { printf "${c_yellow}[aviso]${c_reset} %s\n" "$*" >&2; }
die()   { printf "${c_red}[erro]${c_reset} %s\n" "$*" >&2; exit 1; }
titulo(){ printf "\n${c_bold}==> %s${c_reset}\n" "$*"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Download atomico (temp + mv): nunca deixa arquivo parcial no destino.
baixar() {
    local url="$1" alvo="$2"
    curl -fsSL --retry 3 --connect-timeout 15 -o "$TMP/dl.$$" "$url" \
        || die "falha ao baixar $url"
    mv -f "$TMP/dl.$$" "$alvo"
}

verificar_sha256() {
    local alvo="$1" esperado="$2" atual
    atual="$(sha256sum "$alvo" | awk '{print $1}')"
    [ "$atual" = "$esperado" ] \
        || die "hash de $(basename "$alvo") nao confere (esperado ${esperado:0:12}, obtido ${atual:0:12}); abortando"
}

BACKUPS_FEITOS=""
backup_cfg() {
    local cfg="$1" bkp
    [ -f "$cfg" ] || return 0
    case " $BACKUPS_FEITOS " in *" $cfg "*) return 0 ;; esac
    bkp="$(mktemp "${cfg}.instbackup-XXXXXX")" || die "impossivel criar backup de $cfg"
    cp -p "$cfg" "$bkp" || die "falha ao copiar $cfg para $bkp"
    BACKUPS_FEITOS="$BACKUPS_FEITOS $cfg"
    ok "backup em $bkp"
}

    read_os_release(){
        local f
        OS_ID=""; OS_ID_LIKE=""
        for f in /etc/os-release /usr/lib/os-release; do
            [ -r "$f" ] || continue
            . "$f"
            break
        done
        OS_ID=${ID:-}
        OS_ID_LIKE=${ID_LIKE:-}
    }
    archcheck(){
        read_os_release
        case " $OS_ID $OS_ID_LIKE " in
            *" arch "*|*" cachyos "*) return 0 ;;
        esac
        return 1
        }
    debiancheck(){
        read_os_release
        case " $OS_ID $OS_ID_LIKE " in
            *" debian "*|*" ubuntu "*) return 0 ;;
        esac
        return 1
        }
    steamoscheck(){
        read_os_release
        [ "$OS_ID" = "steamos" ]
        }
    voidcheck(){
        read_os_release
        [ "$OS_ID" = "void" ]
        }
    cachyoscheck(){
        read_os_release
        [ "$OS_ID" = "cachyos" ]
        }
    bazzitecheck(){
        read_os_release
        [ "$OS_ID" = "bazzite" ]
        }
    flatpakcheck(){
        [ -d "$FlatpakSteamInstallDir" ]
        }
    crconfigcheck(){
      whereSLSsteamconfig
        grep -F "DisableCloud: no" config.yaml &> /dev/null
        }

    SetupHeadcrab_Updater(){
		mkdir -p $ApplicationDirectory
		mkdir -p $IconDirectory
		cd $IconDirectory/
		wget -O headcrab.png "$Headcrab_Icon" &> /dev/null
		cd $ApplicationDirectory/
			if [ -f "$SCRIPT_DIR/install.sh" ]; then
				updater_exec="bash \"$SCRIPT_DIR/install.sh\""
			else
				updater_exec="bash -c 'curl -fsSL \"$REPO_RAW/scripts/install.sh\" | bash'"
			fi
			cat > headcrab.desktop <<EOF
[Desktop Entry]
Version=1.0
Name=Headcrab Updater
Comment=Atualiza cliente e SLSsteam (pt-BR, CloudRedirect deste repo)
Exec=$updater_exec
Terminal=true
Icon=headcrab
Type=Application
Categories=Utility;Application;
EOF
		    chmod +x headcrab.desktop
			update-desktop-database $ApplicationDirectory
			echo "Headcrab Updater Now In Your Applications Menu"
			echo "Can Open Up Headcrab Updater To Update To Latest Version."
	}

    SteamOSClientCheck(){
        if [ -f "steam_client_steamdeck_stable_ubuntu12.manifest" ]; then
            versionnumber=$(grep '"version"' steam_client_steamdeck_stable_ubuntu12.manifest | awk -F'"' '{print $4}')
            echo "SteamClientChannel: Stable"
        elif [ -f steam_client_steamdeck_publicbeta_ubuntu12.manifest ]; then
            versionnumber=$(grep '"version"' steam_client_steamdeck_publicbeta_ubuntu12.manifest | awk -F'"' '{print $4}')
			echo "SteamClientChannel: Beta"
			echo "Reverting To Stable Client With DGSC"
		else
			echo "Unknown Version Number"
        fi
            echo "SteamClientType: SteamOS"
        }

	BazziteClientCheck(){
        if [ -f "steam_client_steamdeck_stable_ubuntu12.manifest" ]; then
            versionnumber=$(grep '"version"' steam_client_steamdeck_stable_ubuntu12.manifest | awk -F'"' '{print $4}')
            echo "SteamClientChannel: Stable (Bazzite-Deck)"
        elif [ -f steam_client_steamdeck_publicbeta_ubuntu12.manifest ]; then
            versionnumber=$(grep '"version"' steam_client_steamdeck_publicbeta_ubuntu12.manifest | awk -F'"' '{print $4}')
            echo "SteamClientChannel: Beta (Bazzite-Deck)"
		elif [ -f "steam_client_ubuntu12.manifest" ]; then
            versionnumber=$(grep '"version"' steam_client_ubuntu12.manifest | awk -F'"' '{print $4}')
            echo "SteamClientChannel: Stable (Bazzite-Desktop)"
		else
            versionnumber=$(grep '"version"' steam_client_publicbeta_ubuntu12.manifest | awk -F'"' '{print $4}')
            echo "SteamClientChannel: Beta (Bazzite-Desktop)"
        fi
            echo "SteamClientType: Bazzite"
        }

	CachyClientCheck(){
        if [ -f "steam_client_steamdeck_stable_ubuntu12.manifest" ]; then
            versionnumber=$(grep '"version"' steam_client_steamdeck_stable_ubuntu12.manifest | awk -F'"' '{print $4}')
            echo "SteamClientChannel: Stable (CachyOS-Handheld)"
        elif [ -f steam_client_steamdeck_publicbeta_ubuntu12.manifest ]; then
            versionnumber=$(grep '"version"' steam_client_steamdeck_publicbeta_ubuntu12.manifest | awk -F'"' '{print $4}')
            echo "SteamClientChannel: Beta (CachyOS-Handheld)"
		elif [ -f "steam_client_ubuntu12.manifest" ]; then
            versionnumber=$(grep '"version"' steam_client_ubuntu12.manifest | awk -F'"' '{print $4}')
            echo "SteamClientChannel: Stable (CachyOS-Desktop)"
		else
            versionnumber=$(grep '"version"' steam_client_publicbeta_ubuntu12.manifest | awk -F'"' '{print $4}')
            echo "SteamClientChannel: Beta (CachyOS-Desktop)"
        fi
            echo "SteamClientType: CachyOS"
        }

    FlatpakClientCheck(){
        if [ -f "steam_client_ubuntu12.manifest" ]; then
            versionnumber=$(grep '"version"' steam_client_ubuntu12.manifest | awk -F'"' '{print $4}')
            echo "SteamClientChannel: Stable"
        else
            versionnumber=$(grep '"version"' steam_client_publicbeta_ubuntu12.manifest | awk -F'"' '{print $4}')
            echo "SteamClientChannel: Beta"
        fi
            echo "SteamClientType: Flatpak"
        }

    NativeClientCheck(){
        if [ -f "steam_client_ubuntu12.manifest" ]; then
            versionnumber=$(grep '"version"' steam_client_ubuntu12.manifest | awk -F'"' '{print $4}')
            echo "SteamClientChannel: Stable"
        else
            versionnumber=$(grep '"version"' steam_client_publicbeta_ubuntu12.manifest | awk -F'"' '{print $4}')
            echo "SteamClientChannel: Beta"
        fi
            echo "SteamClientType: Native"
        }

	VoidClientCheck(){
        if [ -f "steam_client_ubuntu12.manifest" ]; then
            versionnumber=$(grep '"version"' steam_client_ubuntu12.manifest | awk -F'"' '{print $4}')
            echo "SteamClientChannel: Stable"
        else
            versionnumber=$(grep '"version"' steam_client_publicbeta_ubuntu12.manifest | awk -F'"' '{print $4}')
            echo "SteamClientChannel: Beta"
        fi
            echo "SteamClientType: Void"
        }

    CheckClientInfo(){
        echo "SteamClientInfo:"
        wheresteampackage
        if steamoscheck; then
            SteamOSClientCheck
		elif bazzitecheck; then
            BazziteClientCheck
		elif cachyoscheck; then
			CachyClientCheck
		elif voidcheck; then
			VoidClientCheck
        elif flatpakcheck; then
            FlatpakClientCheck
        else
            NativeClientCheck
        fi
            echo "SteamClientVersion: $versionnumber"
            }

    CheckHeadcrabCompatibility(){
            echo "=================================================="
        CheckClientInfo
        if [[ "$versionnumber" == "$HeadcrabCompatibleClientVer" ]]; then
            echo "ClientCompatCheck: SteamClientVersion Compatible"
            echo "================================================="
            clientinstall
        else
            echo "ClientCompatCheck: SteamClientVersion Incompatible"
            echo "=================================================="
            echo "Bootstrapping Injector"
            clientdowngrade
        fi
        }

    preinstallchecks(){
        InstallVoidDeps
		InstallDebianDeps
		InstallArchDeps
        RemoveArchPkg
        DisableSLSsteamPath
        }

    InstallDebianDeps() {
	    if debiancheck; then
		if apt-cache search --names-only '^libcurl4t64$' | grep -q "libcurl4t64"; then
		    pkg_name="libcurl4t64"
		else
		    pkg_name="libcurl4"
		fi
		target_pkg="${pkg_name}:i386"
		if dpkg -s "$target_pkg" >/dev/null 2>&1; then
		    echo -e "$target_pkg already installed"
		    return 0
		fi
		if ! dpkg --print-foreign-architectures | grep -q "i386"; then
		    echo "Adding i386 architecture..."
		    sudo dpkg --add-architecture i386
		    sudo apt-get update >/dev/null 2>&1
		fi
		if sudo apt-get install -y "$target_pkg" >/dev/null 2>&1; then
		    echo -e "$target_pkg installed successfully"
		else
		    echo -e "$target_pkg failed to install"
		fi
        fi
	    }

	InstallVoidDeps(){
        if voidcheck; then
            if ! command -v xbps-install >/dev/null 2>&1; then
                echo "Void Linux detected but xbps-install was not found in PATH"
                return 1
            fi
            local pkg cmd install_cmd
            local missing_pkgs=() missing_cmds=()
            for pkg in wget curl grep gawk sed 7zip; do
                case "$pkg" in
                    gawk) cmd="awk" ;;
                    7zip) cmd="7z" ;;
                    *) cmd="$pkg" ;;
                esac
                if ! command -v "$cmd" >/dev/null 2>&1; then
                    missing_pkgs+=("$pkg")
                fi
            done
            if [ "${#missing_pkgs[@]}" -eq 0 ]; then
                echo "Void dependencies already installed"
                return 0
            fi
            if [ "$(id -u)" -eq 0 ]; then
                install_cmd="xbps-install"
            elif command -v sudo >/dev/null 2>&1; then
                install_cmd="sudo xbps-install"
            else
                echo "Void dependencies missing: ${missing_pkgs[*]}"
                echo "Install them with: xbps-install ${missing_pkgs[*]}"
                echo "Re-run as root or install sudo for automatic dependency installation"
                return 1
            fi
            echo "Installing missing Void dependencies: ${missing_pkgs[*]}"
            if ! $install_cmd -y "${missing_pkgs[@]}"; then
                echo "Failed to install Void dependencies: ${missing_pkgs[*]}"
                return 1
            fi
            for pkg in wget curl grep gawk sed 7zip; do
                case "$pkg" in
                    gawk) cmd="awk" ;;
                    7zip) cmd="7z" ;;
                    *) cmd="$pkg" ;;
                esac
                if ! command -v "$cmd" >/dev/null 2>&1; then
                    missing_cmds+=("$pkg")
                fi
            done
            if [ "${#missing_cmds[@]}" -ne 0 ]; then
                echo "Void dependencies still missing after install: ${missing_cmds[*]}"
                return 1
            fi
            echo "Void dependencies installed successfully"
        fi
    }

	InstallArchDeps(){
		if archcheck; then
		 local packages=("wget" "curl" "grep" "awk" "sed" "7zip")
	    local to_install=()
	    for pkg in "${packages[@]}"; do
	        if ! pacman -Qs "$pkg" &>/dev/null; then
	            to_install+=("$pkg")
	        fi
	    done
	    if [ ${#to_install[@]} -eq 0 ]; then
	        echo "All required packages are already installed."
	    else
	        echo "Installing missing packages: ${to_install[*]}"
	        sudo pacman -S "${to_install[@]}" --noconfirm
	    fi
		fi
	}

    RemoveArchPkg(){
        if archcheck; then
        installed_pkgs=$(pacman -Qq | grep -E '^slssteam(-git)?$' || true)
        if [ -n "$installed_pkgs" ]; then
            echo "Headcrab Will Transition To The Install To One That Can Seemlessly Update."
			echo "This Will Replace The System Package Of SLSsteam With One That Is Local."
            echo "Uninstalling Arch packages: $installed_pkgs"
            sudo pacman -Rns --noconfirm $installed_pkgs
        fi
        fi
    }

    DisableSLSsteamPath(){
        local local_target="$SLSsteamInstallDir/path/steam"
        local flatpak_target="$FlatpakSLSsteamInstallDir/path/steam"
        local acted=0
        if [ -e "$flatpak_target" ]; then
            echo "Found: $flatpak_target"
            echo "Renaming $flatpak_target -> ${flatpak_target}.bak"
            mv -- "$flatpak_target" "${flatpak_target}.bak"
            acted=1
        fi
        if [ -e "$local_target" ]; then
            echo "Found: $local_target"
            echo "Renaming $local_target -> ${local_target}.bak"
            mv -- "$local_target" "${local_target}.bak"
            acted=1
        fi
        if [ "$acted" -eq 0 ]; then
            echo "Not present: $flatpak_target"
            echo "Not present: $local_target"
        fi
    }

	TrashiteWatMani(){
		wheresteampackage
		if [ -f "steam_client_steamdeck_stable_ubuntu12.installed" ]; then
			echo "Headcrab Downloading Bazzite-Deck Client Manifest"
			wget -O steam_client_steamdeck_stable_ubuntu12.manifest "$DeckClientManifest" &> /dev/null
		else
			echo "Headcrab Downloading Bazzite-Desktop Client Manifest"
			wget -O steam_client_ubuntu12 "$LinuxClientManifest" &> /dev/null
		fi
			echo "" &> /dev/null
		}

	CachyWatMani(){
		wheresteampackage
		if [ -f "steam_client_steamdeck_stable_ubuntu12.installed" ]; then
			echo "Headcrab Downloading CachyOS-Handheld Client Manifest"
			wget -O steam_client_steamdeck_stable_ubuntu12.manifest "$DeckClientManifest" &> /dev/null
		else
			echo "Headcrab Downloading CachyOS-Desktop Client Manifest"
			wget -O steam_client_ubuntu12 "$LinuxClientManifest" &> /dev/null
		fi
			echo "" &> /dev/null
		}

    DownloadClientManifest(){
	    if steamoscheck; then
	        echo "Headcrab Downloading Steamos Client Manifest.."
	        wget -O steam_client_steamdeck_stable_ubuntu12.manifest "$DeckClientManifest" &> /dev/null
		elif bazzitecheck; then
			TrashiteWatMani
		elif cachyoscheck; then
			CachyWatMani
	    else
	        echo "Headcrab Downloading Linux Client Manifest.."
	        wget -O steam_client_ubuntu12 "$LinuxClientManifest" &> /dev/null
	    fi
	        echo "Client Manifest Downloaded"
    }

    download_dgsc(){
        mkdir -p $Headcrab_Downgrader_Path
        cd $Headcrab_Downgrader_Path/
        if [ -f "$Headcrab_Downgrader_Path/dgsc" ]; then
            echo "Headcrab_dgsc Downloaded Already."
        else
            echo "Downloading Headcrab_dgsc.."
            baixar "$dgsc" "$Headcrab_Downgrader_Path/dgsc"
            chmod +x dgsc
            verificar_sha256 "$Headcrab_Downgrader_Path/dgsc" "$SHA256_DGSC"
        fi
          echo "" &> /dev/null
        }

        download_dlm(){
        mkdir -p $Headcrab_Downgrader_Path
        cd $Headcrab_Downgrader_Path/
        if [ -f "$Headcrab_Downgrader_Path/dlm" ]; then
            echo "Headcrab_dlm Downloaded Already."
        else
            echo "Downloading Headcrab_dlm.."
            baixar "$dlm" "$Headcrab_Downgrader_Path/dlm"
            chmod +x dlm
        fi
          echo "" &> /dev/null
        }

        dlm(){
        download_dlm
        echo "Running Fetching Client Update Headcrab_dlm.."
        wheresteampackage
        $Headcrab_Downgrader_Path/dlm --input-file sources.txt --max-concurrent 16
        echo "Headcrab_dlm Fetched Client Update"
        }

    dgsc(){
        download_dgsc
        echo "Running Headcrab_dgsc.."
        wheresteampackage
        $Headcrab_Downgrader_Path/dgsc --port 1666 --silent & sleep 1s "$@"
        }

    prepdowngrade(){
        wheresteamcfg
        rm -f package/*
        wheresteampackage
        DownloadClientManifest
		}

    clientinstall(){
        echo "the headcrab latches on the steam process.."
		createsteamcfg
        if steamoscheck; then
            echo "Steamos Detected"
            echo "Headcrab Bootstrapping SLSsteam.."
           export_sls wheresteam -exitsteam
		elif bazzitecheck; then
			echo "Bazzite Detected"
            echo "Headcrab Bootstrapping SLSsteam.."
           export_sls wheresteam -exitsteam
		elif cachyoscheck; then
			echo "CachyOS Detected"
            echo "Headcrab Bootstrapping SLSsteam.."
           export_sls wheresteam -exitsteam
        elif flatpakcheck; then
            echo "Headcrab Bootstrapping SLSsteam.."
			export_sls wheresteam -clearbeta steam://exit
		elif voidcheck; then
			echo "Void Linux"
			echo "Headcrab Bootstrapping SLSsteam.."
			export_sls wheresteam -clearbeta -exitsteam
		else
			export_sls wheresteam -clearbeta -exitsteam &> /dev/null
        fi
            echo "" &> /dev/null
            }

    clientdowngrade(){
        prepdowngrade
        overideupdate
        }

    nuketheclient(){
                killall steam | true
            }

    wheresteam(){
        if [ -d "$FlatpakSteamInstallDir" ]; then
                flatpak run com.valvesoftware.Steam "$@" &> /dev/null
        else
                steam "$@" &> /dev/null
            fi
                echo "" &> /dev/null
            }

    wheresteamdir(){
        if [ -d "$FlatpakSteamInstallDir" ]; then
                mkdir -p $FlatpakSLSsteamInstallDir
				mkdir -p $FlatpakCloudRedirectDir
                cp -f $InstallDir/library-inject.so $FlatpakSLSsteamInstallDir/
                cp -f $InstallDir/SLSsteam.so $FlatpakSLSsteamInstallDir/
        else
                 mkdir -p $CloudRedirectDir
				 mkdir -p $SLSsteamInstallDir
                 mkdir -p $SLSsteamConfigDir
                 cp -f $InstallDir/library-inject.so $SLSsteamInstallDir/
                 cp -f $InstallDir/SLSsteam.so $SLSsteamInstallDir/
            fi
				echo "" &> /dev/null
            }

    wheresteamcfg(){
        if [ -d "$FlatpakSteamInstallDir" ]; then
               cd $FlatpakSteamInstallDir/
        else
                cd $SteamInstallDir/
            fi
                echo "" &> /dev/null
            }

	wheresteampackage(){
        if [ -d "$FlatpakSteamInstallDir" ]; then
               cd $FlatpakSteamInstallDir/package
        else
                cd $SteamInstallDir/package
            fi
                echo "" &> /dev/null
            }

    whereSLSsteamconfig(){
        if [ -d "$FlatpakSLSsteamConfigDir" ]; then
               mkdir -p $FlatpakSLSsteamConfigDir
               cd $FlatpakSLSsteamConfigDir/
        else
                mkdir -p $SLSsteamConfigDir
                cd $SLSsteamConfigDir/
            fi
                echo "" &> /dev/null
            }

    updateSLSsteamConfig(){
        (
            local latest_config="$1"
            local config_file
            local merged_config
            local backup_base
            local backup
            local suffix=1

            if [ ! -f "$latest_config" ]; then
                return
            fi

            whereSLSsteamconfig
            config_file="$PWD/config.yaml"

            if [ ! -f "$config_file" ]; then
                return
            fi

            if ! grep -q '^DisableFamilyShareLock:' "$latest_config"; then
                echo "SLSsteam Config Template Is Invalid"
                return
            fi

            merged_config=$(mktemp "${config_file}.tmp.XXXXXX") || return

            if ! awk '
                NR == FNR {
                    if ($0 ~ /^[A-Za-z_][A-Za-z0-9_]*:/) {
                        key = $0
                        sub(/:.*/, "", key)
                        current = key
                        present[key] = 1
                        saved[key] = $0 ORS
                        next
                    }
                    if (current != "" && $0 ~ /^[[:space:]]+/) {
                        saved[current] = saved[current] $0 ORS
                    }
                    next
                }
                /^[A-Za-z_][A-Za-z0-9_]*:/ {
                    key = $0
                    sub(/:.*/, "", key)
                    printf "%s", prefix
                    prefix = ""
                    if (key in present) {
                        printf "%s", saved[key]
                        use_template = 0
                    } else {
                        print
                        use_template = 1
                    }
                    have_key = 1
                    next
                }
                have_key && /^[[:space:]]+/ {
                    if (use_template) {
                        print
                    }
                    next
                }
                {
                    prefix = prefix $0 ORS
                }
                END {
                    printf "%s", prefix
                }
            ' "$config_file" "$latest_config" > "$merged_config"; then
                echo "SLSsteam Config Update Failed"
                rm -f "$merged_config"
                return
            fi

            if ! grep -q '^DisableFamilyShareLock:' "$merged_config"; then
                echo "SLSsteam Config Update Failed"
                rm -f "$merged_config"
                return
            fi

            if cmp -s "$config_file" "$merged_config"; then
                echo "SLSsteam Config Is Up To Date"
                rm -f "$merged_config"
                return
            fi

            backup_base="${config_file}.headcrab-$(date +%Y%m%d-%H%M%S)"
            backup="$backup_base"
            while [ -e "$backup" ]; do
                backup="${backup_base}-${suffix}"
                suffix=$((suffix + 1))
            done

            cp -a "$config_file" "$backup"
            chmod --reference="$config_file" "$merged_config" 2>/dev/null || true
            mv -f "$merged_config" "$config_file"

            echo "SLSsteam Config Updated"
            echo "Config Backup: $backup"
        )
    }

    overideupdate(){
        echo "the headcrab latches on the steam process.."
		killall dgsc | true
        if steamoscheck; then
            echo "Steamos Detected"
            createsteamcfg
            echo "Headcrab Connecting to The Updater.."
           export_sls wheresteam  -forcesteamupdate -forcepackagedownload -overridepackageurl "$Headcrab_Downgrade_URL" -exitsteam &> /dev/null
		elif bazzitecheck; then
			echo "Bazzite Detected"
            createsteamcfg
            echo "Headcrab Connecting to The Updater.."
           export_sls wheresteam  -forcesteamupdate -forcepackagedownload -overridepackageurl "$Headcrab_Downgrade_URL" -exitsteam &> /dev/null
        else
            createsteamcfg
            echo "Headcrab Connecting to The Updater.."
           export_sls wheresteam  -forcesteamupdate -forcepackagedownload -overridepackageurl "$Headcrab_Downgrade_URL" -exitsteam &> /dev/null
        fi
            echo "Compatible Update Applied Via Headcrab_dgsc"
            }

    checkforsteamcfg(){
    echo "the headcrab approaches.."
    wheresteamcfg
        nuketheclient
        CheckHeadcrabCompatibility
        conditioncheck
        }

    downloadSLSsteam(){
            echo "Downloading Latest SLSsteam.."
            mkdir -p $SCRIPT_DIR/SLSsteam_Download
            cd SLSsteam_Download
            local TAG
            TAG=$(curl -sSL --connect-timeout 15 --max-time 30 \
                -o /dev/null -w "%{url_effective}" \
                "https://github.com/AceSLS/SLSsteam/releases/latest" 2>/dev/null)
            TAG="${TAG##*/}"
            SLS_TAG="$TAG"
            baixar "https://github.com/AceSLS/SLSsteam/releases/download/$TAG/SLSsteam-Any-release.7z" \
                   "$SCRIPT_DIR/SLSsteam_Download/SLSsteam-Any.7z"
        }

	downloadnetsock(){
            echo "Downloading Latest Netsock Lib.."
            mkdir -p ~/.config/SLSsteam/tools/netsock
            cd ~/.config/SLSsteam/tools/netsock
            baixar "https://cdn.jsdelivr.net/gh/yesyes0649/steamnetsock-patch@builds/fix.so" \
                   "$HOME/.config/SLSsteam/tools/netsock/netsock.so"
            verificar_sha256 "$HOME/.config/SLSsteam/tools/netsock/netsock.so" "$SHA256_NETSOCK"
                echo "Downloaded Latest Netsock Lib."
				cd $SCRIPT_DIR/
        }

    export_sls(){
        if [ -d "$FlatpakSteamInstallDir" ]; then
                copySLSsteam
                LD_AUDIT=$HOME/.var/app/com.valvesoftware.Steam/.local/share/SLSsteam/library-inject.so:$HOME/.var/app/com.valvesoftware.Steam/.local/share/SLSsteam/SLSsteam.so "$@"
        else
                copySLSsteam
                LD_AUDIT=$HOME/.local/share/SLSsteam/library-inject.so:$HOME/.local/share/SLSsteam/SLSsteam.so "$@"
        fi
                echo &> /dev/null
                }

    extractSLSsteam(){
		downloadnetsock
        downloadSLSsteam
         7z x $SCRIPT_DIR/SLSsteam_Download/SLSsteam-Any.7z -aoa > /dev/null
         updateSLSsteamConfig "$SCRIPT_DIR/SLSsteam_Download/res/config.yaml"
         rm -rf tools
         rm -rf res
         rm setup.sh
         rm -rf docs
         rm SLSsteam-Any.7z
		 echo "SLSsteam Downloaded: Latest"
		 cd $InstallDir/
         }

    copySLSsteam(){
        extractSLSsteam
        wheresteamdir
        rm -rf $InstallDir
        }

    InstallSLSsteam(){
        echo "Installing SLSsteam..."
        if [ -d "$SLSsteamInstallDir" ]; then
          copySLSsteam
        else
            copySLSsteam
        fi
            echo "" &> /dev/null
        }

    whereCR_Install(){
       if [ -d "$FlatpakCloudRedirectDir" ]; then
               cd $FlatpakSteamInstallDir
        else
                cd $CloudRedirectDir
            fi
                echo "" &> /dev/null
            }

    # CloudRedirect DESTE repo: .so/CLI do repo + UI Qt6 nativa (sem flatpak).
    obter_fonte_cr(){
        if [ -d "$SCRIPT_DIR/../ui-linux" ] && [ -d "$SCRIPT_DIR/../.git" ]; then
            FONTE_CR="$(cd "$SCRIPT_DIR/.." && pwd)"
        else
            FONTE_CR="$CloudRedirectDir/src"
            if [ -d "$FONTE_CR/.git" ]; then
                git -C "$FONTE_CR" fetch --depth 1 origin "$CR_BRANCH" || die "falha ao buscar $CR_BRANCH"
                git -C "$FONTE_CR" reset --hard "origin/$CR_BRANCH" || die "falha ao atualizar"
            else
                mkdir -p "$CloudRedirectDir"
                git clone --depth 1 --branch "$CR_BRANCH" "$REPO_CR" "$FONTE_CR" || die "falha ao clonar $REPO_CR"
            fi
        fi
    }

    crinstall(){
      if crconfigcheck; then
        echo "Downloading Latest Cloud Redirect Library"
        whereCR_Install
        obter_fonte_cr
        mkdir -p "$CloudRedirectAppDir"

        echo "Baixando cloud_redirect.so do repo ($CR_BRANCH)..."
        baixar "$CloudRedirectLib" "$CloudRedirectDir/cloud_redirect.so"
        baixar "$CloudRedirectCLI" "$CloudRedirectDir/cloud_redirect_cli"
        chmod 777 "$CloudRedirectDir/cloud_redirect_cli"
        chmod 755 "$CloudRedirectDir/cloud_redirect.so"
        if command -v file >/dev/null 2>&1; then
            file -b "$CloudRedirectDir/cloud_redirect.so" | grep -q 'ELF 32-bit' \
                || die "cloud_redirect.so nao e 32-bit; o runtime da Steam nao vai carregar"
        fi
        install -m 755 "$CloudRedirectDir/cloud_redirect.so" "$CloudRedirectAppDir/cloud_redirect.so"
        install -m 755 "$CloudRedirectDir/cloud_redirect_cli" "$CloudRedirectAppDir/cloud_redirect_cli"

        echo "Compilando a UI Qt6 do CloudRedirect (pode demorar)..."
        cmake -S "$FONTE_CR/ui-linux" -B "$FONTE_CR/ui-linux/build" -DCMAKE_BUILD_TYPE=Release >/dev/null 2>&1 \
            || die "falha no cmake configure da UI"
        cmake --build "$FONTE_CR/ui-linux/build" --target cloud-redirect-ui -j"$(nproc 2>/dev/null || echo 2)" >/dev/null 2>&1 \
            || die "falha ao compilar a UI"
        [ -x "$FONTE_CR/ui-linux/build/cloud-redirect-ui" ] || die "binario da UI nao encontrado"
        install -m 755 "$FONTE_CR/ui-linux/build/cloud-redirect-ui" "$CloudRedirectAppDir/cloud-redirect-ui"

        for tam in 16x16 24x24 32x32 48x48 64x64 128x128 256x256 512x512; do
            mkdir -p "$HOME/.local/share/icons/hicolor/$tam/apps"
            install -m 644 "$FONTE_CR/ui-linux/src/cloudredirect.png" "$HOME/.local/share/icons/hicolor/$tam/apps/cloudredirect.png"
        done
        command -v gtk-update-icon-cache >/dev/null 2>&1 && gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" || true

        cat > "$ApplicationDirectory/cloudredirect.desktop" <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=CloudRedirect
GenericName=Gerenciador de saves na nuvem
Comment=Redireciona o Steam Cloud para provedores externos
Exec="$CloudRedirectAppDir/cloud-redirect-ui"
Icon=cloudredirect
Terminal=false
Categories=Game;
EOF
        chmod +x "$ApplicationDirectory/cloudredirect.desktop"
        command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database -q "$ApplicationDirectory" || true
        echo "Latest Cloud Redirect Library Downloaded"
      else
        echo "User Is Not Using Cloud Redirect Skipping.."
      fi
        echo "" &> /dev/null
        }

    editconfig(){
        whereSLSsteamconfig
            if steamoscheck; then
				echo "Steamos Detected Enabled Safemode"
				sed -i "s/^SafeMode:.*/SafeMode: yes/" config.yaml
				sed -i "s/^NotifyInit:.*/NotifyInit: yes/" config.yaml
				echo "config patched" > .headcrabd
			elif cachyoscheck; then
				echo "Cachy OS Detected Adjusted Loglevel"
				sed -i "s/^LogLevels:.*/LogLevels: 0x3f/" config.yaml
				sed -i "s/^SafeMode:.*/SafeMode: no/" config.yaml
				echo "config patched" > .headcrabd
			else
                sed -i "s/^SafeMode:.*/SafeMode: no/" config.yaml
				echo "config patched" > .headcrabd
            fi
            }

    createsteamcfg(){
    wheresteamcfg
    if [ -f "steam.cfg" ]; then
        echo "steam.cfg Found Skipping Creation Process.."
    else
        cat << 'EOF' > steam.cfg
BootStrapperInhibitAll=enable
BootStrapperForceSelfUpdate=disable
EOF
    fi
        echo "" &> /dev/null
    }

    patchsteam(){
        if [ -d "$FlatpakSteamInstallDir" ]; then
                patchflatpaksteam
        else
                patchlocalsteam
        fi
        }

    checkcrsteam(){
      if crconfigcheck; then
        echo "Fetching Headcrab-CR Client"
        cd $SteamInstallDir/
        rm steam.sh
        wget -O steam.sh "$Headcrab_Native_CR" &> /dev/null
        echo "Patched Client With Headcrab-CR"
      else
        echo "Fetching Headcrab Client"
        cd $SteamInstallDir/
        rm steam.sh
        wget -O steam.sh "$Headcrab_Native" &> /dev/null
        echo "Patched Client With Headcrab"
      fi
        echo "" &> /dev/null
        }

    checkcrflatpaksteam(){
      if crconfigcheck; then
        echo "Fetching Headcrab-CR Client"
        cd $FlatpakSteamInstallDir/
        rm steam.sh
        wget -O steam.sh "$Headcrab_Flatpak_CR" &> /dev/null
        echo "Patched Client With Headcrab-CR"
      else
        echo "Fetching Headcrab Client"
        cd $FlatpakSteamInstallDir/
        rm steam.sh
        wget -O steam.sh "$Headcrab_Flatpak" &> /dev/null
        echo "Patched Client With Headcrab"
      fi
        echo "" &> /dev/null
        }

    patchflatpaksteam(){
        cd $FlatpakSteamInstallDir/
        wget -O client.sh "$Headcrab_Client" &> /dev/null
            chmod 777 steam.sh
            checkcrflatpaksteam
            chmod 555 steam.sh
			chmod +x client.sh
            echo "SLSSteamInstallType: Flatpak"
        }

    patchlocalsteam(){
        cd $SteamInstallDir/
        wget -O client.sh "$Headcrab_Client" &> /dev/null
        chmod 777 steam.sh
			checkcrsteam
			chmod 555 steam.sh
			chmod +x client.sh
        	echo "SLSsteamInstallType: Native"
        }

    checkcrstatus(){
        if crconfigcheck; then
            echo "CloudRedirectStatus: Enabled"
        else
            echo "CloudRedirectStatus: Disabled"
        fi
            echo "" &> /dev/null
            }

    # ── Extras do repositorio BR (nao existem no h3adcr-b) ────────────────
    sed_i_chave(){
        local cfg="$1" chave="$2" valor="$3"
        if grep -qE "^[[:space:]]*$chave:" "$cfg"; then
            sed -i -E "s/^([[:space:]]*$chave:).*/\1 $valor/" "$cfg"
        else
            printf '\n%s: %s\n' "$chave" "$valor" >> "$cfg"
        fi
        }

    garantir_config_slssteam(){
        local cfg="$SLSsteamConfigDir/config.yaml" chave
        mkdir -p "$SLSsteamConfigDir"
        [ -f "$cfg" ] || die "config.yaml do SLSsteam ausente em $SLSsteamConfigDir"
        backup_cfg "$cfg"
        sed_i_chave "$cfg" "DisableCloud" "no"
        sed_i_chave "$cfg" "NotifyInit" "yes"
        sed_i_chave "$cfg" "SafeMode" "no"
        sed_i_chave "$cfg" "Plugins" "yes"
        for chave in AdditionalDepots DecryptionKeys; do
            grep -qE "^[[:space:]]*$chave:" "$cfg" || printf '\n%s:\n' "$chave" >> "$cfg"
        done
        ok "config do SLSsteam garantido (DisableCloud/NotifyInit/Plugins/AdditionalDepots)"
        }

    registrar_versao_slssteam(){
        [ -d "$SLSsteamInstallDir" ] || return 0
        if [ -n "${SLS_TAG:-}" ]; then
            mkdir -p "$SLSsteamInstallDir"
            printf '%s\n' "$SLS_TAG" > "$SLSsteamInstallDir/version"
            ok "versao $SLS_TAG registrada em $SLSsteamInstallDir/version (para o ASSella)"
        fi
        }

    instalar_plugins_sls(){
        local src="$SCRIPT_DIR/../sls-plugins" destino="$SLSsteamConfigDir/plugins"
        [ -d "$src" ] || { warn "sls-plugins ausente em $src; pulando"; return 0; }
        mkdir -p "$destino"
        local arq
        for arq in download.lua spliced-tickets.lua; do
            [ -f "$src/$arq" ] || die "$arq ausente em $src"
            install -m 700 "$src/$arq" "$destino/$arq"
        done
        ok "plugins Lua em $destino (Plugins: yes)"
        }

        conditioncheck(){
            crinstall
            echo "Checking Conditions.."
            echo "=================================================="
            editconfig
            patchsteam
            echo "BlockedClientUpdates: Enabled"
            checkcrstatus
            echo "=================================================="
            }

    main(){
        preinstallchecks
		SetupHeadcrab_Updater
        checkforsteamcfg
        registrar_versao_slssteam
        garantir_config_slssteam
        instalar_plugins_sls
        }

    main
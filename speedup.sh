
#!/bin/bash
set -euo pipefail

PROGRAM="$(basename "$0")"
# Befintliga hårdkodade moduler
MODULES="spotlight airplay siri gamecontroller reportcrash dashboard fx timemachine handoff icloudphotos"

# Kataloger att skanna för dynamiska tjänster
# Vi exkluderar /System/Library/ då dessa ofta är kritiska Apple-tjänster.
LAUNCH_AGENT_PATHS=(
  "/Library/LaunchAgents/"
  "~/Library/LaunchAgents/"
)
LAUNCH_DAEMON_PATHS=(
  "/Library/LaunchDaemons/"
)
# Katalog för att lagra inaktiverade .plist-filer.
# Standard: /tmp/speedup_disabled_plists (temporär, raderas vid omstart)
# För mer persistens: /var/db/speedup_disabled_plists (måste skapas manuellt med sudo om den inte finns)
DISABLED_PLIST_DIR="/tmp/speedup_disabled_plists" 

print_help() {
  echo "$PROGRAM – macOS SpeedUp Tool"
  echo "Usage:"
  echo "  sudo ./speedup.sh                # interactive (standard modules)"
  echo "  sudo ./speedup.sh --auto all     # disable all standard modules"
  echo "  sudo ./speedup.sh --auto siri,fx # disable selected standard modules"
  echo "  sudo ./speedup.sh --undo siri    # restore a standard module"
  echo "  sudo ./speedup.sh --verify       # check status of standard modules"
  echo "  sudo ./speedup.sh --advanced     # interactive (dynamic services)"
  echo "  sudo ./speedup.sh --undo-advanced <original_plist_path> # restore a dynamically disabled service"
  echo "  sudo ./speedup.sh --verify-advanced # check status of dynamically disabled services"
  echo "  sudo ./speedup.sh --help"
  echo
  echo "Standard Modules:"
  echo "  spotlight      Disable Spotlight indexing"
  echo "  airplay        Disable AirPlay UI Agent"
  echo "  siri           Disable Siri"
  echo "  gamecontroller Disable Game Controller"
  echo "  reportcrash    Disable ReportCrash (user & root)"
  echo "  dashboard      Disable legacy Dashboard"
  echo "  fx             Reduce visual effects"
  echo "  timemachine    Disable Time Machine auto backup"
  echo "  handoff        Disable Handoff/Continuity"
  echo "  icloudphotos   Disable iCloud Photos sync"
  echo
  echo "Advanced Modules (dynamically discovered services):"
  echo "  Allows disabling/enabling background services from third-party apps."
}

need_root() {
  [[ $EUID -eq 0 ]] || exec sudo "$0" "$@"
}

# === Verifieringsfunktioner för standardmoduler ===
verify_module() {
  case $1 in
    spotlight)
      mdutil -s / | grep -q "Indexing disabled" && echo "✅ spotlight" || echo "❌ spotlight"
      ;;
    airplay)
      launchctl list | grep -q AirPlayUIAgent && echo "❌ airplay" || echo "✅ airplay"
      ;;
    siri)
      launchctl list | grep -q Siri && echo "❌ siri" || echo "✅ siri"
      ;;
    gamecontroller)
      launchctl list | grep -q gamecontrollerd && echo "❌ gamecontroller" || echo "✅ gamecontroller"
      ;;
    reportcrash)
      launchctl list | grep -q ReportCrash && echo "❌ reportcrash" || echo "✅ reportcrash"
      ;;
    dashboard)
      val=$(defaults read com.apple.dashboard mcx-disabled 2>/dev/null || echo 0)
      [[ "$val" == "1" ]] && echo "✅ dashboard" || echo "❌ dashboard"
      ;;
    fx)
      a=$(defaults read com.apple.universalaccess reduceMotion 2>/dev/null || echo 0)
      b=$(defaults read com.apple.universalaccess reduceTransparency 2>/dev/null || echo 0)
      [[ "$a" == "1" && "$b" == "1" ]] && echo "✅ fx" || echo "❌ fx"
      ;;
    timemachine)
      tmutil isautobackup | grep -q false && echo "✅ timemachine" || echo "❌ timemachine"
      ;;
    handoff)
      a=$(defaults read ~/Library/Preferences/ByHost/com.apple.coreservices.useractivityd.plist ActivityAdvertisingAllowed 2>/dev/null || echo 1)
      b=$(defaults read ~/Library/Preferences/ByHost/com.apple.coreservices.useractivityd.plist ActivityReceivingAllowed 2>/dev/null || echo 1)
      [[ "$a" == "0" && "$b" == "0" ]] && echo "✅ handoff" || echo "❌ handoff"
      ;;
    icloudphotos)
      val=$(defaults read com.apple.photolibraryd PLDisableCloudPhotos 2>/dev/null || echo 0)
      [[ "$val" == "1" ]] && echo "✅ icloudphotos" || echo "❌ icloudphotos"
      ;;
  esac
}

# === Åtgärdsfunktioner för standardmoduler ===
disable_spotlight() { mdutil -a -i off; launchctl unload -w /System/Library/LaunchDaemons/com.apple.metadata.mds.plist || true; }
enable_spotlight()  { launchctl load -w /System/Library/LaunchDaemons/com.apple.metadata.mds.plist || true; mdutil -a -i on; }

disable_airplay() { launchctl unload -w /System/Library/LaunchAgents/com.apple.AirPlayUIAgent.plist || true; pkill -x AirPlayXPCHelper || true; }
enable_airplay()  { launchctl load -w /System/Library/LaunchAgents/com.apple.AirPlayUIAgent.plist || true; }

disable_siri() { launchctl unload -w /System/Library/LaunchAgents/com.apple.Siri.agent.plist || true; pkill -x Siri || true; }
enable_siri()  { launchctl load -w /System/Library/LaunchAgents/com.apple.Siri.agent.plist || true; }

disable_gamecontroller() { launchctl unload -w /System/Library/LaunchAgents/com.apple.GameController.gamecontrollerd.plist || true; }
enable_gamecontroller()  { launchctl load -w /System/Library/LaunchAgents/com.apple.GameController.gamecontrollerd.plist || true; }

disable_reportcrash() { launchctl unload -w /System/Library/LaunchAgents/com.apple.ReportCrash.plist || true; launchctl unload -w /System/Library/LaunchDaemons/com.apple.ReportCrash.Root.plist || true; }
enable_reportcrash()  { launchctl load -w /System/Library/LaunchAgents/com.apple.ReportCrash.plist || true; launchctl load -w /System/Library/LaunchDaemons/com.apple.ReportCrash.Root.plist || true; }

disable_dashboard() { defaults write com.apple.dashboard mcx-disabled -bool true; killall Dock || true; }
enable_dashboard()  { defaults delete com.apple.dashboard mcx-disabled; killall Dock || true; }

disable_fx() { defaults write com.apple.universalaccess reduceMotion -bool true; defaults write com.apple.universalaccess reduceTransparency -bool true; }
enable_fx()  { defaults delete com.apple.universalaccess.reduceMotion 2>/dev/null || true; defaults delete com.apple.universalaccess.reduceTransparency 2>/dev/null || true; }

disable_timemachine() { tmutil disable || true; }
enable_timemachine()  { tmutil enable || true; }

disable_handoff() {
  defaults write ~/Library/Preferences/ByHost/com.apple.coreservices.useractivityd.plist ActivityAdvertisingAllowed -bool false
  defaults write ~/Library/Preferences/ByHost/com.apple.coreservices.useractivityd.plist ActivityReceivingAllowed -bool false
}
enable_handoff() {
  defaults delete ~/Library/Preferences/ByHost/com.apple.coreservices.useractivityd.plist ActivityAdvertisingAllowed 2>/dev/null || true
  defaults delete ~/Library/Preferences/ByHost/com.apple.coreservices.useractivityd.plist ActivityReceivingAllowed 2>/dev/null || true
}

disable_icloudphotos() { defaults write com.apple.photolibraryd PLDisableCloudPhotos -bool true; pkill -x photolibraryd || true; }
enable_icloudphotos()  { defaults delete com.apple.photolibraryd PLDisableCloudPhotos 2>/dev/null || true; }

apply_module() {
  case $1 in
    spotlight) disable_spotlight ;;
    airplay) disable_airplay ;;
    siri) disable_siri ;;
    gamecontroller) disable_gamecontroller ;;
    reportcrash) disable_reportcrash ;;
    dashboard) disable_dashboard ;;
    fx) disable_fx ;;
    timemachine) disable_timemachine ;;
    handoff) disable_handoff ;;
    icloudphotos) disable_icloudphotos ;;
    *) echo "❌ Unknown module: $1"; exit 1 ;;
  esac
}

undo_module() {
  case $1 in
    spotlight) enable_spotlight ;;
    airplay) enable_airplay ;;
    siri) enable_siri ;;
    gamecontroller) enable_gamecontroller ;;
    reportcrash) enable_reportcrash ;;
    dashboard) enable_dashboard ;;
    fx) enable_fx ;;
    timemachine) enable_timemachine ;;
    handoff) enable_handoff ;;
    icloudphotos) enable_icloudphotos ;;
    *) echo "❌ Unknown module: $1"; exit 1 ;;
  esac
}

# === Funktioner för dynamiska tjänster (Advanced Mode) ===

# Identifierar och presenterar icke-Apple Launch Agents/Daemons för interaktiv inaktivering
advanced_interactive_disable() {
  echo "🚀 Avancerat läge: Inaktivera bakgrundstjänster från tredjepartsappar."
  echo "Var försiktig! Att inaktivera nödvändiga tjänster kan påverka programvara."
  echo "De flesta Apple-tjänster exkluderas automatiskt."
  echo

  mkdir -p "$DISABLED_PLIST_DIR" # Skapa katalogen för inaktiverade filer

  local plists_found=()
  local i=0

  # Sök igenom Launch Agent-sökvägar
  for p in "${LAUNCH_AGENT_PATHS[@]}"; do
    local expanded_path=$(eval echo "$p") # Expandera ~ till fullständig sökväg
    if [[ -d "$expanded_path" ]]; then
      for plist_file in "$expanded_path"/*.plist; do
        if [[ -f "$plist_file" ]]; then
          local plist_name=$(basename "$plist_file" .plist)
          # Exkludera Apple-specifika tjänster (enkelt grep för "com.apple.")
          if ! [[ "$plist_name" =~ ^com\.apple\. ]]; then
            # Kolla om tjänsten är laddad (aktiv)
            # Obs: launchctl list visar bara laddade tjänster för den aktuella användaren/sessionen.
            # För LaunchDaemons visas de globalt laddade.
            if launchctl list | grep -q "$plist_name"; then
              plists_found+=("$plist_file")
              echo "Hittade aktiv tjänst: $(basename "$plist_file") (Sökväg: $plist_file)"
              i=$((i + 1))
              read -p "Vill du inaktivera '$plist_name'? (y/n) " -n 1 -r
              echo
              if [[ "$REPLY" =~ ^[Yy]$ ]]; then
                echo "Inaktiverar $plist_name..."
                # launchctl unload -w inaktiverar tjänsten persistent
                launchctl unload -w "$plist_file" || true 
                # Flytta filen till DISABLED_PLIST_DIR för enkel återställning
                mv "$plist_file" "$DISABLED_PLIST_DIR/" || true 
                echo "✅ '$plist_name' inaktiverad och flyttad till '$DISABLED_PLIST_DIR/'"
              else
                echo "❌ '$plist_name' behålls aktiv."
              fi
            fi
          fi
        fi
      done
    fi
  done

  # Sök igenom Launch Daemon-sökvägar (endast /Library/LaunchDaemons för att undvika /System/)
  for p in "${LAUNCH_DAEMON_PATHS[@]}"; do
    local expanded_path=$(eval echo "$p")
    if [[ -d "$expanded_path" ]]; then
      for plist_file in "$expanded_path"/*.plist; do
        if [[ -f "$plist_file" ]]; then
          local plist_name=$(basename "$plist_file" .plist)
          # Exkludera Apple-specifika tjänster
          if ! [[ "$plist_name" =~ ^com\.apple\. ]]; then
            # Kolla om tjänsten är laddad (aktiv)
            if launchctl list | grep -q "$plist_name"; then
              plists_found+=("$plist_file")
              echo "Hittade aktiv tjänst: $(basename "$plist_file") (Sökväg: $plist_file)"
              i=$((i + 1))
              read -p "Vill du inaktivera '$plist_name'? (y/n) " -n 1 -r
              echo
              if [[ "$REPLY" =~ ^[Yy]$ ]]; then
                echo "Inaktiverar $plist_name..."
                launchctl unload -w "$plist_file" || true 
                mv "$plist_file" "$DISABLED_PLIST_DIR/" || true 
                echo "✅ '$plist_name' inaktiverad och flyttad till '$DISABLED_PLIST_DIR/'"
              else
                echo "❌ '$plist_name' behålls aktiv."
              fi
            fi
          fi
        fi
      done
    fi
  done

  if [[ "$i" -eq 0 ]]; then
    echo "Inga ytterligare aktiva, icke-Apple, bakgrundstjänster hittades i de angivna sökvägarna."
  fi
  echo
  echo "Avancerat läge slutfört."
  echo "Starta om datorn för att alla ändringar ska träda i kraft."
}

# Återställer en dynamiskt inaktiverad tjänst
undo_advanced_module() {
  local plist_full_path="$1" # Detta är den ORIGINAL-sökväg som användaren behöver ange
  local plist_name=$(basename "$plist_full_path")
  local original_dir=$(dirname "$plist_full_path") # Extrahera originalkatalogen

  if [[ -f "$DISABLED_PLIST_DIR/$plist_name" ]]; then
    if [[ -d "$original_dir" ]]; then
      echo "Återställer '$plist_name' från '$DISABLED_PLIST_DIR/' till dess originalplats '$original_dir'..."
      # Flytta tillbaka filen till dess ursprungliga katalog
      mv "$DISABLED_PLIST_DIR/$plist_name" "$original_dir/" || { echo "Fel: Kunde inte flytta tillbaka filen till '$original_dir/'. Kontrollera behörigheter." ; exit 1; }
      # Ladda tjänsten igen persistent
      launchctl load -w "$original_dir/$plist_name" || true
      echo "✅ '$plist_name' återställd och aktiverad. En omstart kan krävas för full effekt."
    else
      echo "❌ Ursprunglig katalog '$original_dir' finns inte. Kan inte återställa '$plist_name'."
      echo "Filen finns fortfarande i '$DISABLED_PLIST_DIR/$plist_name'. Vänligen flytta tillbaka den manuellt."
    fi
  else
    echo "❌ Filen '$plist_name' hittades inte i den inaktiverade mappen: '$DISABLED_PLIST_DIR/'."
    echo "Kontrollera att du angett den FULLSTÄNDIGA ORIGINAL-sökvägen (t.ex. /Library/LaunchAgents/com.example.service.plist)."
  fi
}

# Verifierar statusen för dynamiskt inaktiverade tjänster
verify_advanced_modules() {
  echo "🔍 Verifierar status för dynamiskt inaktiverade tjänster..."
  if [[ -d "$DISABLED_PLIST_DIR" ]]; then
    local count=0
    for plist_file_in_disabled_dir in "$DISABLED_PLIST_DIR"/*.plist; do
      if [[ -f "$plist_file_in_disabled_dir" ]]; then
        local plist_name=$(basename "$plist_file_in_disabled_dir" .plist)
        echo "Inaktiverad: $(basename "$plist_file_in_disabled_dir")"
        # Kontrollera om tjänsten fortfarande körs trots att filen är flyttad
        if launchctl list | grep -q "$plist_name"; then
          echo "  -> ❌ Fortfarande aktiv (kan kräva omstart eller manuell hantering)"
        else
          echo "  -> ✅ Inaktiv"
        fi
        count=$((count + 1))
      fi
    done
    if [[ "$count" -eq 0 ]]; then
      echo "Inga dynamiska tjänster är inaktiverade med detta verktyg."
    fi
  else
    echo "Ingen katalog för inaktiverade tjänster hittades: '$DISABLED_PLIST_DIR'."
    echo "Detta kan betyda att inga tjänster har inaktiverats med '--advanced' ännu, eller att katalogen har rensats (t.ex. vid omstart om den är i /tmp)."
  fi
}


# === Argumenthantering ===
AUTO=""
UNDO=""
VERIFY="no"
ADVANCED="no"
UNDO_ADVANCED=""
VERIFY_ADVANCED="no"

while [[ $# -gt 0 ]]; do
  case $1 in
    --auto) AUTO="$2"; shift 2 ;;
    --undo) UNDO="$2"; shift 2 ;;
    --verify) VERIFY="yes"; shift ;;
    --advanced) ADVANCED="yes"; shift ;;
    --undo-advanced) UNDO_ADVANCED="$2"; shift 2 ;;
    --verify-advanced) VERIFY_ADVANCED="yes"; shift ;;
    --help|-h) print_help; exit 0 ;;
    *) echo "❌ Okänt flagga: $1"; exit 1 ;;
  esac
done

need_root "$@"

if [[ "$VERIFY" == "yes" ]]; then
  echo "🔍 Verifierar standardmoduler…"
  for m in $MODULES; do verify_module "$m"; done
  exit 0
fi

if [[ -n "$UNDO" ]]; then
  undo_module "$UNDO"
  echo "✅ Återställde: $UNDO"
  exit 0
fi

if [[ -n "$AUTO" ]]; then
  if [[ "$AUTO" == "all" ]]; then
    for m in $MODULES; do apply_module "$m"; done
  else
    IFS=',' read -ra MODS <<< "$AUTO"
    for m in "${MODS[@]}"; do apply_module "$m"; done
  fi
  echo "✅ Auto-exekvering av standardmoduler slutförd."
  exit 0
fi

if [[ "$ADVANCED" == "yes" ]]; then
  advanced_interactive_disable
  exit 0
fi

if [[ -n "$UNDO_ADVANCED" ]]; then
  undo_advanced_module "$UNDO_ADVANCED"
  exit 0
fi

if [[ "$VERIFY_ADVANCED" == "yes" ]]; then
  verify_advanced_modules
  exit 0
fi

# Ingen interaktiv meny om inga flaggor matchar (originalbeteende)
echo "Du måste ange ett argument för att köra scriptet. Använd --help för att se tillgängliga kommandon."
print_help
exit 1

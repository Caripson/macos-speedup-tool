#!/bin/bash
set -euo pipefail

PROGRAM="$(basename "$0")"
MODULES="spotlight airplay siri gamecontroller reportcrash dashboard fx timemachine handoff icloudphotos"

print_help() {
  echo "$PROGRAM – macOS SpeedUp Tool"
  echo "Usage:"
  echo "  sudo ./speedup.sh                # interactive"
  echo "  sudo ./speedup.sh --auto all     # disable all"
  echo "  sudo ./speedup.sh --auto siri,fx # disable selected"
  echo "  sudo ./speedup.sh --undo siri    # restore a module"
  echo "  sudo ./speedup.sh --verify       # check status"
  echo "  sudo ./speedup.sh --help"
  echo
  echo "Modules:"
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
}

need_root() {
  [[ $EUID -eq 0 ]] || exec sudo "$0" "$@"
}

# === Verifieringsfunktioner ===
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

# === Åtgärdsfunktioner ===
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

# === Argumenthantering ===
AUTO=""
UNDO=""
VERIFY="no"

while [[ $# -gt 0 ]]; do
  case $1 in
    --auto) AUTO="$2"; shift 2 ;;
    --undo) UNDO="$2"; shift 2 ;;
    --verify) VERIFY="yes"; shift ;;
    --help|-h) print_help; exit 0 ;;
    *) echo "❌ Unknown flag: $1"; exit 1 ;;
  esac
done

need_root "$@"

if [[ "$VERIFY" == "yes" ]]; then
  echo "🔍 Verifierar moduler…"
  for m in $MODULES; do verify_module "$m"; done
  exit 0
fi

if [[ -n "$UNDO" ]]; then
  undo_module "$UNDO"
  echo "✅ Restored: $UNDO"
  exit 0
fi

if [[ -n "$AUTO" ]]; then
  if [[ "$AUTO" == "all" ]]; then
    for m in $MODULES; do apply_module "$m"; done
  else
    IFS=',' read -ra MODS <<< "$AUTO"
    for m in "${MODS[@]}"; do apply_module "$m"; done
  fi
  echo "✅ Auto execution complete"
  exit 0
fi

# Ingen interaktiv meny om inga flaggor matchar
print_help
exit 1


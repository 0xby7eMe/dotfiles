pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.UPower

// Network / bluetooth / battery summaries for the bar and control center.
Singleton {
    id: root

    // ---------- network ----------
    readonly property var devices: Networking.devices?.values ?? []
    readonly property var wired: devices.find(d => d.type === DeviceType.Wired && d.connected) ?? null
    readonly property var wifiDev: devices.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wifiNet: wifiDev?.networks?.values?.find(n => n.connected) ?? null
    readonly property bool wifiOn: Networking.wifiEnabled
    readonly property real signal: wifiNet?.signalStrength ?? 0

    readonly property string netIcon: wired ? "ethernet-port"
        : !wifiOn ? "wifi-off"
        : !wifiNet ? "wifi-zero"
        : wifiIcon(signal)
    readonly property string netLabel: wired ? "Ethernet" : wifiNet?.name ?? (wifiOn ? "Not connected" : "Off")

    function wifiIcon(strength: real): string {
        return strength > 0.66 ? "wifi" : strength > 0.33 ? "wifi-high" : "wifi-low";
    }

    function toggleWifi(): void {
        Networking.wifiEnabled = !Networking.wifiEnabled;
    }

    // ---------- bluetooth ----------
    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property bool btOn: btAdapter?.enabled ?? false
    readonly property var btConnected: (Bluetooth.devices?.values ?? []).filter(d => d.connected)
    readonly property string btIcon: !btOn ? "bluetooth-off" : btConnected.length > 0 ? "bluetooth-connected" : "bluetooth"
    readonly property string btLabel: !btAdapter ? "Unavailable" : !btOn ? "Off"
        : btConnected.length > 0 ? btConnected[0].name : "On"

    function toggleBt(): void {
        if (btAdapter)
            btAdapter.enabled = !btAdapter.enabled;
    }

    // ---------- airplane mode ----------
    readonly property bool airplane: !wifiOn && !btOn

    function toggleAirplane(): void {
        const on = !airplane;
        Networking.wifiEnabled = !on;
        if (btAdapter)
            btAdapter.enabled = !on;
    }

    // ---------- battery ----------
    readonly property var bat: UPower.displayDevice
    readonly property bool hasBattery: bat?.isLaptopBattery ?? false
    readonly property real batLevel: bat && bat.energyCapacity > 0 ? bat.energy / bat.energyCapacity : 0
    readonly property bool charging: !UPower.onBattery
    readonly property string batIcon: charging ? "battery-charging"
        : batLevel > 0.8 ? "battery-full"
        : batLevel > 0.45 ? "battery-medium"
        : batLevel > 0.15 ? "battery-low" : "battery-warning"

    // ---------- power profiles ----------
    readonly property int profile: PowerProfiles.profile
    readonly property string profileLabel: profile === PowerProfile.Performance ? "Performance"
        : profile === PowerProfile.PowerSaver ? "Power saver" : "Balanced"
    readonly property string profileIcon: profile === PowerProfile.Performance ? "zap"
        : profile === PowerProfile.PowerSaver ? "leaf" : "scale"

    function cycleProfile(): void {
        const order = [PowerProfile.PowerSaver, PowerProfile.Balanced];
        if (PowerProfiles.hasPerformanceProfile)
            order.push(PowerProfile.Performance);
        PowerProfiles.profile = order[(order.indexOf(profile) + 1) % order.length];
    }
}

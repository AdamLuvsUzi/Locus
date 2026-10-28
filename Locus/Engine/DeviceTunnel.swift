import Foundation

enum TunnelConfig {
    /// LocalDevVPN / SideStore-style loopback tunnel endpoint.
    static let defaultIP = "10.7.0.1"
    static let defaultsKey = "locus.targetDeviceIP"

    static var targetIP: String {
        let stored = UserDefaults.standard.string(forKey: defaultsKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let stored, !stored.isEmpty else { return defaultIP }
        return stored
    }

    /// The address Locus actually dials for the developer tunnel.
    ///
    /// LocalDevVPN shows two IPs: "Tunnel IP" (the phone's own end, e.g.
    /// 10.7.1.1) and "Device IP" (e.g. 10.7.0.1, which routes to the phone's
    /// developer services). Dialing the Tunnel IP connects the phone to itself
    /// on the wrong side and always fails with "Could not open the developer
    /// tunnel". If the saved value is one of the phone's own tunnel addresses,
    /// use the VPN's peer address instead, falling back to the default.
    static var resolvedDeviceIP: String {
        let configured = targetIP
        let ownAddresses = LocalDevVPN.localTunnelAddresses
        guard ownAddresses.contains(configured) else { return configured }
        if let detected = LocalDevVPN.detectedDeviceIP, !ownAddresses.contains(detected) {
            return detected
        }
        return configured == defaultIP ? configured : defaultIP
    }

    static func setTargetIP(_ value: String) {
        UserDefaults.standard.set(value, forKey: defaultsKey)
    }
}

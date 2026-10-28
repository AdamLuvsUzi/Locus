import Darwin
import Foundation
import UIKit

enum LocalDevVPN {
    static let appStoreURL = URL(string: "https://apps.apple.com/us/app/localdevvpn/id6755608044")!
    static let detectURL = URL(string: "localdevvpn://")!

    /// Starts the tunnel, then returns to Locus via `locus://`.
    static let enableURL = URL(string: "localdevvpn://enable?scheme=locus")!

    static var isInstalled: Bool {
        UIApplication.shared.canOpenURL(detectURL)
    }

    /// One IPv4 address on a network interface. For point-to-point interfaces
    /// (LocalDevVPN's utun), `peer` is the far end of the link.
    struct InterfaceAddress {
        let name: String
        let local: String
        let peer: String?
    }

    /// LocalDevVPN gives the phone one address on a utun (shown as "Tunnel IP",
    /// e.g. 10.7.1.1) and routes a second address (shown as "Device IP",
    /// e.g. 10.7.0.1) back to the phone's own developer services.
    /// The VPN is up when a utun carries a 10.7.x.x address, or when the
    /// configured device IP appears as a utun peer. This deliberately does NOT
    /// require the configured device IP to be a local address — the correct
    /// device IP is never local, which made the old check report
    /// "Not connected" for the right value and "Connected" for the wrong one.
    static var isConnected: Bool {
        let target = TunnelConfig.targetIP
        return tunnelInterfaces().contains { iface in
            iface.local.hasPrefix("10.7.") || iface.peer == target || iface.local == target
        }
    }

    /// The device IP Locus should dial, as reported by the live VPN interface,
    /// if it can be read (the utun's point-to-point peer).
    static var detectedDeviceIP: String? {
        for iface in tunnelInterfaces() {
            if let peer = iface.peer, !peer.isEmpty, peer != iface.local, peer != "0.0.0.0" {
                return peer
            }
        }
        return nil
    }

    /// The phone's own address(es) on the VPN — i.e. the "Tunnel IP".
    static var localTunnelAddresses: [String] {
        tunnelInterfaces().map(\.local)
    }

    static func openInstalled() {
        UIApplication.shared.open(enableURL)
    }

    static func openAppStore() {
        UIApplication.shared.open(appStoreURL)
    }

    /// Open LocalDevVPN to connect if installed; otherwise App Store.
    static func openOrInstall() {
        if isInstalled {
            openInstalled()
        } else {
            openAppStore()
        }
    }

    private static func tunnelInterfaces() -> [InterfaceAddress] {
        allIPv4Interfaces().filter { $0.name.hasPrefix("utun") || $0.local.hasPrefix("10.7.") }
    }

    private static func allIPv4Interfaces() -> [InterfaceAddress] {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return [] }
        defer { freeifaddrs(ifaddr) }

        var results: [InterfaceAddress] = []
        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let current = ptr {
            let interface = current.pointee
            if let addr = interface.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET),
               let local = numericHost(addr) {
                let name = String(cString: interface.ifa_name)
                var peer: String?
                if (interface.ifa_flags & UInt32(IFF_POINTOPOINT)) != 0,
                   let dst = interface.ifa_dstaddr,
                   dst.pointee.sa_family == UInt8(AF_INET) {
                    peer = numericHost(dst)
                }
                results.append(InterfaceAddress(name: name, local: local, peer: peer))
            }
            ptr = interface.ifa_next
        }
        return results
    }

    private static func numericHost(_ addr: UnsafeMutablePointer<sockaddr>) -> String? {
        var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let ok = getnameinfo(
            addr,
            socklen_t(MemoryLayout<sockaddr_in>.size),
            &host,
            socklen_t(host.count),
            nil,
            0,
            NI_NUMERICHOST
        ) == 0
        return ok ? String(cString: host) : nil
    }
}

import AppKit
import Foundation
if let argument = CommandLine.arguments.first(where: { $0.hasPrefix("--check-port=") }), let port = Int(argument.dropFirst(13)) {
    do { guard try PortMonitor.read().listeners.contains(where: { $0.port == port && $0.loopback }) else { throw PortFailure(message: "Live loopback listener not found") }; print("PASS: real TCP listener on port \(port)") }
    catch { fputs("FAIL: \(error)\n", stderr); exit(1) }
    exit(0)
}
if CommandLine.arguments.contains("--self-test") {
    do { try ProductTests.run(); print("PASS: \(Product.name) functional checks") }
    catch { fputs("FAIL: \(error)\n", stderr); exit(1) }
    exit(0)
}
if ProductCLI.handle() { exit(0) }
let application = NSApplication.shared
application.setActivationPolicy(.regular)
let delegate = AppDelegate()
application.delegate = delegate
application.run()

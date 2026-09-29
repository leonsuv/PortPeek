import Foundation

struct Listener: Codable, Hashable {
    let pid: Int, process: String, host: String, port: Int
    var id: String { "\(pid)|\(host)|\(port)" }
    var loopback: Bool { host.hasPrefix("127.") || host == "::1" || host == "localhost" }
    var wildcard: Bool { host == "*" || host == "0.0.0.0" || host == "::" }
    var address: String { "\(host.contains(":") ? "[\(host)]" : host):\(port)" }
}
enum ListenerParser {
    static func parse(_ output: String) -> [Listener] {
        var pid = 0, process = "", found: Set<Listener> = []
        for line in output.split(separator:"\n") {
            guard let kind = line.first else { continue }; let value = String(line.dropFirst())
            if kind == "p" { pid = Int(value) ?? 0; process = "" }
            else if kind == "c" { process = value }
            else if kind == "n", pid > 0, !process.isEmpty, let colon = value.lastIndex(of:":"), let port = Int(value[value.index(after:colon)...]), (1...65535).contains(port) {
                let host = String(value[..<colon]).trimmingCharacters(in:CharacterSet(charactersIn:"[]"))
                found.insert(Listener(pid:pid,process:process,host:host,port:port))
            }
        }
        return found.sorted { $0.port == $1.port ? ($0.pid == $1.pid ? $0.host < $1.host : $0.pid < $1.pid) : $0.port < $1.port }
    }
}
struct ListenerReport { let listeners: [Listener]; let message: String? }
final class PipeCapture: @unchecked Sendable {
    private let lock = NSLock(); private var value = Data()
    func store(_ data: Data) { lock.lock(); defer { lock.unlock() }; value = data }
    func read() -> Data { lock.lock(); defer { lock.unlock() }; return value }
}
enum PortMonitor {
    static func read() throws -> ListenerReport {
        let process = Process(); process.executableURL = URL(fileURLWithPath:"/usr/sbin/lsof"); process.arguments = ["-nP","-iTCP","-sTCP:LISTEN","-Fpcn"]
        let out = Pipe(), err = Pipe(); process.standardOutput = out; process.standardError = err
        try process.run()
        // Drain stderr concurrently so warnings cannot fill a pipe and block lsof.
        let errors = PipeCapture(); let group = DispatchGroup(); group.enter()
        DispatchQueue.global().async { errors.store(err.fileHandleForReading.readDataToEndOfFile()); group.leave() }
        let data = out.fileHandleForReading.readDataToEndOfFile(); process.waitUntilExit(); group.wait()
        let message = String(data:errors.read(),encoding:.utf8)?.trimmingCharacters(in:.whitespacesAndNewlines) ?? ""
        if process.terminationStatus != 0 && process.terminationStatus != 1 { throw NSError(domain:"PortPeek",code:Int(process.terminationStatus),userInfo:[NSLocalizedDescriptionKey:message.isEmpty ? "Could not inspect local listeners." : message]) }
        return ListenerReport(listeners:ListenerParser.parse(String(data:data,encoding:.utf8) ?? ""),message:message.isEmpty ? nil : message)
    }
}
struct PortFailure: Error { let message: String }
enum ProductTests {
    static func run() throws {
        let sample = "p4100\ncnode\nf10\nn127.0.0.1:3000\nf11\nn127.0.0.1:3000\np4200\ncpostgres\nn[::1]:5432\np4300\ncPython\nn*:8000\nnnot-a-port\npbad\ncunknown\nn*:20\n"
        let rows = ListenerParser.parse(sample)
        guard rows.count == 3 && rows.map(\.port) == [3000,5432,8000] && rows[0].loopback && rows[1].loopback && rows[2].wildcard else { throw PortFailure(message:"Process grouping, deduplication or IPv6 scope failed") }
        guard rows[1].address == "[::1]:5432" else { throw PortFailure(message:"IPv6 address formatting") }
        guard ListenerParser.parse("p1\nca\nn*:0\nn*:65536\n").isEmpty else { throw PortFailure(message:"Invalid port accepted") }
        let encoded = try JSONEncoder().encode(rows); guard try JSONDecoder().decode([Listener].self,from:encoded) == rows else { throw PortFailure(message:"JSON export fidelity") }
    }
}

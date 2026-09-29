import Foundation

struct Listener: Codable, Hashable {
    let pid: Int, process: String, host: String, port: Int
    var transport = "TCP"
    var id: String { "\(transport)|\(pid)|\(host)|\(port)" }
    var loopback: Bool { host.hasPrefix("127.") || host == "::1" || host == "localhost" }
    var wildcard: Bool { host == "*" || host == "0.0.0.0" || host == "::" }
    var address: String { "\(host.contains(":") ? "[\(host)]" : host):\(port)" }
}
enum ListenerParser {
    static func parse(_ output: String, transport: String = "TCP") -> [Listener] {
        var pid = 0, process = "", found: Set<Listener> = []
        for line in output.split(separator:"\n") {
            guard let kind = line.first else { continue }; let value = String(line.dropFirst())
            if kind == "p" { pid = Int(value) ?? 0; process = "" }
            else if kind == "c" { process = value }
            else if kind == "n", !value.contains("->"), pid > 0, !process.isEmpty, let colon = value.lastIndex(of:":"), let port = Int(value[value.index(after:colon)...]), (1...65535).contains(port) {
                let host = String(value[..<colon]).trimmingCharacters(in:CharacterSet(charactersIn:"[]"))
                found.insert(Listener(pid:pid,process:process,host:host,port:port,transport:transport))
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
    static func command(_ executable:String,_ arguments:[String]) throws -> (String,Int32,String) {
        let process=Process(); process.executableURL=URL(fileURLWithPath:executable); process.arguments=arguments
        let out=Pipe(),err=Pipe(); process.standardOutput=out; process.standardError=err; try process.run()
        let outputs=PipeCapture(),errors=PipeCapture(),group=DispatchGroup()
        group.enter(); DispatchQueue.global().async { outputs.store(out.fileHandleForReading.readDataToEndOfFile()); group.leave() }
        group.enter(); DispatchQueue.global().async { errors.store(err.fileHandleForReading.readDataToEndOfFile()); group.leave() }
        let deadline=Date().addingTimeInterval(8)
        while process.isRunning && Date()<deadline { Thread.sleep(forTimeInterval:0.03) }
        if process.isRunning { process.terminate(); Thread.sleep(forTimeInterval:0.1); if process.isRunning { kill(process.processIdentifier,SIGKILL) }; process.waitUntilExit(); group.wait(); throw PortFailure(message:"Inspection timed out after 8 seconds") }
        process.waitUntilExit(); group.wait()
        return (String(decoding:outputs.read(),as:UTF8.self),process.terminationStatus,String(decoding:errors.read(),as:UTF8.self).trimmingCharacters(in:.whitespacesAndNewlines))
    }
    static func read(transport:String = "TCP") throws -> ListenerReport {
        var rows:[Listener]=[],warnings:[String]=[]
        for mode in transport == "All" ? ["TCP","UDP"] : [transport] {
            guard ["TCP","UDP"].contains(mode) else { throw PortFailure(message:"Protocol must be TCP, UDP or All") }
            let arguments = ["-nP","-i"+mode] + (mode == "TCP" ? ["-sTCP:LISTEN"] : []) + ["-Fpcn"]
            let (output,status,message) = try command("/usr/sbin/lsof",arguments)
            guard status == 0 || status == 1 else { throw PortFailure(message:message.isEmpty ? "Could not inspect sockets" : message) }
            rows += ListenerParser.parse(output,transport:mode); if !message.isEmpty { warnings.append(message) }
        }
        return ListenerReport(listeners:rows,message:warnings.isEmpty ? nil : warnings.joined(separator:"; "))
    }
    static func details(_ row:Listener) throws -> String {
        let (value,status,error)=try command("/bin/ps",["-p",String(row.pid),"-o","user=,etime=,command="])
        guard status == 0 else { throw PortFailure(message:error.isEmpty ? "Process has exited" : error) }; return String(value.prefix(16000)).trimmingCharacters(in:.whitespacesAndNewlines)
    }
}
struct PortSnapshot: Codable { let date:Date; let listeners:[Listener] }
struct PortChanges { let opened:[Listener],closed:[Listener] }
enum PortExports {
    static func changes(before:[Listener],after:[Listener]) -> PortChanges { let a=Set(before),b=Set(after); return PortChanges(opened:after.filter{ !a.contains($0) },closed:before.filter{ !b.contains($0) }) }
    static func csv(_ rows:[Listener]) -> String { func quote(_ value:String)->String { "\""+(["=","+","-","@"].contains(String(value.first ?? " ")) ? "'" : "")+value.replacingOccurrences(of:"\"",with:"\"\"")+"\"" }; return "Protocol,Port,PID,Process,Address\n"+rows.map{ [quote($0.transport),String($0.port),String($0.pid),quote($0.process),quote($0.address)].joined(separator:",") }.joined(separator:"\n")+"\n" }

}
struct PortFailure: Error { let message: String }
enum ProductTests {
    static func run() throws {
        let sample = "p4100\ncnode\nf10\nn127.0.0.1:3000\nf11\nn127.0.0.1:3000\np4200\ncpostgres\nn[::1]:5432\np4300\ncPython\nn*:8000\nnnot-a-port\npbad\ncunknown\nn*:20\n"
        let rows = ListenerParser.parse(sample)
        guard rows.count == 3 && rows.map(\.port) == [3000,5432,8000] && rows[0].loopback && rows[1].loopback && rows[2].wildcard else { throw PortFailure(message:"Process grouping, deduplication or IPv6 scope failed") }
        guard rows[1].address == "[::1]:5432" else { throw PortFailure(message:"IPv6 address formatting") }
        guard ListenerParser.parse("p1\nca\nn*:0\nn*:65536\n").isEmpty else { throw PortFailure(message:"Invalid port accepted") }
        let udp=ListenerParser.parse("p12\ncserver\nn*:5353\nn127.0.0.1:44->127.0.0.1:55\n",transport:"UDP")
        guard udp.count == 1 && udp[0].transport == "UDP" && udp[0].id.hasPrefix("UDP|") else { throw PortFailure(message:"UDP bound socket parsing") }
        let change=PortExports.changes(before:rows,after:[rows[0]]+udp); guard change.opened == udp && change.closed.count == 2 else { throw PortFailure(message:"Snapshot difference") }
        guard PortExports.csv(udp).contains("UDP") else { throw PortFailure(message:"CSV protocol export") }
        let encoded = try JSONEncoder().encode(rows); guard try JSONDecoder().decode([Listener].self,from:encoded) == rows else { throw PortFailure(message:"JSON export fidelity") }
    }
}

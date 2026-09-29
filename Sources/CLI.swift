import Foundation
struct CLIError: LocalizedError { let message:String; var errorDescription:String? {message} }
struct CLIOptions {
    let values:[String:String]; let flags:Set<String>
    init(_ args:[String], allowed:Set<String>, flags allowedFlags:Set<String> = []) throws {
        var values:[String:String]=[:],flags:Set<String>=[]
        for arg in args {
            guard arg.hasPrefix("--") else {throw CLIError(message:"Options use --name=value syntax")}
            let parts=String(arg.dropFirst(2)).split(separator:"=",maxSplits:1,omittingEmptySubsequences:false)
            let key=String(parts[0]); guard values[key] == nil,!flags.contains(key) else{throw CLIError(message:"Duplicate option: "+key)}
            if parts.count==2,allowed.contains(key){values[key]=String(parts[1])}
            else if parts.count==1,allowedFlags.contains(key){flags.insert(key)}
            else{throw CLIError(message:"Unknown option: "+arg)}
        }
        self.values=values;self.flags=flags
    }
    func required(_ key:String)throws->String{guard let value=values[key],!value.isEmpty else{throw CLIError(message:"Missing --"+key+"=value")};return value}
    func url(_ key:String)throws->URL{URL(fileURLWithPath:try required(key))}
    var excludes:Set<String>{Set((values["exclude"] ?? "").split(separator:",").map(String.init))}
}
func cliJSON<T:Encodable>(_ value:T)throws{let e=JSONEncoder();e.outputFormatting=[.prettyPrinted,.sortedKeys];e.dateEncodingStrategy = .iso8601;print(String(decoding:try e.encode(value),as:UTF8.self))}
func cliObject(_ value:[String:Any])throws{print(String(decoding:try JSONSerialization.data(withJSONObject:value,options:[.prettyPrinted,.sortedKeys]),as:UTF8.self))}
enum ProductCLI {
    static func handle() -> Bool {
        let args=Array(CommandLine.arguments.dropFirst());guard let command=args.first,!command.hasPrefix("--") || command=="--help" else{return false}
        do {try run(command,Array(args.dropFirst()));return true} catch {fputs("Error: \(error.localizedDescription)\n",stderr);exit(1)}
    }
    static func run(_ command:String,_ args:[String]) throws {
        if command=="--help"{print("PortPeek list [--protocol=TCP|UDP|All] [--port=3000] [--scope=all|loopback|wildcard] [--format=json|csv]\nRead-only local socket inspection. No elevated privileges are requested.");return}
        guard command=="list" else{throw CLIError(message:"Use list or --help")};let o=try CLIOptions(args,allowed:["protocol","port","scope","format"])
        let report=try PortMonitor.read(transport:o.values["protocol"] ?? "All");if let warning=report.message{fputs("Partial results: "+warning+"\n",stderr)};var rows=report.listeners
        if let value=o.values["port"]{guard let port=Int(value),(1...65535).contains(port) else{throw CLIError(message:"Invalid port")};rows=rows.filter{$0.port==port}}
        switch o.values["scope"] ?? "all"{case "all":break;case "loopback":rows=rows.filter(\.loopback);case "wildcard":rows=rows.filter(\.wildcard);default:throw CLIError(message:"scope must be all, loopback or wildcard")}
        switch o.values["format"] ?? "json"{case "json":try cliJSON(PortSnapshot(date:Date(),listeners:rows));case "csv":print(PortExports.csv(rows),terminator:"");default:throw CLIError(message:"format must be json or csv")}
    }
}

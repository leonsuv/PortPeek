import AppKit

final class AppDelegate: ProductAppDelegate, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
    var listeners: [Listener] = [], shown: [Listener] = []
    var table: NSTableView!, search: NSSearchField!, scope: NSSegmentedControl!, status: NSTextField!, inspector: NSTextField!, copyButton: NSButton!
    var portsMetric: Metric!, processesMetric: Metric!, networkMetric: Metric!, refreshButton: NSButton!, timer: Timer?, reading = false
    override func buildWindow() {
        makeWindow(width:1180,height:740,minWidth:940,minHeight:640)
        let root = NSView(); window.contentView = root
        let heading = vertical([text("Know what's listening.",28,.semibold),text("Find the process behind every local TCP port.",13,color:.secondaryLabelColor)],spacing:8)
        refreshButton = button("Refresh", "arrow.clockwise",target:self,action:#selector(refresh)); refreshButton.keyEquivalent = "r"
        search = NSSearchField(); search.placeholderString = "Search port, process, PID or address"; search.delegate = self; search.widthAnchor.constraint(equalToConstant:270).isActive = true
        let header = horizontal([horizontal([symbol("network",size:24),heading],spacing:16),spacer(),refreshButton])
        portsMetric = Metric("PORTS",value:"—",icon:"number"); processesMetric = Metric("PROCESSES",value:"—",icon:"app.connected.to.app.below.fill"); networkMetric = Metric("ALL-INTERFACE LISTENERS",value:"—",icon:"network")
        let metrics = horizontal([portsMetric,processesMetric,networkMetric],spacing:12); metrics.distribution = .fillEqually
        scope = NSSegmentedControl(labels:["All listeners","Loopback","All interfaces"],trackingMode:.selectOne,target:self,action:#selector(filter)); scope.selectedSegment = 0
        let controls = horizontal([scope,spacer(),search])
        table = makeTable([("port","Port",100),("process","Process",280),("pid","PID",110),("address","Listening address",260),("scope","Scope",160)]); table.dataSource = self; table.delegate = self
        let tableCard = Surface(scroll(table),padding:0)
        inspector = text("Select a listener to inspect its address and process.",13,color:.secondaryLabelColor); inspector.maximumNumberOfLines = 2; inspector.lineBreakMode = .byWordWrapping
        copyButton = button("Copy address", "doc.on.doc",target:self,action:#selector(copyAddress)); copyButton.isEnabled = false
        let copyJSON = button("Copy list as JSON", "curlybraces",target:self,action:#selector(copyList)); let monitor = button("Activity Monitor", "waveform.path.ecg",target:self,action:#selector(openMonitor))
        let actions = horizontal([inspector,spacer(),copyButton]); let inspectorSurface = Surface(actions,padding:18)
        status = text(isDemo ? "Preview · example listeners. No process data was collected." : "Reading local listeners…",11,color:.secondaryLabelColor)
        let bottom = horizontal([status,spacer(),copyJSON,monitor])
        let body = vertical([header,metrics,controls,tableCard,inspectorSurface,bottom],spacing:20)
        for view in [header,metrics,controls,tableCard,inspectorSurface,bottom] { fullWidth(view,body) }
        root.addSubview(body); body.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([body.leadingAnchor.constraint(equalTo:root.leadingAnchor,constant:28),body.trailingAnchor.constraint(equalTo:root.trailingAnchor,constant:-28),body.topAnchor.constraint(equalTo:(window.contentLayoutGuide as! NSLayoutGuide).topAnchor,constant:28),body.bottomAnchor.constraint(equalTo:root.bottomAnchor,constant:-24)])
        if isDemo {
            listeners = [Listener(pid:4102,process:"node",host:"127.0.0.1",port:3000),Listener(pid:4102,process:"node",host:"::1",port:3000),Listener(pid:4381,process:"postgres",host:"127.0.0.1",port:5432),Listener(pid:4620,process:"Python",host:"*",port:8000),Listener(pid:4714,process:"ruby",host:"127.0.0.1",port:9292),Listener(pid:4880,process:"redis-server",host:"127.0.0.1",port:6379)]
            filter(); table.selectRowIndexes(IndexSet(integer:0),byExtendingSelection:false)
        } else { refresh(); timer = Timer.scheduledTimer(withTimeInterval:5,repeats:true) { [weak self] _ in guard let self, self.window.isVisible else { return }; self.refresh() } }
    }
    @objc func refresh() {
        guard !isDemo, !reading else { return }; reading = true; refreshButton.isEnabled = false
        DispatchQueue.global(qos:.utility).async { [weak self] in
            let result = Result { try PortMonitor.read() }
            DispatchQueue.main.async { guard let self else { return }; self.reading = false; self.refreshButton.isEnabled = true
                switch result { case .success(let report): self.listeners = report.listeners; self.filter(); self.status.stringValue = report.message == nil ? "Updated \(Date().formatted(date:.omitted,time:.standard)) · automatic refresh every 5 seconds · read-only" : "Partial results: \(report.message!)"; self.status.toolTip = report.message
                case .failure(let error): self.status.stringValue = "Could not refresh: \(error.localizedDescription)"; self.status.toolTip = error.localizedDescription }
            }
        }
    }
    func controlTextDidChange(_ obj: Notification) { filter() }
    @objc func filter() {
        let selection = selected?.id, query = search.stringValue.lowercased()
        shown = listeners.filter { listener in
            let matchesScope = scope.selectedSegment == 0 || (scope.selectedSegment == 1 ? listener.loopback : listener.wildcard)
            return matchesScope && (query.isEmpty || "\(listener.port) \(listener.process) \(listener.pid) \(listener.host)".lowercased().contains(query))
        }.sorted { $0.port == $1.port ? $0.pid < $1.pid : $0.port < $1.port }
        table.reloadData(); if let selection,let row = shown.firstIndex(where: { $0.id == selection }) { table.selectRowIndexes(IndexSet(integer:row),byExtendingSelection:false) } else { table.deselectAll(nil) }
        portsMetric.value.stringValue = String(Set(listeners.map(\.port)).count); processesMetric.value.stringValue = String(Set(listeners.map(\.pid)).count); networkMetric.value.stringValue = String(listeners.filter(\.wildcard).count)
        tableViewSelectionDidChange(Notification(name:NSTableView.selectionDidChangeNotification))
    }
    var selected: Listener? { guard table != nil, shown.indices.contains(table.selectedRow) else { return nil }; return shown[table.selectedRow] }
    func tableViewSelectionDidChange(_ notification: Notification) { copyButton.isEnabled = selected != nil; if let row = selected { inspector.stringValue = "\(row.process) · PID \(row.pid)\n\(row.address) · \(row.wildcard ? "Listening on all interfaces" : row.loopback ? "Local connections only" : "Bound to a specific interface")" } else { inspector.stringValue = shown.isEmpty ? "No listeners match this view." : "Select a listener to inspect its address and process." } }
    @objc func copyAddress() { guard let row = selected else { return }; NSPasteboard.general.clearContents(); NSPasteboard.general.setString(row.address,forType:.string) }
    @objc func copyList() { guard let data = try? JSONEncoder().encode(shown),let string = String(data:data,encoding:.utf8) else { return }; NSPasteboard.general.clearContents(); NSPasteboard.general.setString(string,forType:.string); status.stringValue = "Copied \(shown.count) visible listeners as JSON." }
    @objc func openMonitor() { NSWorkspace.shared.open(URL(fileURLWithPath:"/System/Applications/Utilities/Activity Monitor.app")) }
    func numberOfRows(in tableView: NSTableView) -> Int { shown.count }
    func tableView(_ tableView: NSTableView,viewFor column:NSTableColumn?,row:Int) -> NSView? { let listener = shown[row]; switch column?.identifier.rawValue { case "port":return cell(String(listener.port),color:Product.accent,bold:true); case "process":return cell(listener.process,bold:true);case "pid":return cell(String(listener.pid),color:.secondaryLabelColor);case "address":return cell(listener.address);default:return cell(listener.wildcard ? "All interfaces" : listener.loopback ? "Loopback" : "Specific interface",color:.secondaryLabelColor) } }
}

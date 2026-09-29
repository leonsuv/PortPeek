import AppKit

final class AppDelegate: ProductAppDelegate, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
    var listeners: [Listener] = [], shown: [Listener] = []
    var table: NSTableView!, search: NSSearchField!, scope: NSSegmentedControl!, status: NSTextField!, inspector: NSTextField!, copyButton: NSButton!
    var transport:NSPopUpButton!, interval:NSPopUpButton!, pinnedOnly:NSButton!, labelField:NSTextField!, pinButton:NSButton!, delta:NSTextField!
    var pins:Set<Int>=[], labels:[String:String]=[:], baseline:PortSnapshot?, changes=PortChanges(opened:[],closed:[]), hasRead=false
    var portsMetric: Metric!, processesMetric: Metric!, networkMetric: Metric!, refreshButton: NSButton!, timer: Timer?, reading = false
    override func buildWindow() {
        makeWindow(width:1260,height:900,minWidth:1080,minHeight:810)
        let root = NSView(); window.contentView = root
        let heading = vertical([text("Know what's listening.",28,.semibold),text("Inspect TCP listeners, bound UDP sockets and changes over time.",13,color:.secondaryLabelColor)],spacing:8)
        refreshButton = button("Refresh", "arrow.clockwise",target:self,action:#selector(refresh)); refreshButton.keyEquivalent = "r"
        search = NSSearchField(); search.placeholderString = "Search port, process, PID or address"; search.delegate = self; search.widthAnchor.constraint(equalToConstant:270).isActive = true
        let header = horizontal([horizontal([symbol("network",size:24),heading],spacing:16),spacer(),refreshButton])
        portsMetric = Metric("PORTS",value:"—",icon:"number"); processesMetric = Metric("PROCESSES",value:"—",icon:"app.connected.to.app.below.fill"); networkMetric = Metric("ALL-INTERFACE LISTENERS",value:"—",icon:"network")
        let metrics = horizontal([portsMetric,processesMetric,networkMetric],spacing:12); metrics.distribution = .fillEqually
        scope = NSSegmentedControl(labels:["All listeners","Loopback","All interfaces"],trackingMode:.selectOne,target:self,action:#selector(filter)); scope.selectedSegment = 0
        transport=NSPopUpButton(); transport.addItems(withTitles:["TCP + UDP","TCP","UDP"]); transport.target=self; transport.action=#selector(filter)
        interval=NSPopUpButton(); interval.addItems(withTitles:["Refresh: 5 sec","Refresh: 15 sec","Refresh: 30 sec","Manual refresh"]); interval.target=self; interval.action=#selector(changeInterval)
        pinnedOnly=NSButton(checkboxWithTitle:"Pinned only",target:self,action:#selector(filter))
        if !isDemo { pins=Set(UserDefaults.standard.array(forKey:"pins") as? [Int] ?? []); labels=UserDefaults.standard.dictionary(forKey:"labels") as? [String:String] ?? [:]; if let data=UserDefaults.standard.data(forKey:"baseline") { baseline=try? JSONDecoder().decode(PortSnapshot.self,from:data) } }
        let controls = horizontal([scope,spacer(),search])
        let monitoring = horizontal([transport,interval,pinnedOnly,spacer(),button("Capture baseline",target:self,action:#selector(captureBaseline)),button("Export changes…",target:self,action:#selector(exportChanges))])
        delta=text("Capture a baseline to compare future observations.",12,color:.secondaryLabelColor)
        table = makeTable([("protocol","Protocol",85),("port","Port",100),("process","Process",280),("pid","PID",110),("address","Listening address",260),("scope","Scope",160)]); table.dataSource = self; table.delegate = self
        let tableCard = Surface(scroll(table),padding:0)
        inspector = text("Select a listener to inspect its address and process.",13,color:.secondaryLabelColor); inspector.maximumNumberOfLines = 4; inspector.lineBreakMode = .byWordWrapping
        copyButton = button("Copy address", "doc.on.doc",target:self,action:#selector(copyAddress)); copyButton.isEnabled = false
        let copyJSON = button("Copy list as JSON", "curlybraces",target:self,action:#selector(copyList)); let monitor = button("Activity Monitor", "waveform.path.ecg",target:self,action:#selector(openMonitor))
        inspector.font = .monospacedSystemFont(ofSize:12,weight:.regular); inspector.heightAnchor.constraint(equalToConstant:78).isActive=true
        labelField=NSTextField(string:""); labelField.placeholderString="Label this port, e.g. API / Postgres"; labelField.target=self; labelField.action=#selector(saveLabel)
        pinButton=button("Pin port", "pin",target:self,action:#selector(togglePin))
        let actions=horizontal([labelField,pinButton,button("Save label",target:self,action:#selector(saveLabel)),copyButton,button("Inspect process",target:self,action:#selector(processDetails)),button("Copy Terminal command",target:self,action:#selector(copyCommand))])
        let detail=vertical([inspector,actions]); fullWidth(inspector,detail); fullWidth(actions,detail); let inspectorSurface=Surface(detail,padding:18)
        status = text(isDemo ? "Preview · example listeners. No process data was collected." : "Reading local listeners…",11,color:.secondaryLabelColor)
        let bottom = horizontal([status,spacer(),button("Export CSV…",target:self,action:#selector(exportCSV)),button("Export JSON…",target:self,action:#selector(exportJSON)),copyJSON,monitor])
        let body = vertical([header,metrics,controls,monitoring,delta!,tableCard,inspectorSurface,bottom],spacing:20)
        for view in [header,metrics,controls,monitoring,delta!,tableCard,inspectorSurface,bottom] { fullWidth(view,body) }
        root.addSubview(body); body.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([body.leadingAnchor.constraint(equalTo:root.leadingAnchor,constant:28),body.trailingAnchor.constraint(equalTo:root.trailingAnchor,constant:-28),body.topAnchor.constraint(equalTo:(window.contentLayoutGuide as! NSLayoutGuide).topAnchor,constant:28),body.bottomAnchor.constraint(equalTo:root.bottomAnchor,constant:-24)])
        if isDemo {
            pins=[3000,5432]; labels=["3000":"Frontend","5432":"Local database"]; listeners = [Listener(pid:4102,process:"node",host:"127.0.0.1",port:3000),Listener(pid:4102,process:"node",host:"::1",port:3000),Listener(pid:4381,process:"postgres",host:"127.0.0.1",port:5432),Listener(pid:4620,process:"Python",host:"*",port:8000),Listener(pid:4714,process:"ruby",host:"127.0.0.1",port:9292),Listener(pid:4880,process:"redis-server",host:"127.0.0.1",port:6379)]
            listeners.append(Listener(pid:4990,process:"mDNSResponder",host:"*",port:5353,transport:"UDP")); baseline=PortSnapshot(date:Date().addingTimeInterval(-300),listeners:Array(listeners.dropLast())); updateChanges(); filter(); table.selectRowIndexes(IndexSet(integer:0),byExtendingSelection:false)
        } else { refresh(); changeInterval() }
    }
    @objc func refresh() {
        guard !isDemo, !reading else { return }; reading = true; refreshButton.isEnabled = false
        DispatchQueue.global(qos:.utility).async { [weak self] in
            let result = Result { try PortMonitor.read(transport:"All") }
            DispatchQueue.main.async { guard let self else { return }; self.reading = false; self.refreshButton.isEnabled = true
                switch result { case .success(let report): self.listeners = report.listeners; self.hasRead=true; self.updateChanges(); self.filter(); self.status.stringValue = report.message == nil ? "Updated \(Date().formatted(date:.omitted,time:.standard)) · read-only" : "Partial results: \(report.message!)"; self.status.toolTip = report.message
                case .failure(let error): self.status.stringValue = "Could not refresh: \(error.localizedDescription)"; self.status.toolTip = error.localizedDescription }
            }
        }
    }
    func controlTextDidChange(_ obj: Notification) { filter() }
    @objc func filter() {
        let selection = selected?.id, query = search.stringValue.lowercased()
        shown = listeners.filter { listener in
            let matchesScope = scope.selectedSegment == 0 || (scope.selectedSegment == 1 ? listener.loopback : listener.wildcard)
            return matchesScope && (transport.indexOfSelectedItem == 0 || listener.transport == transport.titleOfSelectedItem) && (pinnedOnly.state != .on || pins.contains(listener.port)) && (query.isEmpty || "\(listener.port) \(listener.process) \(listener.pid) \(listener.host) \(labels[String(listener.port)] ?? "")".lowercased().contains(query))
        }.sorted { $0.port == $1.port ? $0.pid < $1.pid : $0.port < $1.port }
        table.reloadData(); if let selection,let row = shown.firstIndex(where: { $0.id == selection }) { table.selectRowIndexes(IndexSet(integer:row),byExtendingSelection:false) } else { table.deselectAll(nil) }
        portsMetric.value.stringValue = String(Set(listeners.map(\.port)).count); processesMetric.value.stringValue = String(Set(listeners.map(\.pid)).count); networkMetric.value.stringValue = String(listeners.filter(\.wildcard).count)
        tableViewSelectionDidChange(Notification(name:NSTableView.selectionDidChangeNotification))
    }
    var selected: Listener? { guard table != nil, shown.indices.contains(table.selectedRow) else { return nil }; return shown[table.selectedRow] }
    func tableViewSelectionDidChange(_ notification: Notification) { copyButton.isEnabled = selected != nil; pinButton.isEnabled=selected != nil; labelField.isEnabled=selected != nil; labelField.stringValue=selected.flatMap{ labels[String($0.port)] } ?? ""; pinButton.title=selected.map{ pins.contains($0.port) ? "Unpin port" : "Pin port" } ?? "Pin port"; if let row = selected { inspector.stringValue = "\(row.process) · PID \(row.pid)\n\(row.transport) \(row.address) · \(row.wildcard ? "Listening on all interfaces" : row.loopback ? "Local connections only" : "Bound to a specific interface")" } else { inspector.stringValue = shown.isEmpty ? "No listeners match this view." : "Select a listener to inspect its address and process." } }
    @objc func changeInterval() { timer?.invalidate(); guard !isDemo,interval.indexOfSelectedItem<3 else{return}; timer=Timer.scheduledTimer(withTimeInterval:Double([5,15,30][interval.indexOfSelectedItem]),repeats:true){[weak self] _ in guard let self,self.window.isVisible else{return};self.refresh()} }
    @objc func togglePin(){guard !isDemo,let row=selected else{return};if pins.contains(row.port){pins.remove(row.port)}else{pins.insert(row.port)};UserDefaults.standard.set(Array(pins),forKey:"pins");filter()}
    @objc func saveLabel(){guard !isDemo,let row=selected else{return};labels[String(row.port)]=String(labelField.stringValue.prefix(100));UserDefaults.standard.set(labels,forKey:"labels");filter()}
    @objc func captureBaseline(){guard !isDemo,hasRead,!reading else{return};baseline=PortSnapshot(date:Date(),listeners:listeners);if let data=try? JSONEncoder().encode(baseline){UserDefaults.standard.set(data,forKey:"baseline")};updateChanges()}
    func updateChanges(){guard let baseline else{return};changes=PortExports.changes(before:baseline.listeners,after:listeners);delta.stringValue="Since \(baseline.date.formatted(date:.abbreviated,time:.shortened)): \(changes.opened.count) opened · \(changes.closed.count) closed · pinned ports: \(pins.count)"}
    @objc func processDetails(){guard !isDemo,let row=selected else{return};inspector.stringValue="Reading process \(row.pid)…";DispatchQueue.global(qos:.utility).async{let result=Result{try PortMonitor.details(row)};DispatchQueue.main.async{guard self.selected?.id==row.id else{return};switch result{case .success(let value):self.inspector.stringValue="\(row.transport) \(row.address) · PID \(row.pid)\nUser · elapsed time · command\n"+value;self.inspector.toolTip=value;case .failure(let error):self.inspector.stringValue=error.localizedDescription}}}}
    @objc func copyCommand(){guard let row=selected else{return};NSPasteboard.general.clearContents();NSPasteboard.general.setString("lsof -nP -i\(row.transport):\(row.port)"+(row.transport=="TCP" ? " -sTCP:LISTEN" : ""),forType:.string)}
    func exportData(_ data:Data,name:String){guard !isDemo else{return};let panel=NSSavePanel();panel.nameFieldStringValue=name;panel.beginSheetModal(for:window){response in guard response == .OK,let url=panel.url else{return};do{try data.write(to:url,options:.withoutOverwriting);self.status.stringValue="Exported \(name)"}catch{self.alert("Export failed",error.localizedDescription)}}}
    @objc func exportCSV(){exportData(Data(PortExports.csv(shown).utf8),name:"PortPeek.csv")}
    @objc func exportJSON(){guard let data=try? JSONEncoder().encode(PortSnapshot(date:Date(),listeners:shown)) else{return};exportData(data,name:"PortPeek.json")}
    @objc func exportChanges(){guard let baseline else{status.stringValue="Capture a baseline first.";return};let object:[String:Any] = ["baseline":baseline.date.description,"observed":Date().description,"opened":changes.opened.map{["protocol":$0.transport,"pid":String($0.pid),"port":String($0.port),"process":$0.process,"address":$0.address]},"closed":changes.closed.map{["protocol":$0.transport,"pid":String($0.pid),"port":String($0.port),"process":$0.process,"address":$0.address]}];if let data=try? JSONSerialization.data(withJSONObject:object,options:[.prettyPrinted,.sortedKeys]){exportData(data,name:"PortPeek-changes.json")}}
    @objc func copyAddress() { guard let row = selected else { return }; NSPasteboard.general.clearContents(); NSPasteboard.general.setString(row.address,forType:.string) }
    @objc func copyList() { guard let data = try? JSONEncoder().encode(shown),let string = String(data:data,encoding:.utf8) else { return }; NSPasteboard.general.clearContents(); NSPasteboard.general.setString(string,forType:.string); status.stringValue = "Copied \(shown.count) visible listeners as JSON." }
    @objc func openMonitor() { NSWorkspace.shared.open(URL(fileURLWithPath:"/System/Applications/Utilities/Activity Monitor.app")) }
    func numberOfRows(in tableView: NSTableView) -> Int { shown.count }
    func tableView(_ tableView: NSTableView,viewFor column:NSTableColumn?,row:Int) -> NSView? { let listener = shown[row]; switch column?.identifier.rawValue { case "protocol":return cell(listener.transport,color:.secondaryLabelColor); case "port":return cell(String(listener.port),color:Product.accent,bold:true); case "process":return cell(listener.process+(labels[String(listener.port)].map{" · "+$0} ?? "")+(pins.contains(listener.port) ? " ★" : ""),bold:true);case "pid":return cell(String(listener.pid),color:.secondaryLabelColor);case "address":return cell(listener.address);default:return cell(listener.wildcard ? "All interfaces" : listener.loopback ? "Loopback" : "Specific interface",color:.secondaryLabelColor) } }
}

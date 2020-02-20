import Swift
import Cocoa
import CoreFoundation
import Commander

let basic = [kAXRoleAttribute, kAXTitleAttribute, kAXDescriptionAttribute, kAXValueAttribute]
let additional = [kAXSubroleAttribute, kAXPositionAttribute, kAXSizeAttribute]

func getAttribute(_ element: AXUIElement, _ name: String) -> AnyObject? {
    var value: AnyObject?
    AXUIElementCopyAttributeValue(element, name as CFString, &value)
    return value
}

func getAttributeAsString(_ element: AXUIElement, _ name: String) -> String {
    if let val = getAttribute(element, name) {
        if (val is String) {
            return val as? String ?? ""
        } else if (val is NSValue) {
            return String(format: "%d", val as? Int ?? 0)
        } else {
            let value = val as! AXValue
            let type = AXValueGetType(value);
            switch type {
            case .axError:
                var res: AXError = .success;
                AXValueGetValue(value, type, &res);
                return "\(res)"
            case .cfRange:
                var res: CFRange = CFRange();
                AXValueGetValue(value, type, &res);
                return "\(res)"
            case .cgPoint:
                var res: CGPoint = CGPoint.zero;
                AXValueGetValue(value, type, &res);
                return "\(res)"
            case .cgRect:
                var res: CGRect = CGRect.zero;
                AXValueGetValue(value, type, &res);
                return "\(res)"
            case .cgSize:
                var res: CGSize = CGSize.zero;
                AXValueGetValue(value, type, &res);
                return "\(res)"
            default:
                return "\(value)"
            }            
        }
    }

    return ""
}

func dumpTree(_ element: AXUIElement, _ attributes: [String], _ indent: Int = 0) {
	let prefixIndent = String(repeating: " ", count: indent)
    let roleDesc = getAttribute(element, kAXRoleDescriptionAttribute) as? String ?? "unknown"
    var details = [String]()
    for attr in attributes {
        let val = getAttributeAsString(element, attr)
        details.append("\(attr)=\(val)")
    }
    let detailsStr = details.joined(separator: " ")
    print("\(prefixIndent)\(roleDesc) : \(detailsStr)")
    let children = getAttribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
    for child in children {
    	dumpTree(child, attributes, indent + 1)
    }
}

func getRootElement(pid: Int, name: String) -> AXUIElement? {
    if let info = CGWindowListCopyWindowInfo([.excludeDesktopElements, .optionAll], kCGNullWindowID) as? [[ String : Any]] {
        var pids = [Int32](Set(info.map({ $0["kCGWindowOwnerPID"] as! Int32 })))
        pids.sort(by: >)
        for p in pids {
            if (pid != 0) {
                if (pid == p) {
                    return AXUIElementCreateApplication(p);
                }
            } else {
                let appRef = AXUIElementCreateApplication(p)
                if (name == getAttribute(appRef, kAXTitleAttribute) as? String ?? "") {
                    return appRef
                }
            }
        }
    }

    return nil
}

func findWebArea(_ element: AXUIElement) -> AXUIElement? {
    let role = getAttribute(element, kAXRoleAttribute) as? String ?? ""
    if (role == "AXWebArea") {
        return element;
    }
    let children = getAttribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
    for child in children {
        if let webArea = findWebArea(child) {
            return webArea
        }
    }

    return nil
}

let main = Group {
  $0.command("tree",
    Option("pid", default: 0, description: "Target app PID"),
    Option("app", default: "Nightly", description: "Target app name. Ignored if PID is provided"),
    Flag("web", description: "Only output web area subtree"),
    Flag("extras", description: "Show additional attributes"),
    VariadicOption<String>("attribute", description: "Show provided attributes")) { pid, app, web, extras, attributes in
        let attribs = (extras ? basic + additional : basic) + attributes
        if let appRef = getRootElement(pid:pid, name:app) {
            if (web) {
                if let webArea = findWebArea(appRef) {
                    dumpTree(webArea, attribs)
                } else {
                    print("No web area found.")
                }
            } else {
                dumpTree(appRef, attribs)
            }
        } else {
            print("No app found. Did you specify a name or PID?")
        }
  }

  $0.command("events") {
    print("Nothing here yet")
  }
}

main.run()
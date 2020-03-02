import Swift
import Cocoa
import CoreFoundation
import Commander

let basic = ["AXRole", "AXTitle", "AXDescription", "AXValue"]
let additional = [ "AXSelectedCells", "AXVisibleCells", "AXRowIndexRange",
    "AXColumnIndexRange", "AXCellForColumnAndRow", "AXBlockQuoteLevel",
    "AXAccessKey", "AXValueAutofilled", "AXValueAutofillAvailable",
    "AXValueAutofillType", "AXLanguage", "AXRequired", "AXInvalid", "AXGrabbed",
    "AXDateTimeValue", "AXInlineText", "AXDropEffects", "AXARIALive",
    "AXARIAAtomic", "AXARIARelevant", "AXElementBusy", "AXARIAPosInSet",
    "AXARIASetSize", "AXLoadingProgress", "AXHasPopup", "AXPopupValue",
    "AXPlaceholderValue", "AXTextMarkerIsValid", "AXIndexForTextMarker",
    "AXTextMarkerForIndex", "AXPath", "AXExpandedTextValue",
    "AXIsMultiSelectable", "AXDocumentURI", "AXDocumentEncoding",
    "AXARIAControls", "AXDOMIdentifier", "AXDOMClassList", "AXARIACurrent",
    "AXARIAColumnIndex", "AXARIARowIndex", "AXARIAColumnCount", "AXARIARowCount",
    "AXUIElementCountForSearchPredicate", "AXUIElementsForSearchPredicate",
    "AXEndTextMarkerForBounds", "AXStartTextMarkerForBounds",
    "AXLineTextMarkerRangeForTextMarker", "AXMisspellingTextMarkerRange",
    "AXSelectTextWithCriteria", "AXSearchTextWithCriteria", "AXTextOperation",
    "AXPreventKeyboardDOMEventDispatch", "AXCaretBrowsingEnabled",
    "AXWebSessionID", "AXFocusableAncestor", "AXEditableAncestor",
    "AXHighestEditableAncestor", "AXLinkRelationshipType", "AXRelativeFrame"]

// XXX: Let's use this later
let math = ["AXMathRootRadicand", "AXMathRootIndex", "AXMathFractionDenominator",
    "AXMathFractionNumerator", "AXMathBase", "AXMathSubscript",
    "AXMathSuperscript", "AXMathUnder", "AXMathOver", "AXMathFencedOpen",
    "AXMathFencedClose", "AXMathLineThickness", "AXMathPrescripts",
    "AXMathPostscripts"]

// XXX: AXChildrenInNavigationOrder
// XXX: AXOwns - we do this in our internal a11y tree.

let extents = ["AXPosition", "AXSize"]
func getAttribute(_ element: AXUIElement, _ name: String) -> AnyObject? {
    var value: AnyObject?
    AXUIElementCopyAttributeValue(element, name as CFString, &value)
    return value
}

func anyObjectToString(_ obj: AnyObject) -> String {
    if (obj is String) {
        return obj as? String ?? ""
    } else if (obj is NSValue) {
        return String(format: "%d", obj as? Int ?? 0)
    } else if (obj is NSArray) {
        var strArray: [String] = []
        for elm in (obj as? [AnyObject] ?? []) {
            strArray.append(anyObjectToString(elm))
        }
        return strArray.joined(separator:",")
    } else {
        let value = obj as! AXValue
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
            return "\(value) \(type)"
        }
    }
}

func getAttributeAsString(_ element: AXUIElement, _ name: String) -> String {
    if let val = getAttribute(element, name) {
        return anyObjectToString(val)
    }

    return ""
}

func dumpTree(_ element: AXUIElement, _ attributes: [String], _ actions: Bool, _ indent: Int = 0) {
	let prefixIndent = String(repeating: " ", count: indent)
    let roleDesc = getAttribute(element, "AXRoleDescription") as? String ?? "unknown"
    var details = [String]()
    for attr in attributes {
        let val = getAttributeAsString(element, attr)
        details.append("\(attr)=\(val)")
    }
    if (actions) {
        var actionNames: CFArray?
        AXUIElementCopyActionNames(element, &actionNames)
        let actionList = actionNames as? [String] ?? []
        details.append("actions=[\(actionList.joined(separator:","))]")
    }
    let detailsStr = details.joined(separator: " ")
    print("\(prefixIndent)\(roleDesc) : \(detailsStr)")
    let children = getAttribute(element, "AXChildren") as? [AXUIElement] ?? []
    for child in children {
    	dumpTree(child, attributes, actions, indent + 1)
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
                if (name == getAttribute(appRef, "AXTitle") as? String ?? "") {
                    return appRef
                }
            }
        }
    }

    return nil
}

func findWebArea(_ element: AXUIElement) -> AXUIElement? {
    let role = getAttribute(element, "AXRole") as? String ?? ""
    if (role == "AXWebArea") {
        return element;
    }
    let children = getAttribute(element, "AXChildren") as? [AXUIElement] ?? []
    for child in children {
        if let webArea = findWebArea(child) {
            return webArea
        }
    }

    return nil
}

let main = Group {
  $0.command("tree",    Option("pid", default: 0, description: "Target app PID"),
    Option("app", default: "Nightly", description: "Target app name. Ignored if PID is provided"),
    Flag("web", description: "Only output web area subtree"),
    Flag("extras", description: "Show additional attributes"),
    Flag("actions", description: "List supported actions"),
    VariadicOption<String>("attribute", description: "Show provided attributes")) { pid, app, web, extras, actions, attributes in
        let attribs = (extras ? basic + additional : basic) + attributes
        if let appRef = getRootElement(pid:pid, name:app) {
            if (web) {
                if let webArea = findWebArea(appRef) {
                    dumpTree(webArea, attribs, actions)
                } else {
                    print("No web area found.")
                }
            } else {
                dumpTree(appRef, attribs, actions)
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
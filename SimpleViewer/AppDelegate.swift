//
//  AppDelegate.swift
//  i678921465
//
//  Created by Carlos D. Santiago on 12/10/17.
//  Copyright © 2017 Carlos D. Santiago. All rights reserved.
//

import Cocoa

struct RequestUserStrings {
	let currentURL: String?
	let alertMessageText: String
	let alertButton1stText: String
	let alertButton1stInfo: String?
	let alertButton2ndText: String
	let alertButton2ndInfo: String?
	let alertButton3rdText: String?
	let alertButton3rdInfo: String?
}

fileprivate class URLField: NSTextField {
	override func mouseDown(with event: NSEvent) {
		super.mouseDown(with: event)
		if let textEditor = currentEditor() {
			textEditor.selectAll(self)
		}
	}
	
	convenience init(withValue: String?) {
		self.init()
		
		if let string = withValue {
			self.stringValue = string
		}
		self.lineBreakMode = NSLineBreakMode.byTruncatingHead
		self.usesSingleLineMode = true
	}
}

extension URL {
	var webloc : URL? {
		get {
			do {
				let data = try Data.init(contentsOf: self) as Data
				let dict = try! PropertyListSerialization.propertyList(from:data, options: [], format: nil) as! [String:Any]
				let urlString = dict["URL"] as! String
				return URL.init(string: urlString)
			}
			catch
			{
				return nil
			}
		}
	}
}

extension NSURL {
	
	func compare(_ other: URL ) -> ComparisonResult {
		return (self.absoluteString?.compare(other.absoluteString))!
	}
	//  https://stackoverflow.com/a/44908669/564870
	func resolvedFinderAlias() -> URL? {
		if (self.fileReferenceURL() != nil) { // item exists
			do {
				// Get information about the file alias.
				// If the file is not an alias files, an exception is thrown
				// and execution continues in the catch clause.
				let data = try NSURL.bookmarkData(withContentsOf: self as URL)
				// NSURLPathKey contains the target path.
				let rv = NSURL.resourceValues(forKeys: [ URLResourceKey.pathKey ], fromBookmarkData: data)
				var urlString = rv![URLResourceKey.pathKey] as! String
				if !urlString.hasPrefix("file://") {
					urlString = "file://" + urlString
				}
				return URL(string: urlString.addingPercentEncoding(withAllowedCharacters: NSCharacterSet.urlQueryAllowed)!)!
			} catch {
				// We know that the input path exists, but treating it as an alias
				// file failed, so we assume it's not an alias file so return nil.
				return nil
			}
		}
		return nil
	}
}

class DocumentController : NSDocumentController {
	override func typeForContents(of url: URL) throws -> String {
		return "DocumentType"
	}
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

	var fullScreen : NSRect? = nil
	@IBAction func toggleFullScreen(_ sender: NSMenuItem) {
		if let keyWindow = NSApp.keyWindow {
			if let last_rect = fullScreen {
				keyWindow.setFrame(last_rect, display: true, animate: true)
				fullScreen = nil;
			}
			else
			{
				fullScreen = keyWindow.frame
				keyWindow.setFrame(NSScreen.main()!.visibleFrame, display: true, animate: true)
			}
		}
	}
	
	func application(_ sender: NSApplication, openFile: String) -> Bool {
		let urlString = (openFile.hasPrefix("file://") ? openFile : "file://" + openFile)
		let fileURL = URL(string: urlString.addingPercentEncoding(withAllowedCharacters: NSCharacterSet.urlQueryAllowed)!)!
		return self.doOpenFile(fileURL: fileURL)
	}
	func doOpenFile(fileURL: URL,fromWindow: NSWindow? = nil) -> Bool {
		let doc = NSApp.keyWindow?.windowController?.document as? Document
		let webView = (NSApp.keyWindow?.contentView?.subviews.first) as? MyWebView
		let dc = NSDocumentController.shared()
		var status : Bool = false
		var itemURL = fileURL
		
		//	Bookmark a potential alias, and a webloc container
		//	so each can be read to derive the target url info.
		if isSandboxed() != storeBookmark(url: itemURL as URL) {
			Swift.print("Yoink, unable to bookmark (\(itemURL))")
			return false
		}
		if let original = (itemURL as NSURL).resolvedFinderAlias() {
			if isSandboxed() != storeBookmark(url: original as URL) {
				Swift.print("Yoink, unable to bookmark orignal (\(original))")
				return false
			}
			itemURL = original
		}
		if itemURL.absoluteString.hasSuffix("webloc"), let webURL = itemURL.webloc {
			itemURL = webURL
		}
		
		//	Overlay existing windows unless newWindows tells us not to
		if newWindows || webView == nil {
			//	Create doc, window controller, then load url via webkit
			do {
				let next = try dc.makeDocument(withContentsOf: itemURL, ofType: "DocumentType")
				next.makeWindowControllers()
				dc.addDocument(next)
				next.showWindows()
				status = true
				if let window = next.windowControllers.first?.window {
					NSApp.addWindowsItem(window, title: fileURL.lastPathComponent, filename: false)
				}
			}
			catch let error {
				NSApp.presentError(error)
				Swift.print("Yoink, unable to open doc for (\(String(describing: itemURL)))")
				status = false
			}
		}
		else
		{
			webView?.stopLoading()
			doc?.updateURL(url: itemURL)
			// MARK: - load(URLRequest:) of a fileURL does NOT WORK ON HIGH SIERRA 2nd time
			// instead use loadFileURL(itemURL, allowingReadAccessTo: itemURL)
			if self.loadByFileURL {
				webView?.loadFileURL(itemURL, allowingReadAccessTo: itemURL)
			}
			else
			{
				webView?.load(URLRequest(url: itemURL))

			}
			status = true
		}
		
		return status
	}
	
	func doOpenLocation(url: URL,fromWindow: NSWindow? = nil) -> Bool {
		let doc = NSApp.keyWindow?.windowController?.document as? Document
		let webView = (NSApp.keyWindow?.contentView?.subviews.first) as? MyWebView
		let dc = NSDocumentController.shared()
		var status : Bool = false
		var itemURL = url
		
		//	Bookmark a potential alias, and a webloc container
		//	so each can be read to derive the target url info.
		if itemURL.isFileURL {
			if isSandboxed() != storeBookmark(url: itemURL as URL) {
				Swift.print("Yoink, unable to bookmark (\(itemURL))")
				return false
			}
			if let original = (itemURL as NSURL).resolvedFinderAlias() {
				if isSandboxed() != storeBookmark(url: original as URL) {
					Swift.print("Yoink, unable to bookmark orignal (\(original))")
					return false
				}
				itemURL = original
			}
		}
		if itemURL.absoluteString.hasSuffix("webloc"), let webURL = itemURL.webloc {
			itemURL = webURL
		}
		
		//	Overlay existing windows unless newWindows tells us not to
		if newWindows || webView == nil {
			//	Create doc, window controller, then load url via webkit
			do {
				let next = try dc.makeDocument(withContentsOf: itemURL, ofType: "DocumentType")
				next.makeWindowControllers()
				dc.addDocument(next)
				next.showWindows()
				status = true
				if let window = next.windowControllers.first?.window {
					let newTitle = url.isFileURL ? url.lastPathComponent : url.absoluteString
					NSApp.addWindowsItem(window, title: newTitle, filename: false)
				}
			}
			catch let error {
				NSApp.presentError(error)
				Swift.print("Yoink, unable to open doc for (\(String(describing: itemURL)))")
				status = false
			}
		}
		else
		{
			webView?.stopLoading()
			doc?.updateURL(url: itemURL)
			// MARK: - load(URLRequest:) of a fileURL does NOT WORK ON HIGH SIERRA 2nd time
			// instead use loadFileURL(itemURL, allowingReadAccessTo: itemURL)
			if self.loadByFileURL {
				webView?.loadFileURL(itemURL, allowingReadAccessTo: itemURL)
			}
			else
			{
				webView?.load(URLRequest(url: itemURL))
				
			}
			status = true
		}
		
		return status
	}

	func didRequestUserUrl(_ strings: RequestUserStrings,
						   onWindow: NSWindow?,
						   acceptHandler: @escaping (String) -> Void) {
		
		// Create alert
		let alert = NSAlert()
		alert.alertStyle = NSAlertStyle.informational
		alert.messageText = strings.alertMessageText
		
		// Create urlField
		let urlField = URLField(withValue: strings.currentURL)
		urlField.frame = NSRect(x: 0, y: 0, width: 300, height: 20)
		
		// Add urlField and buttons to alert
		alert.accessoryView = urlField
		let alert1stButton = alert.addButton(withTitle: strings.alertButton1stText)
		if let alert1stToolTip = strings.alertButton1stInfo {
			alert1stButton.toolTip = alert1stToolTip
		}
		let alert2ndButton = alert.addButton(withTitle: strings.alertButton2ndText)
		if let alert2ndtToolTip = strings.alertButton2ndInfo {
			alert2ndButton.toolTip = alert2ndtToolTip
		}
		if let alert3rdText = strings.alertButton3rdText {
			let alert3rdButton = alert.addButton(withTitle: alert3rdText)
			if let alert3rdtToolTip = strings.alertButton3rdInfo {
				alert3rdButton.toolTip = alert3rdtToolTip
			}
		}
		
		if let urlWindow = onWindow {
			alert.beginSheetModal(for: urlWindow, completionHandler: { response in
				// buttons are accept, cancel, default
				if response == NSAlertThirdButtonReturn {
					var newUrl = (alert.buttons[2] as NSButton).toolTip
					newUrl = UrlHelpers.ensureScheme(newUrl!)
					if UrlHelpers.isValid(urlString: newUrl!) {
						acceptHandler(newUrl!)
					}
				}
				else
					if response == NSAlertFirstButtonReturn {
						// swiftlint:disable:next force_cast
						var newUrl = (alert.accessoryView as! NSTextField).stringValue
						newUrl = UrlHelpers.ensureScheme(newUrl)
						if UrlHelpers.isValid(urlString: newUrl) {
							acceptHandler(newUrl)
						}
				}
			})
		}
		else
		{
			switch alert.runModal() {
			case NSAlertThirdButtonReturn:
				var newUrl = (alert.buttons[2] as NSButton).toolTip
				newUrl = UrlHelpers.ensureScheme(newUrl!)
				if UrlHelpers.isValid(urlString: newUrl!) {
					acceptHandler(newUrl!)
				}
				
				break
				
			case NSAlertFirstButtonReturn:
				var newUrl = (alert.accessoryView as! NSTextField).stringValue
				newUrl = UrlHelpers.ensureScheme(newUrl)
				if UrlHelpers.isValid(urlString: newUrl) {
					acceptHandler(newUrl)
				}
				
			default:// NSAlertSecondButtonReturn:
				return
			}
		}
		
		// Set focus on urlField
		alert.accessoryView!.becomeFirstResponder()
	}
	@IBAction func loadURL(_ sender: AnyObject) {
		didRequestUserUrl(RequestUserStrings (
			currentURL: UserSettings.homePageURL.value,
			alertMessageText: "Enter URL",
			alertButton1stText: "Load",     alertButton1stInfo: nil,
			alertButton2ndText: "Cancel",   alertButton2ndInfo: nil,
			alertButton3rdText: "Home",     alertButton3rdInfo: UserSettings.homePageURL.value),
						  onWindow: NSApp.keyWindow as? NSPanel,
						  acceptHandler: { (newUrl: String) in
							_ = self.doOpenLocation(url: URL.init(string: newUrl)!)
		})
	}

	
	@IBAction func newDocument(_ sender: AnyObject) {
		let dc = NSDocumentController.shared()
		do {
			let doc = try dc.makeUntitledDocument(ofType: "DocumentType")
			doc.makeWindowControllers()
			dc.addDocument(doc)
			let wc = doc.windowControllers.first
			let window : NSPanel = wc!.window as! NSPanel as NSPanel
			NSApp.addWindowsItem(window, title: (window.windowController?.document?.displayName)!, filename: false)

			//  Remember to close down any observations before closure
			window.makeKeyAndOrderFront(sender)
		}
		catch let error {
			NSApp.presentError(error)
			Swift.print("Yoink, unable to make new doc")
		}
	}
	var newWindows : Bool {
		get {
			return newWindowsItem.state == NSOnState
		}
	}
	@IBOutlet weak var newWindowsItem: NSMenuItem!
	@IBAction func doMakeNewWindows(_ sender: NSMenuItem) {
		newWindowsItem.state = (newWindowsItem.state == NSOnState) ? NSOffState : NSOnState
	}
	
	var loadByFileURL : Bool {
		get {
			return useLoadFileURL.state == NSOnState
		}
	}

	@IBOutlet weak var useLoadFileURL: NSMenuItem!
	@IBAction func doLoadFileURL(_ sender: Any) {
		useLoadFileURL.state = (useLoadFileURL.state == NSOnState) ? NSOffState : NSOnState

	}
	override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
		switch menuItem.title {
		case "Create New Windows":
			menuItem.state = newWindowsItem.state == NSOffState ? NSOnState : NSOffState
			break
			
		default:
			Swift.print("menuItem:\(menuItem.title) \(menuItem.state)")
			break
		}
		return true;
	}

	// MARK:- Sandbox Support
	var bookmarks = [URL: Data]()
	
	func isSandboxed() -> Bool {
		let bundleURL = Bundle.main.bundleURL
		var staticCode:SecStaticCode?
		var isSandboxed:Bool = false
		let kSecCSDefaultFlags:SecCSFlags = SecCSFlags(rawValue: SecCSFlags.RawValue(0))
		
		if SecStaticCodeCreateWithPath(bundleURL as CFURL, kSecCSDefaultFlags, &staticCode) == errSecSuccess {
			if SecStaticCodeCheckValidityWithErrors(staticCode!, SecCSFlags(rawValue: kSecCSBasicValidateOnly), nil, nil) == errSecSuccess {
				let appSandbox = "entitlement[\"com.apple.security.app-sandbox\"] exists"
				var sandboxRequirement:SecRequirement?
				
				if SecRequirementCreateWithString(appSandbox as CFString, kSecCSDefaultFlags, &sandboxRequirement) == errSecSuccess {
					let codeCheckResult:OSStatus  = SecStaticCodeCheckValidityWithErrors(staticCode!, SecCSFlags(rawValue: kSecCSBasicValidateOnly), sandboxRequirement, nil)
					if (codeCheckResult == errSecSuccess) {
						isSandboxed = true
					}
				}
			}
		}
		return isSandboxed
	}
	
	func bookmarkPath() -> String?
	{
		if var documentsPathURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
			documentsPathURL = documentsPathURL.appendingPathComponent("Bookmarks.dict")
			return documentsPathURL.path
		}
		else
		{
			return nil
		}
	}
	
	func loadBookmarks() -> Bool
	{
		//  Ignore loading unless configured
		guard isSandboxed() else
		{
			return false
		}

		let fm = FileManager.default
		
		guard let path = bookmarkPath(), fm.fileExists(atPath: path) else {
			return saveBookmarks()
		}
		
		var restored = 0
		bookmarks = NSKeyedUnarchiver.unarchiveObject(withFile: path) as! [URL: Data]
		var iterator = bookmarks.makeIterator()
		
		while let bookmark = iterator.next()
		{
			//  stale bookmarks get dropped
			if !fetchBookmark(bookmark) {
				bookmarks.removeValue(forKey: bookmark.key)
			}
			else
			{
				restored += 1
			}
		}
		return restored == bookmarks.count
	}
	
	func saveBookmarks() -> Bool
	{
		//  Ignore saving unless configured
		guard isSandboxed() else
		{
			return false
		}
		
		if let path = bookmarkPath() {
			return NSKeyedArchiver.archiveRootObject(bookmarks, toFile: path)
		}
		else
		{
			return false
		}
	}
	
	func storeBookmark(url: URL) -> Bool
	{
		//  Peek to see if we've seen this key before
		if let data = bookmarks[url] {
			if self.fetchBookmark((key: url, value: data)) {
				Swift.print ("= \(url.absoluteString)")
				return true
			}
		}
		do
		{
//			let options:NSURL.BookmarkCreationOptions = (url as NSURL).resolvedFinderAlias() == nil || url.path.hasSuffix("webloc")
//				? [.withSecurityScope] : [.withSecurityScope,.securityScopeAllowOnlyReadAccess]
			let options:NSURL.BookmarkCreationOptions = [.withSecurityScope,.securityScopeAllowOnlyReadAccess]
			let data = try url.bookmarkData(options: options, includingResourceValuesForKeys: nil, relativeTo: nil)
			bookmarks[url] = data
			return self.fetchBookmark((key: url, value: data))
		}
		catch let error
		{
			if !url.absoluteString.hasSuffix("webloc") {
				NSApp.presentError(error)
				Swift.print ("Error storing bookmark: \(url)")
			}
			return false
		}
	}
	
	func fetchBookmark(_ bookmark: (key: URL, value: Data)) -> Bool
	{
		let restoredUrl: URL?
		var isStale = true
		
		do
		{
			restoredUrl = try URL.init(resolvingBookmarkData: bookmark.value, options: NSURL.BookmarkResolutionOptions.withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
		}
        catch let error
        {
//            NSApp.presentError(error)
			Swift.print ("! \(bookmark.key)\t\(error.localizedDescription)")
			return false
		}
		
		guard !isStale, let url = restoredUrl, url.startAccessingSecurityScopedResource() else {
			Swift.print ("? \(bookmark.key)")
			return false
		}
		Swift.print ("+ \(url)")
		return true
	}

	func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
		let dc = NSDocumentController.shared()
		return dc.documents.count == 0
	}

	func applicationWillFinishLaunching(_ notification: Notification) {
		//	we need typeForContents
		_ = DocumentController.init()
	}
	
	func applicationDidFinishLaunching(_ aNotification: Notification) {
		// Insert code here to initialize your application
		//  Load sandbox bookmark url
		if self.isSandboxed() { _ = self.loadBookmarks() }
	}

	func applicationWillTerminate(_ aNotification: Notification) {
		// Insert code here to tear down your application
		//  Save sandbox bookmark url
		if self.isSandboxed() { _ = self.saveBookmarks() }
	}
}


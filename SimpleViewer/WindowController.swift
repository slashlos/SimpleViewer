//
//  WindowController.swift
//  SimpleViewer
//
//  Created by Carlos D. Santiago on 12/10/17.
//  Copyright © 2017 Carlos D. Santiago. All rights reserved.
//

import Foundation
import AppKit
import Cocoa

struct k {
    static let TitleUtility: CGFloat = 16.0
    static let TitleNormal: CGFloat = 22.0
    static let ToolbarItemHeight: CGFloat = 48.0
    static let ToolbarItemSpacer: CGFloat = 4.0
    static let ToolbarTextHeight: CGFloat = 12.0
    static let ToolbarlessSpacer: CGFloat = 4.0

	static let bingInfo = "Microsoft Bing Search"
	static let bingName = "Bing"
	static let bingLink = "https://search.bing.com/search?Q=%@"
	static let googleInfo = "Google Search"
	static let googleName = "Google"
	static let googleLink = "https://www.google.com/search?q=%@"
	static let yahooName = "Yahoo"
	static let yahooInfo = "Yahoo! Search"
	static let yahooLink = "https://search.yahoo.com/search?q=%@"
	static let searchInfos = [k.bingInfo, k.googleInfo, k.yahooInfo]
	static let searchNames = [k.bingName, k.googleName, k.yahooName]
	static let searchLinks = [k.bingLink, k.googleLink, k.yahooLink]
}

//  Offset a window from the current app key window
extension NSWindow {
    func offsetFromKeyWindow() {
		if let keyWindow = NSApp.keyWindow {
            self.offsetFromWindow(keyWindow)
        }
		else
		if let mainWindow = NSApp.mainWindow {
			self.offsetFromWindow(mainWindow)
		}
    }
    
    func offsetFromWindow(_ theWindow: NSWindow) {
        let oldRect = theWindow.frame
        let newRect = self.frame
        let titleHeight = theWindow.isFloatingPanel ? k.TitleUtility : k.TitleNormal
        
        //    Offset this window from the key window by title height pixels to right, just below
        //    either the title bar or the toolbar accounting for incons and/or text.
        
        let x = oldRect.origin.x + k.TitleNormal
        var y = oldRect.origin.y + (oldRect.size.height - newRect.size.height) - titleHeight
        
        if let toolbar = theWindow.toolbar {
            if toolbar.isVisible {
                let item = theWindow.toolbar?.visibleItems?.first
                let size = item?.maxSize
                
                if ((size?.height)! > CGFloat(0)) {
                    y -= (k.ToolbarItemSpacer + (size?.height)!);
                }
                else
                {
                    y -= k.ToolbarItemHeight;
                }
                if theWindow.toolbar?.displayMode == .iconAndLabel {
                    y -= (k.ToolbarItemSpacer + k.ToolbarTextHeight);
                }
                y -= k.ToolbarItemSpacer;
            }
        }
        else
        {
            y -= k.ToolbarlessSpacer;
        }
        
        self.setFrameOrigin(NSMakePoint(x,y))
    }
}

protocol WeblocDelegate : AnyObject {
	func draggingEntered(forWebloc webloc: PanelController, sender: NSDraggingInfo) -> NSDragOperation
	func performDragOperation(forWebloc webloc: PanelController, sender: NSDraggingInfo) -> Bool
	func pasteboardWriter(forWebloc webloc: PanelController) -> NSPasteboardWriting
}

class PanelController : NSWindowController,NSWindowDelegate,NSFilePromiseProviderDelegate,NSPasteboardWriting,WeblocDelegate,NSDraggingSource {
	
	fileprivate var panel: NSPanel! {
		get {
			return (self.window as! NSPanel)
		}
	}
	fileprivate var doc: Document? {
		get {
			return self.document as? Document
		}
	}
	
	var snapshot : NSImage? {
		get {
			guard let window = self.window, let view = self.window!.contentView else { return nil }
			
			let inf = CGFloat(FP_INFINITE)
			let null = CGRect(x: inf, y: inf, width: 0, height: 0)
			
			let cgImage = CGWindowListCreateImage(null, .optionIncludingWindow,
												  CGWindowID(window.windowNumber), .bestResolution)
			let image = NSImage(cgImage: cgImage!, size: view.bounds.size)
			
			return image
		}
	}

	@IBAction func toggleFullScreen(_ sender: NSMenuItem) {
		(NSApp.delegate as! AppDelegate).toggleFullScreen(sender)
	}
	
	override func mouseEntered(with theEvent: NSEvent) {
		if theEvent.modifierFlags.contains(NSEvent.ModifierFlags.shift) {
			NSApp.activate(ignoringOtherApps: true)
		}
		else
		{
			super.mouseEntered(with: theEvent)
		}
		if trackingTag == theEvent.trackingNumber {
			window!.standardWindowButton(.closeButton)!.alphaValue = 1.00
		}
//		window!.titlebarAppearsTransparent = false
		window!.titleVisibility = NSWindow.TitleVisibility.visible
		if let window = self.window, let docIcon = window.standardWindowButton(.documentIconButton)?.cell?.controlView {
			docIcon.isHidden = false
		}
		Swift.print("mouseEntered")
	}
	override func mouseExited(with theEvent: NSEvent) {
		if trackingTag == theEvent.trackingNumber {
			window!.standardWindowButton(.closeButton)!.alphaValue = 0.01
		}
//		window!.titlebarAppearsTransparent = true
		window!.titleVisibility = NSWindow.TitleVisibility.hidden
		if let window = self.window, let docIcon = window.standardWindowButton(.documentIconButton)?.cell?.controlView {
			docIcon.isHidden = true
		}
		Swift.print("mouseExited")
	}
	
	private let dragThreshold: CGFloat = 3.0
	private var dragOriginOffset = CGPoint.zero

	override func mouseDown(with event: NSEvent) {
		if let window = self.window, let docIcon = window.standardWindowButton(.documentIconButton)?.cell?.controlView {

			let location = docIcon.convert(event.locationInWindow, from: nil)
			let hitPoint = docIcon.convert(location, to: docIcon.superview)
			let hitView = docIcon.hitTest(hitPoint)
			
			let eventMask: NSEvent.EventTypeMask = [NSEvent.EventTypeMask.leftMouseUp, NSEvent.EventTypeMask.leftMouseDragged]
			let timeout = NSEvent.foreverDuration//NSEvent.foreverDuration
			
			if hitView == docIcon {
				window.trackEvents(matching: eventMask, timeout: timeout, mode: RunLoop.Mode.eventTracking, handler: {(event, stop) in
					
                    if event?.type == .leftMouseUp {
						stop.pointee = true
					} else {
                        let movedLocation = docIcon.convert((event?.locationInWindow)!, from: nil)
						if abs(movedLocation.x - location.x) > self.dragThreshold || abs(movedLocation.y - location.y) > self.dragThreshold {
							stop.pointee = true
							if let delegate : PanelController = window.delegate as? PanelController {
								let draggingItem = NSDraggingItem(pasteboardWriter: delegate.pasteboardWriter(forWebloc: self))
								draggingItem.setDraggingFrame(docIcon.frame, contents: delegate.doc!.displayImage)
                                docIcon.beginDraggingSession(with: [draggingItem], event: event!, source: self)
							}
						}
					}
				})
			}
		}
	}
	
	var trackingTag: NSView.TrackingRectTag?
	var contentTag: NSView.TrackingRectTag?
	func updateTrackingAreas(_ establish : Bool) {
		if let tag = trackingTag {
			window!.standardWindowButton(.closeButton)!.removeTrackingRect(tag)
		}
		if establish, let closeButton = window!.standardWindowButton(.closeButton) {
			window!.ignoresMouseEvents = false
			trackingTag = closeButton.addTrackingRect(closeButton.bounds, owner: self, userData: nil, assumeInside: false)
		}
		if let tag = contentTag {
			window!.contentView?.removeTrackingRect(tag)
		}
		if establish, let contentView = window!.contentView {
			contentTag = contentView.addTrackingRect(contentView.bounds, owner: self, userData: nil, assumeInside: false)
		}
	}

    override func windowDidLoad() {
		window!.ignoresMouseEvents = false
		
		updateTrackingAreas(true)
		window!.standardWindowButton(.closeButton)!.alphaValue = 0.01

		panel.isFloatingPanel = true
		
		panel.registerForDraggedTypes([NSPasteboard.PasteboardType(rawValue: "NSFilePromiseProvider"),NSPasteboard.PasteboardType(rawValue: kUTTypeFileURL as String as String)])
///		panel.registerForDraggedTypes([NSPasteboard.PasteboardType.fileURL])

		self.window?.offsetFromKeyWindow()
    }
    
	func windowShouldClose(_ sender: NSWindow) -> Bool {
		panel.ignoresMouseEvents = true
		updateTrackingAreas(false)

		// Wind down all observations
		NotificationCenter.default.removeObserver(self)
		
		//	If view isn't visible stop its observations
		(panel.contentViewController as! ViewController).viewWillDisappear()
		
		return true
	}
	/*
	func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
		let content = sender.contentView?.bounds.size
		Swift.print("windowWillResize: \(frameSize) content: \(String(describing: content))")
		return frameSize
	}
	func windowDidResize(_ notification: Notification) {
		let content = (notification.object as! NSWindow).contentView?.bounds.size
		let webView = contentViewController?.view.subviews.first as! MyWebView
		let magnify = webView.magnification
		let bounds = webView.bounds.size
		let visual = NSMakeSize(bounds.width*magnify, bounds.height*magnify)
		Swift.print("windowDidResize: \(String(describing: content)) webView: \(bounds) visual: \(magnify) \(visual)")
	}
	*/
	
	//	MARK:- Document Drag File Promise

	/// queue used for reading and writing file promises
	private lazy var workQueue: OperationQueue = {
		let providerQueue = OperationQueue()
		providerQueue.qualityOfService = .userInitiated
		return providerQueue
	}()

	/// directory URL used for accepting file promises
	private lazy var destinationURL: URL = {
		let destinationURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Drops")
		try? FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true, attributes: nil)
		return destinationURL
	}()

	func window(_ window: NSWindow, shouldDragDocumentWith event: NSEvent, from dragImageLocation: NSPoint, with pasteboard: NSPasteboard) -> Bool {
		
		if let dragImage = self.snapshot {
			//	Replace string with our URL string
			let urlString = String(format: """
<?xml version=\"1.0\" encoding=\"UTF-8\"?>
	<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
	<plist version=\"1.0\">
	<dict>
	<key>URL</key>
	<string>%@</string>
	</dict>
	</plist>
""", ((document as! Document).fileURL?.absoluteString)!)
            let filename = String(format: "%@%@", pasteboard.string(forType: NSPasteboard.PasteboardType(rawValue: kUTTypeFileURL as String as String))!, ((document as! Document).fileURL?.webFilename)!)

            pasteboard.clearContents()
            pasteboard.setString(urlString, forType: NSPasteboard.PasteboardType.string)
            pasteboard.setString(filename, forType: NSPasteboard.PasteboardType(rawValue: kPasteboardTypeFileURLPromise))
//            pasteboard.setString(filename, forType: kUTTypeFileURL as String)
            
            let item = MyFilePromiseProvider.init()
            item.userInfo = self.document
            pasteboard.writeObjects([item])

			window.drag(dragImage, at: dragImageLocation, offset: NSZeroSize, event: event, pasteboard: pasteboard, source: self, slideBack: true)
		}
		
		return false
	}
	
	func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
		return true
	}
	
	//	MARK:- Pasteboard Writing Protocol
	func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
		let item = MyFilePromiseProvider.init()
		item.fileType = kUTTypeData as String
		item.delegate = self
		item.userInfo = document
		pasteboard.writeObjects([item])
		let urlString = (document as! Document).fileURL?.lastPathComponent
		let fileName = String(format: "%@.webloc", urlString!)
		pasteboard.setPropertyList([fileName], forType:NSPasteboard.PasteboardType(rawValue: kUTTypeData as String as String))/*
		let url = URL.init(string: ((document as! Document).fileURL?.absoluteString)!)
		pasteboard.setPropertyList(url as Any, forType: kUTTypeFileURL as String)*/

		return [NSPasteboard.PasteboardType(rawValue: kUTTypeData as String as String)]
	}
    
    public func writingOptions(forType type: NSPasteboard.PasteboardType, pasteboard: NSPasteboard) -> NSPasteboard.WritingOptions
    {
        return []
    }
    
	func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
		return kUTTypeData
	}
	
	// MARK: - NSDraggingSource
	
	func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
		return (context == .outsideApplication) ? [.copy] : []
	}
	
	func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
		return .copy
	}

	// MARK: - NSDraggingDestination

	func draggingEntered(forWebloc webloc: PanelController, sender: NSDraggingInfo) -> NSDragOperation {
		return sender.draggingSourceOperationMask.intersection([.copy])
	}
	
	func pasteboardWriter(forWebloc webloc: PanelController) -> NSPasteboardWriting {
		let provider = NSFilePromiseProvider(fileType: kUTTypeFileURL as String, delegate: self)
		provider.userInfo = webloc.document
		return provider
	}
	
	//	MARK:- Drag File Promise
	
	public func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, fileNameForType fileType: String) -> String {
		let urlString = (document as! Document).fileURL?.lastPathComponent
		let fileName = String(format: "%@.webloc", urlString!)
		Swift.print("WindowDelegate -filePromiseProvider\n \(fileName)")
		return fileName
	}
	
	func performDragOperation(forWebloc webloc: PanelController, sender: NSDraggingInfo) -> Bool {
		return true
	}
	
	public func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider,
									writePromiseTo url: URL,
									completionHandler: @escaping (Error?) -> Void) {
		let urlString = String(format: """
<?xml version=\"1.0\" encoding=\"UTF-8\"?>
	<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
	<plist version=\"1.0\">
	<dict>
	<key>URL</key>
	<string>%@</string>
	</dict>
	</plist>
""", ((document as! Document).fileURL?.absoluteString)!)
		Swift.print("WindowDelegate -filePromiseProvider\n \(urlString)")
		
		do {
			try urlString.write(to: url, atomically: true, encoding: .utf8)
			completionHandler(nil)
		} catch let error {
			completionHandler(error)
		}
	}

	// MARK: - NSFilePromiseProviderDelegate
	
	/// - Tag: ProvideOperationQueue
	func operationQueue(for filePromiseProvider: NSFilePromiseProvider) -> OperationQueue {
		return workQueue
	}
}

public class MyFilePromiseProvider : NSFilePromiseProvider {
	
	public override func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
		if let items = pasteboard.pasteboardItems {
			Swift.print("MyFilePromiseProvider -writableTypes(\(items.count))")
			return [NSPasteboard.PasteboardType(rawValue: kUTTypeData as String as String)]
		}
		else
		{
			return pasteboard.types!
		}
	}
	
	public override func writingOptions(forType type: NSPasteboard.PasteboardType, pasteboard: NSPasteboard) -> NSPasteboard.WritingOptions {
			
		if type.rawValue == kUTTypeData as String {
			Swift.print("MyPromiseProvider -writingOptions()")
			return []
		}

		return super.writingOptions(forType: type, pasteboard: pasteboard)
	}
	
	public override func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
		Swift.print("MyPromiseProvider -pasteboardPropertyList(\(type))")

		if type.rawValue == kUTTypeData as String {
			let document = (userInfo as! Document)
			let urlString = String(format: """
<?xml version=\"1.0\" encoding=\"UTF-8\"?>
	<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
	<plist version=\"1.0\">
	<dict>
	<key>URL</key>
	<string>%@</string>
	</dict>
	</plist>
""", (document.fileURL?.absoluteString)!)
			let data = urlString.data(using: String.Encoding.utf8)
			Swift.print("MyPromiseProvider -pasteboardPropertyList()")
			return data
		}
		
		if type.rawValue == kUTTypeURL as String {
			let document = (userInfo as! Document)
			let url = document.fileURL
			
			return url
		}
		
		if type.rawValue == kUTTypeFileURL as String {
			let document = (userInfo as! Document)
			let url = document.fileURL
			
			if let fileName = url!.webFilename?.replaceSuffix("/", replacement: ".webloc") {
				let tempPath = NSTemporaryDirectory()
				let fileURL = URL.init(fileURLWithPath: String(format: "%@%@", tempPath, fileName))
				_ = fileURL.startAccessingSecurityScopedResource()
				return fileName
			}

			let urlString = document.fileURL?.absoluteString
			let fileName = String(format: "%@.webloc", urlString!)

			return fileName
		}

		return super.pasteboardPropertyList(forType: type)
	}
	
	public override func namesOfPromisedFilesDropped(atDestination dropDestination: URL) -> [String]? {
		let document = (userInfo as! Document)
		let urlString = document.fileURL?.lastPathComponent
		let fileName = String(format: "%@.webloc", urlString!)

		return [fileName]
	}
}

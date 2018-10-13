//
//  WindowController.swift
//  SimpleViewer
//
//  Created by Carlos D. Santiago on 12/10/17.
//  Copyright © 2017 Carlos D. Santiago. All rights reserved.
//

import Foundation
import AppKit

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

class PanelController : NSWindowController,NSWindowDelegate,NSFilePromiseProviderDelegate,NSPasteboardWriting {
	fileprivate var panel: NSPanel! {
		get {
			return (self.window as! NSPanel)
		}
	}
	@IBAction func toggleFullScreen(_ sender: NSMenuItem) {
		(NSApp.delegate as! AppDelegate).toggleFullScreen(sender)
	}
	
	override func mouseEntered(with theEvent: NSEvent) {
		if theEvent.modifierFlags.contains(.shift) {
			NSApp.activate(ignoringOtherApps: true)
		}
		else
		{
			super.mouseEntered(with: theEvent)
		}
		if trackingTag == theEvent.trackingNumber {
			window!.standardWindowButton(.closeButton)!.alphaValue = 1.00
			Swift.print("mouseEntered")
		}
	}
	override func mouseExited(with theEvent: NSEvent) {
		if trackingTag == theEvent.trackingNumber {
			window!.standardWindowButton(.closeButton)!.alphaValue = 0.01
			Swift.print("mouseExited")
		}
	}
	
	var trackingTag: NSTrackingRectTag?
	func updateTrackingAreas(_ establish : Bool) {
		if let tag = trackingTag {
			window!.standardWindowButton(.closeButton)!.removeTrackingRect(tag)
		}
		if establish, let closeButton = window!.standardWindowButton(.closeButton) {
			window!.ignoresMouseEvents = false
			trackingTag = closeButton.addTrackingRect(closeButton.bounds, owner: self, userData: nil, assumeInside: false)
		}
	}

    override func windowDidLoad() {
		window!.ignoresMouseEvents = false
		
		updateTrackingAreas(true)
		window!.standardWindowButton(.closeButton)!.alphaValue = 0.01

		panel.isFloatingPanel = true
		
		panel.registerForDraggedTypes(["NSFilePromiseProvider"])
		
		self.window?.offsetFromKeyWindow()
    }
    
	func windowShouldClose(_ sender: Any) -> Bool {
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
		let url = (document as! Document).fileURL
		
		if url?.scheme != "file" {
			Swift.print("WindowDelegate -shouldDragDocumentWith(\(String(describing: url))")
			let item = MyFilePromiseProvider.init()
			item.fileType = kUTTypeData as String
			item.delegate = self
			item.userInfo = ["document" : document]
			pasteboard.writeObjects([item])
		}
		
		return true
	}
	
	//	MARK:- Pasteboard Writer
	func writableTypes(for pasteboard: NSPasteboard) -> [String] {
		let item = MyFilePromiseProvider.init()
		item.fileType = kUTTypeData as String
		item.delegate = self
		item.userInfo = ["document" : document]
		pasteboard.writeObjects([item])
		return [kUTTypeFileURL as String]
	}
	
	func writingOptions(forType type: String, pasteboard: NSPasteboard) -> NSPasteboard.WritingOptions {
		return []
	}

	func pasteboardPropertyList(forType type: String) -> Any? {
		return kUTTypeData
	}
	
	//	MARK:- Drag File Promise
	public func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, fileNameForType fileType: String) -> String {
		let urlString = (document as! Document).fileURL?.lastPathComponent
		let fileName = String(format: "%@.webloc", urlString!)
		return fileName
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
	
	public override func writableTypes(for pasteboard: NSPasteboard) -> [String] {
		Swift.print("WindowDelegate -writableTypes()")
		return [kUTTypeData as String]
	}
	
	public override func writingOptions(forType type: String, pasteboard: NSPasteboard) -> NSPasteboard.WritingOptions {
			
		if type == kUTTypeData as String {
			Swift.print("MyPromiseProvider -writingOptions()")
			return []
		}

		return super.writingOptions(forType: type, pasteboard: pasteboard)
	}
	
	public override func pasteboardPropertyList(forType type: String) -> Any? {
			
		if type == kUTTypeData as String {
			let document : Document = (userInfo as! Dictionary)["document"]!
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
			Swift.print("MyPromiseProvider -pasteboardPropertyList()")
			return urlString
		}

		return super.pasteboardPropertyList(forType: type)
	}
	
	public override func namesOfPromisedFilesDropped(atDestination dropDestination: URL) -> [String]? {
		return ["names"]
	}
}

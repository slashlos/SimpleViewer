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

class PanelController : NSWindowController,NSWindowDelegate {
	
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
	//	MARK:- Drag-n-Drop
	func window(_ window: NSWindow, shouldDragDocumentWith event: NSEvent, from dragImageLocation: NSPoint, with pasteboard: NSPasteboard) -> Bool {
		let url = (document as! Document).fileURL
		Swift.print("pasteboard \(String(describing: url))")
		
		if url?.scheme != "file" {
			let urlString = String(format: """
<?xml version=\"1.0\" encoding=\"UTF-8\"?>
	<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
	<plist version=\"1.0\">
	<dict>
	<key>URL</key>
	<string>%@</string>
	</dict>
	</plist>
""", (url?.absoluteString)!)
			Swift.print("drop \(urlString)")
			pasteboard.setString(urlString, forType: "NSFilePromiseProvider")
			pasteboard.setString(urlString, forType: kPasteboardTypeFileURLPromise)
//			pasteboard.setString((url?.absoluteString)!, forType: kPasteboardTypeFileURLPromise)
			pasteboard.setString(urlString, forType: kPasteboardTypeFileURLPromise)
		}
		
		return true
	}
	
	public func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, fileNameForType fileType: String) -> String {
		let url = (document as! Document).fileURL?.lastPathComponent
		Swift.print("url \(String(describing: url))")
		return "name.webloc"
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
		Swift.print("promise \(urlString)")
		
		do {
			try urlString.write(to: url, atomically: true, encoding: .utf8)
			completionHandler(nil)
		} catch let error {
			completionHandler(error)
		}
	}
}


public class MyFilePromiseProvider : NSFilePromiseProvider {

	public override func writableTypes(for pasteboard: NSPasteboard) -> [String] {

		var types = super.writableTypes(for: pasteboard)
		types.append("webloc")
			
		return types;
	}
	
	public override func writingOptions(forType type: String, pasteboard: NSPasteboard) -> NSPasteboardWritingOptions {
		
		if type == "webloc" {
			return []
		}
		return super.writingOptions(forType: type, pasteboard: pasteboard)
	}
	
	public override func pasteboardPropertyList(forType type: String) -> Any? {
		
		if type == "webloc" {
			return "Hello world!"
		}
		return super.pasteboardPropertyList(forType: type)
	}
}

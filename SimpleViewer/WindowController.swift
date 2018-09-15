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
}

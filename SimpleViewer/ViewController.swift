//
//  ViewController.swift
//  SimpleViewer
//
//  Created by Carlos D. Santiago on 12/10/17.
//  Copyright © 2017 Carlos D. Santiago. All rights reserved.
//

import Cocoa
import WebKit
import AVFoundation

class MyWebView : WKWebView {
	var appDelegate: AppDelegate = NSApp.delegate as! AppDelegate
	class func handlesURLScheme(scheme: String) -> Bool {
		Swift.print("handle: \(scheme)")
		return true
	}
	
	override var mouseDownCanMoveWindow: Bool {
		get {
			if let window = self.window {
				return window.isMovableByWindowBackground
			}
			else
			{
				return false
			}
		}
	}

	override func mouseEntered(with theEvent: NSEvent) {
		if theEvent.modifierFlags.contains(.shift) {
			NSApp.activate(ignoringOtherApps: true)
		}
		else
		{
			super.mouseEntered(with: theEvent)
		}
	}
	
	override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
		return .copy
	}
	
	func next(url: URL) {
		let doc = self.window?.windowController?.document as? Document
		let newWindows = appDelegate.newWindows
		let dc = NSDocumentController.shared()
		var nextURL = url
		
		//  Pick off request (non-file) urls first
		if !url.isFileURL {
			if newWindows {
				do
				{
					let next = try NSDocumentController.shared().makeDocument(withContentsOf: url, ofType: "DocumentType")
					next.makeWindowControllers()
					dc.addDocument(next)

					let oldWindow = self.window
					let newWindow = next.windowControllers.first?.window
					(newWindow?.contentView?.subviews.first as! MyWebView).load(URLRequest(url: url))
					newWindow?.offsetFromWindow(oldWindow!)
					
					//	do not bother with filenames as it not be a valid filename
					NSApp.addWindowsItem(newWindow!, title: url.lastPathComponent, filename: false)
				}
				catch let error {
					NSApp.presentError(error)
					Swift.print("Yoink, unable to create new url doc for (\(url))")
					return
				}
			}
			else
			{
				self.stopLoading()
				if appDelegate.loadByFileURL {
					self.loadFileURL(url, allowingReadAccessTo: url)
				}
				else
				{
					self.load(URLRequest(url: url))
				}
			}
			return
		}
		
		//	Bookmark a potential alias, and a webloc container
		//	so each can be read to derive the target url info.
		if appDelegate.isSandboxed() != appDelegate.storeBookmark(url: nextURL as URL) {
			Swift.print("Yoink, unable to bookmark (\(nextURL))")
			return
		}
		if let original = (nextURL as NSURL).resolvedFinderAlias() {
			if appDelegate.isSandboxed() != appDelegate.storeBookmark(url: original as URL) {
				Swift.print("Yoink, unable to bookmark orignal (\(original))")
				return
			}
			nextURL = original
		}
		if nextURL.absoluteString.hasSuffix("webloc"), let webURL = nextURL.webloc {
			nextURL = webURL
		}
		
		self.stopLoading()
		doc?.updateURL(url: nextURL)
		
		if nextURL.isFileURL {
			if appDelegate.loadByFileURL {
				self.loadFileURL(nextURL, allowingReadAccessTo: nextURL)
			}
			else
			{
				self.load(URLRequest(url: nextURL))
			}
		}
		else
		{
			self.load(URLRequest(url: nextURL))
		}
	}

	override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
		let isSandboxed = appDelegate.isSandboxed()
		let newWindows = appDelegate.newWindows
		let pboard = sender.draggingPasteboard()
		let items = pboard.pasteboardItems

		NSApp.activate(ignoringOtherApps: true)

		if (pboard.types?.contains(NSURLPboardType))! {
			let dc = NSDocumentController.shared()
			for item in items! {
				if let urlString = item.string(forType: kUTTypeURL as String) {
					self.load(URLRequest(url: URL(string: urlString)!))
				}
				else
				if let urlString = item.string(forType: kUTTypeFileURL as String/*"public.file-url"*/), var itemURL = URL.init(string: urlString) {
					if newWindows {
						_ = appDelegate.doOpenFile(fileURL: itemURL, fromWindow: self.window)
						continue
					}

					//	Bookmark a potential alias, and a webloc container
					//	so each can be read to derive the target url info.
					if isSandboxed != appDelegate.storeBookmark(url: itemURL as URL) {
						Swift.print("Yoink, unable to bookmark (\(itemURL))")
						return false
					}
					if let original = (itemURL as NSURL).resolvedFinderAlias() {
						if isSandboxed != appDelegate.storeBookmark(url: original as URL) {
							Swift.print("Yoink, unable to bookmark orignal (\(original))")
							return false
						}
						itemURL = original
					}
					if itemURL.absoluteString.hasSuffix("webloc"), let webURL = itemURL.webloc {
						itemURL = webURL
					}

					//	From here we will overlay current asset so stop it first
					self.stopLoading()

					if let doc = self.window?.windowController?.document {
						(doc as! Document).updateURL(url: itemURL)
						dc.addDocument(doc as! Document)
						if let window = self.window {
							//	do not bother with filenames as it not be a valid filename
							NSApp.addWindowsItem(window, title: itemURL.lastPathComponent, filename: false)
						}
					}
					if appDelegate.loadByFileURL {
						self.loadFileURL(itemURL, allowingReadAccessTo: itemURL)
					}
					else
					{
						self.load(URLRequest.init(url: itemURL))
					}
				}
				else
				{
					Swift.print("items has \(item.types)")
				}
			}
		}
		else
		if (pboard.types?.contains(NSPasteboardURLReadingFileURLsOnlyKey))! {
			Swift.print("we have NSPasteboardURLReadingFileURLsOnlyKey")
		}
		return true
	}
}

class CenteredClipView : NSClipView
{
	override func constrainBoundsRect(_ proposedBounds: NSRect) -> NSRect {
		
		var rect = super.constrainBoundsRect(proposedBounds)
		if let containerView = self.documentView {
			
			if (rect.size.width > containerView.frame.size.width) {
				rect.origin.x = (containerView.frame.width - rect.width) / 2
			}
			
			if(rect.size.height > containerView.frame.size.height) {
				rect.origin.y = (containerView.frame.height - rect.height) / 2
			}
		}
		
		return rect
	}
}

class ViewController: NSViewController, WKNavigationDelegate, WKUIDelegate {
	
	var appDelegate: AppDelegate = NSApp.delegate as! AppDelegate
	var trackingTag: NSTrackingRectTag?
	dynamic var observing : Bool = false
	func updateTrackingAreas() {
		if let tag = trackingTag {
			view.removeTrackingRect(tag)
		}
		
		trackingTag = view.addTrackingRect(view.bounds, owner: self, userData: nil, assumeInside: false)
	}
	
    // MARK: Zoom
    /**
     Use to adjust the height of the Document View.  Use this instead of other methods when you want to resize the view.
     */
	@IBOutlet weak var scrollView: NSScrollView!
	@IBOutlet weak var viewWidthConstraint: NSLayoutConstraint!
    
    /**
     A link to the View from the Storyboard.  Needed for getting the image size to calculate the zoomFactor and zoomToFit.
     */
    @IBOutlet weak var viewHeightConstraint: NSLayoutConstraint!
    
    /**
     A link to the View from the Storyboard.  Needed for getting the webView size to calculate the zoomFactor and zoomToFit.
     */
    @IBOutlet weak var webView: MyWebView!
    
    /**
     A link to the CenteringClipView of the NSScrollView from the Storyboard.  Needed for getting the centeringClipView size in the zoomToFit calculations.
     */
    @IBOutlet var clipView: CenteringClipView!
	
    var zoomFactor:CGFloat = 1.0 {
        /**
         Updates the Document View size whenever the zoomFactor is changed.
         */
        didSet {
			guard webView.url != nil else {
				return
			}

			self.webView.magnification = zoomFactor
//			scrollView.magnification = zoomFactor
/*
			let content = self.view.window?.contentView?.bounds.size
			let bounds = self.webView.bounds.size
			let visual = NSMakeSize(bounds.width*zoomFactor, bounds.height*zoomFactor)
			Swift.print("zoom: \(String(describing: content)) webView: \(bounds) visual: \(zoomFactor) \(visual)")*/

			if let viewConstraint = viewHeightConstraint {
				viewConstraint.constant = webView.bounds.size.height * zoomFactor
			}
			if let viewConstraint = viewWidthConstraint {
				viewConstraint.constant = webView.bounds.size.width * zoomFactor
			}
			Swift.print(String.init(format: "zoomFactor: %2.1f", zoomFactor))
		}
    }

    /**
     Zooms in on the image.  In other words, expands or scales the image up.
     - parameters:
     - sender: The object that sent the event. The parameter is set to be optional so that it can be called with nil.
     */
    @IBAction func zoomIn(_ sender: NSMenuItem?) {
        if zoomFactor + 0.1 > 4 {
            zoomFactor = 4
        } else if zoomFactor == 0.05 {
            zoomFactor = 0.1
        } else {
            zoomFactor += 0.1
        }
		Swift.print(String(format:"+zoom:%.2f",zoomFactor))
    }
    
    /**
     Zooms out on the image.  In other words, shrinks or scales the image down.
     - parameters:
     - sender: The object that sent the event. The parameter is set to be optional so that it can be called with nil.
     */
    @IBAction func zoomOut(_ sender: NSMenuItem?) {
        if zoomFactor - 0.1 < 0.05 {
            zoomFactor = 0.05
        } else {
            zoomFactor -= 0.1
        }
		Swift.print(String(format:"-zoom:%.2f",zoomFactor))
    }
    
    /**
     Sets the image to it's default size.
     - parameters:
     - sender: The object that sent the event. The parameter is set to be optional so that it can be called with nil.
     */
    @IBAction func zoomReset(_ sender: NSMenuItem?) {
		Swift.print("zoom1")
        zoomFactor = 1.0
    }
    
    /**
     Fits the image entirely in the Scroll View content area (it's Clip View), using proportional scaling up or down.
     - parameters:
     - sender: The object that sent the event. The parameter is set to be optional so that it can be called with nil.
     */
    @IBAction func zoomToFit(_ sender: NSMenuItem?) {
		guard self.webView.url != nil, clipView != nil else {
			Swift.print("Yoink: zoomToFit()")
			return
		}
		Swift.print("zoomF")
		let imSize = webSize
		var clipSize = clipView.bounds.size
		
		//We want a 1 pixel gutter.  To make the calculations easier, adjust the clipbounds down to account for the gutter.  Use 2 * the pixel gutter, since we are adjusting only the height and width (this accounts for the left and right margin combined, and the top and bottom margin combined).
		let imageMargin:CGFloat = 2
		
		clipSize.width -= imageMargin
		clipSize.height -= imageMargin
		
		guard imSize.width > 0 && imSize.height > 0 && clipSize.width > 0 && clipSize.height > 0 else {
			return
		}
		
		let clipAspectRatio = clipSize.width / clipSize.height
		let imAspectRatio = imSize.width / imSize.height
		
		if clipAspectRatio > imAspectRatio {
			zoomFactor = clipSize.height / imSize.height
		} else {
			zoomFactor = clipSize.width / imSize.width
		}
    }

	// MARK: View lifecycle
	func fit(_ childView: NSView, parentView: NSView) {
		childView.translatesAutoresizingMaskIntoConstraints = false
		childView.topAnchor.constraint(equalTo: parentView.topAnchor).isActive = true
		childView.leadingAnchor.constraint(equalTo: parentView.leadingAnchor).isActive = true
		childView.trailingAnchor.constraint(equalTo: parentView.trailingAnchor).isActive = true
		childView.bottomAnchor.constraint(equalTo: parentView.bottomAnchor).isActive = true
//		childView.widthAnchor.constraint(equalTo: parentView.widthAnchor).isActive = true
		
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		if let superView = webView.superview {
			self.fit(webView, parentView: superView)
		}

		// Do any additional setup after loading the view.
		
		webView.autoresizingMask = [NSAutoresizingMaskOptions.viewHeightSizable, NSAutoresizingMaskOptions.viewWidthSizable]
		
		// Allow plug-ins such as silverlight
		webView.configuration.preferences.plugInsEnabled = true
		
		// Setup magic URLs
		webView.navigationDelegate = self
		
		// Allow zooming
		webView.allowsMagnification = true
		
		// Alow back and forth
		webView.allowsBackForwardNavigationGestures = true
		
		// Listen for load progress
		webView.addObserver(self, forKeyPath: "estimatedProgress", options: NSKeyValueObservingOptions.new, context: nil)
		observing = true
		
		//	Watch command key changes
		NotificationCenter.default.addObserver(
			self,
			selector: #selector(ViewController.commandKeyDown(_:)),
			name: NSNotification.Name(rawValue: "commandKeyDown"),
			object: nil)
		
		//  We allow drag from title's document icon to self or Finder
		webView.register(forDraggedTypes: [NSURLPboardType])
		webView.load(URLRequest(url: URL(string: UserSettings.homePageURL.value)!))
		
		// Do any additional setup after loading the view.
		DispatchQueue.main.async { [weak self]() -> Void in
			self?.zoomToFit(nil)
		}
	}
	
	override var representedObject: Any? {
		didSet {
		// Update the view, if already loaded.
		}
	}

	override func viewDidLayout() {
		if let superView = webView.superview {
			let size = superView.bounds.size
			webView.widthAnchor.constraint(equalToConstant: size.width)
			webView.heightAnchor.constraint(equalToConstant: size.height)
		}
	}

    override func viewWillDisappear() {
        let navDelegate = webView.navigationDelegate as! NSObject
        
        //  Halt anything in progress
        webView.stopLoading()
		webView.loadHTMLString("about:blank", baseURL: nil)
        
        // Wind down all observations
		if observing {
			webView.removeObserver(navDelegate, forKeyPath: "estimatedProgress")
			NotificationCenter.default.removeObserver(navDelegate)
			observing = false
		}
    }
    
	var webSize = CGSize(width: 0,height: 0)

	override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
		
		if keyPath == "estimatedProgress" {
		
			if let progress = change?[NSKeyValueChangeKey(rawValue: "new")] as? Float {
				let percent = progress * 100
				var title = NSString(format: "Loading... %.2f%%", percent)
				if percent == 100, let url = (self.webView.url) {
					
                    Swift.print("loaded: \(url)")
                    
					let notif = Notification(name: Notification.Name(rawValue: "NewURL"), object: url);
					NotificationCenter.default.post(notif)
					
					// once loaded update window title,size with video name,dimension
					if let urlTitle = (self.webView.url?.absoluteString) {
						title = urlTitle as NSString
						
						if let track = AVURLAsset(url: url, options: nil).tracks.first {
							
							//    if it's a video file, get and set window content size to its dimentions
							if track.mediaType == AVMediaTypeVideo {
								let oldSize = self.webView.bounds.size
								title = url.lastPathComponent as NSString
								webSize = track.naturalSize
								if oldSize != webSize, var origin = self.webView.window?.frame.origin, let theme = self.view.window?.contentView?.superview {
									var iterator = theme.constraints.makeIterator()
									Swift.print(String(format:"content:%p view:%p webView:%p", (self.view.window?.contentView)!, webView.superview!, webView))

									while let constraint = iterator.next()
									{
										Swift.print("\(constraint.priority) \(constraint)")
									}

									origin.y += (oldSize.height - webSize.height)
									webView.window?.setContentSize(webSize)
									webView.window?.setFrameOrigin(origin)
									//webView.bounds.size = webSize
								}
							}
							
							//  Wait for URL to finish
							let videoPlayer = AVPlayer(url: url)
							let item = videoPlayer.currentItem
							
							NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main, using: { (_) in
								DispatchQueue.main.async {
									Swift.print("restarting #1")
									videoPlayer.seek(to: kCMTimeZero)
									videoPlayer.play()
								}
							})
							
							NotificationCenter.default.addObserver(forName: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: item, queue: .main, using: { (_) in
								DispatchQueue.main.async {
									Swift.print("restarting #2")
									videoPlayer.seek(to: kCMTimeZero)
									videoPlayer.play()
								}
							})
						}
						
						// Restore track mice
						if webView.window!.windowController == nil || webView.window!.delegate == nil {
							webView.window?.standardWindowButton(.closeButton)?.alphaValue = 0.50/*
							let panelController = PanelController()
							webView.window!.windowController = panelController
							webView.window!.delegate = panelController
							panelController.window = webView.window!
							panelController.updateTrackingAreas(true)*/
						}
					} else {
						title = "SimpleViewer"
					}
					if let window = self.view.window {
						if let url = webView.url {
							if let doc = window.windowController?.document {
								(doc as! Document).updateURL(url: url)
							}
							let newTitle = url.isFileURL ? url.lastPathComponent : url.absoluteString
							NSApp.addWindowsItem(window, title: newTitle, filename: false)
						}
					}

					self.view.window?.title = title.removingPercentEncoding!
				}
			}
		}
	}
	
	@objc internal func commandKeyDown(_ notification : Notification) {
		let commandKeyDown : NSNumber = notification.object as! NSNumber
		if let window = self.view.window {
			window.isMovableByWindowBackground = commandKeyDown.boolValue
			Swift.print(String(format: "command %@", commandKeyDown.boolValue ? "v" : "^"))
		}
	}

	//	MARK: Nav Delegate
	func webView(_ webView: WKWebView,
				 decidePolicyFor navigationAction: WKNavigationAction,
				 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
		
		guard navigationAction.buttonNumber < 2 else {
			if let url = navigationAction.request.url {
				Swift.print("newWindow with url:\(String(describing: url))")
				self.appDelegate.openURLInNewWindow(url: url)
			}
			decisionHandler(WKNavigationActionPolicy.cancel)
			return
		}
		decisionHandler(WKNavigationActionPolicy.allow)
	}
	
	//	MARK: UI Delegate
	func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
				 for navigationAction: WKNavigationAction,
				 windowFeatures: WKWindowFeatures) -> WKWebView? {
		
		if navigationAction.targetFrame == nil {
			appDelegate.openURLInNewWindow(url: navigationAction.request.url!)
			return nil
		}

		let newWindows = appDelegate.newWindows
		var newWebView : WKWebView?
		Swift.print("createWebViewWith")
		
		if let newURL = navigationAction.request.url {
			appDelegate.newWindows = false
			do {
				let doc = try NSDocumentController.shared().makeDocument(withContentsOf: newURL, ofType: "Custom")
				if let vwc = doc.windowControllers.first as? PanelController,
					let window = vwc.window, let cvc = window.contentViewController as? ViewController {
					let newView = MyWebView.init(frame: webView.frame, configuration: configuration)
					let contentView = window.contentView!
					
					cvc.webView = newView
					contentView.addSubview(newView)
					
					newView.navigationDelegate = cvc
					newView.uiDelegate = cvc
					newWebView = cvc.webView
					cvc.viewDidLoad()
					
					//  Setups all done, make us visible
					cvc.webView.load(navigationAction.request)

					window.makeKeyAndOrderFront(self)
				}
			} catch let error {
				NSApp.presentError(error)
			}
		}
		if appDelegate.newWindows != newWindows {
			appDelegate.newWindows = newWindows
		}
		
		return newWebView
	}

}


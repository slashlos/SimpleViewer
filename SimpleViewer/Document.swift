//
//  Document.swift
//  i678921465
//
//  Created by Carlos D. Santiago on 12/10/17.
//  Copyright © 2017 Carlos D. Santiago. All rights reserved.
//

import Cocoa

class Document: NSDocument {
	var viewURL : URL?
	
	override init() {
	    super.init()
		// Add your subclass-specific initialization here.
	}

    func updateURL( url: URL) {
        fileURL = url
    }
	
	override func makeWindowControllers() {
		// Returns the Storyboard that contains your Document window.
		let storyboard = NSStoryboard(name: "Main", bundle: nil)
		let windowController = storyboard.instantiateController(withIdentifier: "MainController") as! NSWindowController
		self.addWindowController(windowController)
		if (viewURL != nil), let webView = windowController.window?.contentView?.subviews.first {
			(webView as! MyWebView).next(url: viewURL!)
		}
	}
	
	override func read(from url: URL, ofType typeName: String) throws {
		do {
			if typeName == "webloc", let webURL = url.webloc {
				viewURL = webURL
			}
			else
			{
				viewURL = url
			}
		}
	}
	
	convenience init(contentsOf url: URL, ofType typeName: String) throws {
		self.init()
		
		if typeName == "webloc" || url.path.hasSuffix("webloc"), let webURL = url.webloc {
			fileURL = webURL
		}
		else
		{
			fileURL = url
		}
		viewURL = fileURL
		fileType = typeName
	}
	
}


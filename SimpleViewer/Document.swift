//
//  Document.swift
//  SimpleViewer
//
//  Created by Carlos D. Santiago on 12/10/17.
//  Copyright © 2017 Carlos D. Santiago. All rights reserved.
//

import Cocoa

class DocumentController : NSDocumentController {
	override func typeForContents(of url: URL) throws -> String {
		return "DocumentType"
	}

	override func makeDocument(for urlOrNil: URL?, withContentsOf contentsURL: URL, ofType typeName: String) throws -> NSDocument {
		var doc: Document
		do {
			doc = try Document.init(contentsOf: contentsURL)
			if (urlOrNil != nil) {
				doc.fileURL = urlOrNil
				doc.fileType = urlOrNil?.pathExtension
			}
		} catch let error {
			NSApp.presentError(error)
			doc = Document.init()
		}
		return doc
	}
	
	override func makeDocument(withContentsOf url: URL, ofType typeName: String) throws -> NSDocument {
		var doc: Document
		do {
			doc = try self.makeDocument(for: url, withContentsOf: url, ofType: typeName) as! Document
		} catch let error {
			NSApp.presentError(error)
			doc = Document.init()
		}
		return doc
	}
	
}

class Document: NSDocument {
	var viewURL : URL?
	
	override init() {
	    super.init()
		// Add your subclass-specific initialization here.
	}

	convenience init(contentsOf url: URL) throws {
		do {
			try self.init(contentsOf: url, ofType: "Main")
		}
	}
	convenience init(contentsOf url: URL, ofType typeName: String) throws {
		self.init()
		self.fileType = url.pathExtension
		self.fileURL = url
		
		//  Record url and type, caller will load via notification
		do {
			self.makeWindowController(typeName)
			NSDocumentController.shared().addDocument(self)
			
			//  Defer custom setups until we have a webView
			if typeName == "Custom" { return }
			
			if url.path.hasSuffix("webloc"), let webURL = url.webloc {
				fileURL = webURL
			}
			else
			{
				fileURL = url
			}
			viewURL = fileURL
			
			if let wvc = self.windowControllers.first, let cvc = wvc.contentViewController {
				(cvc as! ViewController).webView.next(url: url)
				wvc.window?.orderFront(self)
			}
		}
	}

	func updateURL( url: URL) {
        fileURL = url
    }
	
	override func makeWindowControllers() {
		makeWindowController("Main")
	}
	func makeWindowController(_ typeName: String) {
		let storyboard = NSStoryboard(name: "Main", bundle: nil)
		let identifier = String(format: "%@Controller", typeName)
		
		let controller = storyboard.instantiateController(withIdentifier: identifier) as! NSWindowController
		self.addWindowController(controller)
		
		//  Delegate will close down any observations before closure
		controller.window?.delegate = controller as? NSWindowDelegate
		
		if (viewURL != nil), let webView = controller.window?.contentView?.subviews.first {
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
	
}


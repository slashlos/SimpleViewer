//
//  Document.swift
//  SimpleViewer
//
//  Created by Carlos D. Santiago on 12/10/17.
//  Copyright © 2017 Carlos D. Santiago. All rights reserved.
//

import Cocoa
import QuickLook

let kTitleUtility =		16
let	kTitleNormal =		22

extension NSImage {
	
	func resize(w: Int, h: Int) -> NSImage {
		let destSize = NSMakeSize(CGFloat(w), CGFloat(h))
		let newImage = NSImage(size: destSize)
		newImage.lockFocus()
		self.draw(in: NSMakeRect(0, 0, destSize.width, destSize.height),
				  from: NSMakeRect(0, 0, self.size.width, self.size.height),
				  operation: .sourceOver,
				  fraction: CGFloat(1))
		newImage.unlockFocus()
		newImage.size = destSize
		return NSImage(data: newImage.tiffRepresentation!)!
	}
}

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
	
	var displayImage: NSImage? {
		get {
			if (self.fileURL?.isFileURL) != nil {
				let size = NSMakeSize(CGFloat(kTitleNormal), CGFloat(kTitleNormal))
				
				let tmp = QLThumbnailImageCreate(kCFAllocatorDefault, self.fileURL! as CFURL , size, nil)
				if let tmpImage = tmp?.takeUnretainedValue() {
					let tmpIcon = NSImage(cgImage: tmpImage, size: size)
					return tmpIcon
				}
			}
			let tmpImage = NSImage.init(named: NSImage.Name(rawValue: "docIcon"))
			let docImage = tmpImage?.resize(w: 32, h: 32)
			return docImage
		}
	}

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
		
		//  Record url and type, caller will load via notification
		do {
			self.makeWindowController(typeName)
			NSDocumentController.shared.addDocument(self)
			
			//  Defer custom setups until we have a webView
			if typeName == "Custom" { return }
			
			if url.path.hasSuffix("webloc"), let webURL = url.webloc {
				fileURL = webURL
			}
			else
			{
				fileURL = url
			}
			self.fileType = fileURL?.pathExtension

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
		let storyboard = NSStoryboard(name: NSStoryboard.Name(rawValue: "Main"), bundle: nil)
		let identifier = String(format: "%@Controller", typeName)
		
		let controller = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: identifier)) as! NSWindowController
		self.addWindowController(controller)
		
		//  Delegate will close down any observations before closure
		controller.window?.delegate = controller as? NSWindowDelegate
		
		if (fileURL != nil), let webView = controller.window?.contentView?.subviews.first {
			(webView as! MyWebView).next(url: fileURL!)
		}
	}
	
	override func read(from url: URL, ofType typeName: String) throws {
		do {
			if typeName == "webloc", let webURL = url.webloc {
				fileURL = webURL
			}
			else
			{
				fileURL = url
			}
		}
	}
	
}


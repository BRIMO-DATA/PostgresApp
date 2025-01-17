//
//  ServerManager.swift
//  Postgres
//
//  Created by Chris on 23/06/16.
//  Copyright © 2016 postgresapp. All rights reserved.
//

import Cocoa

class ServerManager: NSObject {
	
	static let shared = ServerManager()
	
	@objc dynamic var servers: [Server] = []
	
	
	func refreshServerStatuses() {
		for server in servers {
			server.updateServerStatus()
		}
	}
	
	func saveServers() {
		var plists: [[AnyHashable: Any]] = []
		for server in servers {
			plists.append(server.asPropertyList)
		}
		UserDefaults.standard.set(plists, forKey: "Servers")
	}
	
	
	func loadServers() {
		servers.removeAll()
		guard let plists = UserDefaults.shared.array(forKey: "Servers") as? [[AnyHashable: Any]] else {
			NSLog("PostgresApp could not load servers from user defaults.")
			return
		}
		for plist in plists {
			guard let server = Server(propertyList: plist) else {
				NSLog("PostgresApp could not load server from user defaults.")
				continue
			}
			servers.append(server)
		}
		// The first time we run this version of Postgres.app, we try to figure out
		// which macOS versions all the data directories were created with.
		// This is needed to show the reindex warning if necessary
		if !UserDefaults.shared.bool(forKey: "DidCheckInitdbOSVersion") {
			for server in servers {
				server.checkInitdbOSVersion()
			}
			UserDefaults.shared.set(true, forKey: "DidCheckInitdbOSVersion")
		}
	}
	
	
	func createDefaultServer() {
		if servers.isEmpty {
			let version = Bundle.main.object(forInfoDictionaryKey: "LatestStablePostgresVersion") as! String
			servers.append(Server(name: "PostgreSQL \(version)", startOnLogin: true))
			saveServers()
		}
	}
	
	
	func checkForExistingDataDirectories() {
		let dataDirsPath = FileManager.default.applicationSupportDirectoryPath()
		guard let dataDirsPathEnum = FileManager().enumerator(at: URL(fileURLWithPath: dataDirsPath), includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsSubdirectoryDescendants, .skipsPackageDescendants, .skipsHiddenFiles]) else { return }
		while let itemURL = dataDirsPathEnum.nextObject() as? URL {
			do {
				let resourceValues = try itemURL.resourceValues(forKeys: [.isDirectoryKey])
				guard resourceValues.isDirectory == true else { continue }
			} catch { continue }
			
			var dataDirHasServer = false
			for server in servers where server.varPath == itemURL.path { dataDirHasServer = true }
			
			if !dataDirHasServer {
				let dataDirName = itemURL.lastPathComponent
				let pgVersionPath = itemURL.appendingPathComponent("PG_VERSION").path
				
				do {
					var version = try String(contentsOfFile: pgVersionPath)
					version.removeLast() // remove \n
					servers.append(Server(name: "PostgreSQL \(version)", version: version, varPath: itemURL.path))
					saveServers()
				} catch {
					NSLog("Import of data directory failed: No valid PG_VERSION file in \(dataDirName)")
				}
			}
		}
	}
	
}


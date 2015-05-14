//
//  JVCoreData.swift
//
//
//  Created by jero on 5/14/15.
//  Copyright (c) 2015 Fluential. All rights reserved.
//

import CoreData
import Foundation

class JVCoreData {
    
    static let kCoreDataModelName = "DataModel"
    
    var managedObjectContext: NSManagedObjectContext
    var managedObjectContextPrivateQueue: NSManagedObjectContext
    var managedObjectContextMainQueue: NSManagedObjectContext
    
    var managedObjectModel: NSManagedObjectModel
    var persistentStoreCoordinator: NSPersistentStoreCoordinator
    
    // MARK: - # Singleton -
    
    struct Static {
        static var instance: JVCoreData?
        static var onceToken: dispatch_once_t = 0
    }
    
    class var sharedInstance: JVCoreData {
        
        if Static.instance == nil {
            dispatch_once(&Static.onceToken) {
                Static.instance = JVCoreData()
            }
        }
        
        return Static.instance!
    }
    
    // MARK: - # Life Cycle -
    
    init() {
        
        var error: NSError? = nil
        
        var modelURL = NSURL.fileURLWithPath(NSBundle.mainBundle().pathForResource(kCoreDataModelName, ofType: "momd")!)
        managedObjectModel = NSManagedObjectModel(contentsOfURL: modelURL!)!
        
        var dbPath = "\(NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.LibraryDirectory, NSSearchPathDomainMask.UserDomainMask, true).last!)/\(kCoreDataModelName).sqlite"
        var storeUrl = NSURL.fileURLWithPath(dbPath)
        
        if !NSFileManager.defaultManager().fileExistsAtPath(storeUrl!.path!) {
            // If there’s no Data Store present (which is the case when the app first launches),
            // identify the sqlite file we added in the Bundle Resources,
            // copy it into the Documents directory, and make it the Data Store.
            var lastPath = dbPath.lastPathComponent
            var components = lastPath.componentsSeparatedByString(".")
            var sqlitePath = NSBundle.mainBundle().pathForResource(components.first, ofType: components.last)
            
            if sqlitePath != nil && NSFileManager.defaultManager().fileExistsAtPath(sqlitePath!) {
                
                if !NSFileManager.defaultManager().copyItemAtPath(sqlitePath!, toPath: storeUrl!.path!, error: &error) {
                    println("Unresolved error \(error), \(error?.userInfo)")
                    error = nil
                }
            }
        }
        
        var options = [NSMigratePersistentStoresAutomaticallyOption: NSNumber(bool: true),
                        NSInferMappingModelAutomaticallyOption: NSNumber(bool: true)]
        
        persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)
        persistentStoreCoordinator.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: storeUrl, options: options, error: &error)
        if error != nil {
            /*
            Replace this implementation with code to handle the error appropriately.
            
            abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. If it is not possible to recover from the error, display an alert panel that instructs the user to quit the application by pressing the Home button.
            
            Typical reasons for an error here include:
            * The persistent store is not accessible
            * The schema for the persistent store is incompatible with current managed object model
            Check the error message to determine what the actual problem was.
            */
            println("Unresolved error \(error), \(error?.userInfo)")
#if DEBUG
            abort()
#endif
        }
        
        managedObjectContext = NSManagedObjectContext()
        managedObjectContext.mergePolicy = NSOverwriteMergePolicy
        managedObjectContext.persistentStoreCoordinator = persistentStoreCoordinator
        
        managedObjectContextMainQueue = NSManagedObjectContext(concurrencyType: NSManagedObjectContextConcurrencyType.MainQueueConcurrencyType)
        managedObjectContextMainQueue.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        managedObjectContextMainQueue.persistentStoreCoordinator = persistentStoreCoordinator
        
        managedObjectContextPrivateQueue = NSManagedObjectContext(concurrencyType: NSManagedObjectContextConcurrencyType.PrivateQueueConcurrencyType)
        managedObjectContextPrivateQueue.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        managedObjectContextPrivateQueue.persistentStoreCoordinator = persistentStoreCoordinator
        
        NSNotificationCenter.defaultCenter().addObserverForName(NSManagedObjectContextDidSaveNotification, object: nil, queue: nil, usingBlock: {(notification: NSNotification!) -> () in
            
            var savedContext = notification.object as! NSManagedObjectContext
            if savedContext == self.managedObjectContextPrivateQueue {
                
                self.managedObjectContextMainQueue.performBlock({() -> () in
                    self.managedObjectContextMainQueue.mergeChangesFromContextDidSaveNotification(notification)
                })
            } else if savedContext == self.managedObjectContextMainQueue {
                
                self.managedObjectContextPrivateQueue.performBlock({() -> () in
                    self.managedObjectContextPrivateQueue.mergeChangesFromContextDidSaveNotification(notification)
                })
            } else {
                
                self.managedObjectContextMainQueue.performBlock({() -> () in
                    self.managedObjectContextMainQueue.mergeChangesFromContextDidSaveNotification(notification)
                })
                self.managedObjectContextPrivateQueue.performBlock({() -> () in
                    self.managedObjectContextPrivateQueue.mergeChangesFromContextDidSaveNotification(notification)
                })
            }
        })
    }
    
    // MARK: - # Private Methods -
    
    
    
    // MARK: - # Public Methods -
    
    func saveContext() {
        
        var error: NSError? = nil
        if (managedObjectContext.hasChanges && !managedObjectContext.save(&error))
        {
            /*
            Replace this implementation with code to handle the error appropriately.
            
            abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            */
            println("Unresolved error \(error), \(error?.userInfo)")
#if DEBUG
            abort()
#endif
        }
    }
    
    func deleteContext() {
        
        for store in persistentStoreCoordinator.persistentStores {
            persistentStoreCoordinator.removePersistentStore(store as! NSPersistentStore, error: nil)
            NSFileManager.defaultManager().removeItemAtPath((store as! NSPersistentStore).URL!.path!, error: nil)
        }
        
        managedObjectContext = NSManagedObjectContext()
        managedObjectContext.mergePolicy = NSOverwriteMergePolicy
        managedObjectContext.persistentStoreCoordinator = persistentStoreCoordinator
        
        managedObjectContextMainQueue = NSManagedObjectContext(concurrencyType: NSManagedObjectContextConcurrencyType.MainQueueConcurrencyType)
        managedObjectContextMainQueue.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        managedObjectContextMainQueue.persistentStoreCoordinator = persistentStoreCoordinator
        
        managedObjectContextPrivateQueue = NSManagedObjectContext(concurrencyType: NSManagedObjectContextConcurrencyType.PrivateQueueConcurrencyType)
        managedObjectContextPrivateQueue.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        managedObjectContextPrivateQueue.persistentStoreCoordinator = persistentStoreCoordinator
    }
}

//
//  TeamcenterModel.swift
//  TCSwiftBridge
//
//  Created by Sedoykin Alexey on 03/08/2025.
//

import Foundation

// MARK: Codable models for the login response

/// Holds server info fields from login response
public struct ServerInfo: Codable {
    let DisplayVersion: String?  // Version display string
    let HostName: String?        // Server host name
    let Locale: String?          // Server locale code
    let LogFile: String?         // Path to server log file
    let SiteLocale: String?      // Locale for the site
    let TcServerID: String?      // Teamcenter server ID
    let UserID: String?          // Logged-in user ID
    let Version: String?         // Server version number
}

/// Top-level login response with QName and serverInfo
public struct LoginResponse: Codable {
    let qName: String?           // XML QName value
    let serverInfo: ServerInfo?  // Server information

    enum CodingKeys: String, CodingKey {
        case qName = ".QName"    // Map JSON field ".QName"
        case serverInfo = "serverInfo"
    }
}

/// Represents a session object with IDs and type info
public struct SessionObject: Codable {
    let objectID: String?   // Optional object identifier
    let cParamID: String?   // Optional parameter ID
    let uid: String         // Unique ID
    let className: String   // Class name of object
    let type: String        // Object type string
}

public typealias ExtraInfo = [String: String]  // Simple key-value extra info

/// Service data includes plain strings and basic folder models
public struct SessionServiceData: Codable {
    let plain: [String]                       // Plain text entries
    let modelObjects: [String: FolderBasic]   // FolderBasic models by UID
}

// A “catch-all” JSON type
public enum JSONValue: Codable {
    case string(String)
    case number(Double)
    case object([String: JSONValue])
    case array([JSONValue])
    case bool(Bool)
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let b = try? container.decode(Bool.self) {
            self = .bool(b)
        } else if let n = try? container.decode(Double.self) {
            self = .number(n)
        } else if let s = try? container.decode(String.self) {
            self = .string(s)
        } else if let arr = try? container.decode([JSONValue].self) {
            self = .array(arr)
        } else if let obj = try? container.decode([String: JSONValue].self) {
            self = .object(obj)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Not a JSON value"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let b):
            try container.encode(b)
        case .number(let n):
            try container.encode(n)
        case .string(let s):
            try container.encode(s)
        case .array(let a):
            try container.encode(a)
        case .object(let o):
            try container.encode(o)
        }
    }
}

/// Full response for GetTCSessionInfo API call
public struct SessionInfoResponse: Codable {
    let qName: String?                 // XML QName
    let serverVersion: String          // Version of server
    let transientVolRootDir: String    // Root directory for transients
    let isInV7Mode: Bool               // Mode flag
    let moduleNumber: Int              // Module number
    let bypass: Bool                   // Bypass setting
    let journaling: Bool               // Journaling enabled
    let appJournaling: Bool            // App journaling
    let secJournaling: Bool            // Security journaling
    let admJournaling: Bool            // Admin journaling
    let privileged: Bool               // Privileged session flag
    let isPartBOMUsageEnabled: Bool    // BOM part usage
    let isSubscriptionMgrEnabled: Bool // Subscription manager

    // Main session objects for user, group, role, etc.
    let user: SessionObject
    let group: SessionObject
    let role: SessionObject
    let tcVolume: SessionObject
    let project: SessionObject
    let workContext: SessionObject
    let site: SessionObject

    let textInfos: [String]            // Text info entries
    let extraInfo: ExtraInfo           // Extra key-value pairs
    let serviceData: SessionServiceData? // Optional service data

    enum CodingKeys: String, CodingKey {
        case qName = ".QName"
        case serverVersion, transientVolRootDir, isInV7Mode, moduleNumber
        case bypass, journaling, appJournaling, secJournaling, admJournaling
        case privileged, isPartBOMUsageEnabled, isSubscriptionMgrEnabled
        case user, group, role, tcVolume, project, workContext, site
        case textInfos, extraInfo
        case serviceData = "ServiceData"
    }
}

// MARK: Codable models for expandFolder response

/// Basic info for a folder, may be in first level or modelObjects
public struct FolderBasic: Codable {
    public let objectID: String?
    public let uid: String
    public let className: String
    public let type: String
}

/// One element of "output" array from expandFolder API
public struct ExpandFolderOutput: Codable {
    let inputFolder: FolderBasic     // The folder we expanded
    let fstlvlFolders: [FolderBasic] // Subfolders at first level
    // itemsOutput and itemRevsOutput can be added if needed
}

/// ServiceData for expandFolder with plain entries and modelObjects
public struct ExpandServiceData: Codable {
    let plain: [String]                        // Plain text entries
    let modelObjects: [String: FolderBasic]    // FolderBasic models by UID
}

/// Top-level response for expandFolder API
public struct ExpandFolderResponse: Codable {
    let qName: String?                      // XML QName
    let output: [ExpandFolderOutput]?       // Expand output list
    let serviceData: ExpandServiceData?     // Service data

    enum CodingKeys: String, CodingKey {
        case qName = ".QName"
        case output
        case serviceData = "ServiceData"
    }
}

// MARK: Codable models for getProperties response

/// Holds database and UI values for one property
public struct PropertyValue: Codable {
    let dbValues: [String]?  // Raw database values
    let uiValues: [String]?  // Formatted UI values
}

/// One model object entry in getProperties response
public struct ModelObject: Codable {
    let objectID: String?                // Optional object ID
    let uid: String?                     // Unique ID
    let className: String?               // Class name
    let type: String?                    // Object type
    let props: [String: PropertyValue]?  // Property values by name
}

/// Top-level response for getProperties API
public struct GetPropertiesResponse: Codable {
    let qName: String?                          // XML QName
    let plain: [String]?                        // Plain text entries
    let modelObjects: [String: ModelObject]?    // ModelObject entries by UID

    enum CodingKeys: String, CodingKey {
        case qName = ".QName"
        case plain, modelObjects
    }
}

// MARK: Codable models for createItem response

/// Output for createItem API: nested item and revision
public struct CreateItemsOutput: Codable {
    struct NestedObject: Codable {
        let uid: String  // UID of created item or revision
    }
    let item: NestedObject    // Created item
    let itemRev: NestedObject // Created item revision
}

/// Top-level for createItem API
public struct CreateItemsResponse: Codable {
    let output: [CreateItemsOutput]?  // List of created outputs

    enum CodingKeys: String, CodingKey {
        case output
    }
}

// MARK: Codable models for createFolder response

/// Output for createFolder API: nested folder object
public struct CreateFoldersOutput: Codable {
    struct FolderObj: Codable {
        let uid: String      // UID of new folder
        let className: String // Class name of folder
        let type: String     // Object type string
    }
    let folder: FolderObj   // Created folder object
}

/// Top-level for createFolder API
public struct CreateFoldersResponse: Codable {
    let output: [CreateFoldersOutput]?  // List of created folders

    enum CodingKeys: String, CodingKey {
        case output
    }
}

// MARK: Codable models for getItemFromId response

/// Top-level response for getItemFromId API
public struct GetItemFromIdResponse: Codable {
    let qName: String?                 // e.g. "...GetItemFromIdResponse"
    let output: [GetItemFromIdOutput]? // Array of item + revision outputs

    enum CodingKeys: String, CodingKey {
        case qName = ".QName"
        case output
    }
}

/// One entry of item + its revisions
public struct GetItemFromIdOutput: Codable {
    let item: FolderBasic            // Reuses FolderBasic (uid, className, type)
    let itemRevOutput: [ItemRevOutput]

    enum CodingKeys: String, CodingKey {
        case item
        case itemRevOutput
    }
}

/// Wrapper for the revision inside GetItemFromIdOutput
public struct ItemRevOutput: Codable {
    let itemRevision: FolderBasic    // uid, className, type
}

// MARK: Codable models for createBOMWindows response

/// Top-level response for CreateBOMWindows API
public struct CreateBOMWindowsResponse: Codable {
    let qName: String?                        // e.g. "...CreateBOMWindowsResponse"
    let output: [CreateBOMWindowsOutput]?     // List of outputs

    enum CodingKeys: String, CodingKey {
        case qName = ".QName"
        case output
    }
}

/// One output entry with window and line
public struct CreateBOMWindowsOutput: Codable {
    let clientId: String                      // Echoed clientId
    let bomWindow: FolderBasic                // UID, className, type of BOMWindow
    let bomLine: FolderBasic                  // UID, className, type of BOMLine
}

// MARK: Codable models for saveBOMWindows response

/// Top-level for SaveBOMWindows API
public struct SaveBOMWindowsResponse: Codable {
    let qName: String?                      // e.g. "...SaveBOMWindowsResponse"
    let serviceData: SaveBOMWindowsServiceData

    enum CodingKeys: String, CodingKey {
        case qName = ".QName"
        case serviceData = "ServiceData"
    }
}

/// Holds the list of updated UIDs and any returned objects
public struct SaveBOMWindowsServiceData: Codable {
    let updated: [String]                   // UIDs of updated objects
    let modelObjects: [String: ModelObject] // Map of UID → full object info

    enum CodingKeys: String, CodingKey {
        case updated
        case modelObjects = "modelObjects"
    }
}


// MARK: Codable models for closeBOMWindows response

/// Top-level response for CloseBOMWindows API
public struct CloseBOMWindowsResponse: Codable {
    let qName: String?                          // e.g. "...CloseBOMWindowsResponse"
    let serviceData: CloseBOMWindowsServiceData // decoded from "ServiceData"

    enum CodingKeys: String, CodingKey {
        case qName = ".QName"
        case serviceData = "ServiceData"
    }
}

/// Holds the list of deleted BOM window UIDs
public struct CloseBOMWindowsServiceData: Codable {
    let deleted: [String]
}

// MARK: Codable models for addOrUpdateChildrenToParentLine response

/// Top-level response for AddOrUpdateChildrenToParentLine API
public struct AddOrUpdateChildrenToParentLineResponse: Codable {
    let qName: String?                                 // XML QName
    let itemLines: [ItemLine]?                         // Updated or created child lines
    let itemelementLines: [ItemElementLine]?           // Updated or created element‐lines
    let serviceData: AddOrUpdateChildrenServiceData?   // Created/updated UIDs & errors

    enum CodingKeys: String, CodingKey {
        case qName    = ".QName"
        case itemLines
        case itemelementLines
        case serviceData = "ServiceData"
    }
}

/// One BOM‐line entry in the response
public struct ItemLine: Codable {
    let clientId: String
    let bomline: FolderBasic
}

/// One element‐line entry (if any) in the response
public struct ItemElementLine: Codable {
    let clientId: String
    let itemelementLine: FolderBasic
}

/// ServiceData with created/updated UIDs and any partial errors
public struct AddOrUpdateChildrenServiceData: Codable {
    let updated: [String]?
    let created: [String]?
    let modelObjects: [String: FolderBasic]?
    let partialErrors: [PartialError]?

    enum CodingKeys: String, CodingKey {
        case updated, created, modelObjects, partialErrors
    }
}

/// One error block for a single UID
public struct PartialError: Codable {
    let uid: String
    let errorValues: [ErrorValue]
}

/// Detailed error info
public struct ErrorValue: Codable {
    let message: String
    let code: Int
    let level: Int
}

// MARK: Codable models for getSavedQueries response

/// One saved‐query entry
public struct SavedQueryEntry: Codable {
    public let name: String
    public let description: String
    public let query: FolderBasic

    enum CodingKeys: String, CodingKey {
        case name, description, query
    }
}

/// ServiceData for getSavedQueries
public struct SavedQueriesServiceData: Codable {
    public let plain: [String]?
    public let modelObjects: [String: FolderBasic]?
    
    enum CodingKeys: String, CodingKey {
        case plain, modelObjects
    }
}

/// Top‐level response for getSavedQueries
public struct GetSavedQueriesResponse: Codable {
    public let qName: String?
    public let queries: [SavedQueryEntry]?
    public let serviceData: SavedQueriesServiceData?

    enum CodingKeys: String, CodingKey {
        case qName = ".QName"
        case queries
        case serviceData = "ServiceData"
    }
}

/// Flattened info for easier use
public struct SavedQueryInfo {
    public let name: String
    public let description: String
    public let uid: String
    public let objectID: String
    public let className: String
    public let type: String
}

// MARK: – Models for findSavedQueries

/// Top‐level response
public struct FindSavedQueriesResponse: Codable {
    public let qName: String?
    public let savedQueries: [FolderBasic]? //reuse from Folder
    public let serviceData: GetPropertiesResponse?   // re–use your existing GetPropertiesResponse for the modelObjects

    enum CodingKeys: String, CodingKey {
        case qName = ".QName"
        case savedQueries
        case serviceData = "ServiceData"
    }
}


// MARK: Codable models for CreateRelations response

/// One output entry for createRelation
public struct CreateRelationsOutput: Codable {
    public let clientId: String
    public let relation: FolderBasic

    enum CodingKeys: String, CodingKey {
        case clientId, relation
    }
}

/// Top‐level response for createRelation
public struct CreateRelationsResponse: Codable {
    public let qName: String?
    public let output: [CreateRelationsOutput]?
    public let serviceData: SaveBOMWindowsServiceData?  // reuse the existing ServiceData model if shape matches

    enum CodingKeys: String, CodingKey {
        case qName = ".QName"
        case output
        case serviceData = "ServiceData"
    }
}

// MARK: Codable models for getRevisionRules response

/// One entry in GetRevisionRules output
public struct RevisionRuleEntry: Codable {
    public let revRule: FolderBasic
    public let hasValueStatus: [String: Bool]
    public let overrideFolders: [JSONValue]  // empty list in current payload

    enum CodingKeys: String, CodingKey {
        case revRule, hasValueStatus, overrideFolders
    }
}

/// Top‐level response for getRevisionRules
public struct GetRevisionRulesResponse: Codable {
    public let qName: String?
    public let output: [RevisionRuleEntry]?
    public let serviceData: SessionServiceData?  // reuse your existing type for ServiceData

    enum CodingKeys: String, CodingKey {
        case qName = ".QName"
        case output
        case serviceData = "ServiceData"
    }
}


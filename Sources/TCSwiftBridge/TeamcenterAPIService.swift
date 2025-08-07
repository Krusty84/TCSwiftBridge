//
//  TeamcenterAPIService.swift
//  TCSwiftBridge
//
//  Created by Sedoykin Alexey on 03/08/2025.
//

import Foundation
import Combine

// Service class to call Teamcenter REST APIs
// Conforms to ObservableObject for SwiftUI bindings
public final class TeamcenterAPIService: ObservableObject {
    // Shared singleton instance
    public static let shared = TeamcenterAPIService()
    // Published JSESSIONID string after a successful login
    @Published public var jsessionId: String? = nil
    //
    public struct RawLog {
        public let endpoint: String
        public let status: Int
        public let body: Data
    }
    @Published public var lastRaw: RawLog?
    public var onRaw: ((RawLog) -> Void)?
    /*
     let (data, response) = try await URLSession.shared.data(for: request)
     if let http = response as? HTTPURLResponse {
         self.emitRaw(request.url!, http, data) //<-- add for get Raw JSON response
     }
     */
    private func emitRaw(_ url: URL, _ http: HTTPURLResponse, _ data: Data) {
        let log = RawLog(endpoint: url.absoluteString, status: http.statusCode, body: data)
        DispatchQueue.main.async {
            self.lastRaw = log
            self.onRaw?(log)
        }
    }
    
    // Private init to enforce singleton pattern
    private init() {}
    
    /// Login to Teamcenter and store JSESSIONID cookie
    /// - Parameters:
    ///   - tcEndpointUrl: Full login URL for Teamcenter
    ///   - userName: User's login name
    ///   - userPassword: User's password
    /// - Returns: JSESSIONID string if successful, else nil
    public func tcLogin(
        tcEndpointUrl: String,
        userName: String,
        userPassword: String
    ) async -> String? {
        // 1. Build URL from string
        guard let url = URL(string: tcEndpointUrl) else {
            print("Invalid URL:", tcEndpointUrl)
            return nil
        }
        
        // 2. Create payload with empty header and login credentials
        let payload: [String: Any] = [
            "header": ["state": [:], "policy": [:]],
            "body": [
                "credentials": [
                    "user": userName,
                    "password": userPassword,
                    "role": "",
                    "descrimator": "",
                    "locale": "",
                    "group": ""
                ]
            ]
        ]
        
        // 3. Convert payload to JSON data
        let jsonData: Data
        do {
            jsonData = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            print("Could not encode JSON:", error)
            return nil
        }
        
        // 4. Build POST request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        do {
            // 5. Send network request
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                self.emitRaw(request.url!, http, data)
            }
            guard let http = response as? HTTPURLResponse else {
                print("Not an HTTP response")
                return nil
            }
            
            // 6. Parse JSON response into dictionary
            guard
                let jsonObj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                let qName = jsonObj[".QName"] as? String
            else {
                print("Bad JSON or missing .QName")
                return nil
            }
            
            // 7. Check if login succeeded or failed
            if qName.contains("Session.LoginResponse") {
                // success, proceed
            } else {
                // failure: log server message if present
                if let msg = jsonObj["message"] as? String {
                    print("Login error from server:", msg)
                } else {
                    print("Login failed with exception:", qName)
                }
                return nil
            }
            
            // 8. Extract JSESSIONID from Set-Cookie header
            if let cookieHeader = http.value(forHTTPHeaderField: "Set-Cookie") {
                let parts = cookieHeader
                    .split(separator: ";")
                    .map(String.init)
                if let jsPart = parts.first(where: { $0.hasPrefix("JSESSIONID=") }),
                   let newID = jsPart.split(separator: "=").last
                {
                    let session = String(newID)
                    // Update published property on main thread
                    DispatchQueue.main.async {
                        self.jsessionId = session
                    }
                    print("Got new JSESSIONID:", session)
                    return session
                }
            }
            
            // 9. If no new cookie but status is 2xx, reuse old session
            if (200...299).contains(http.statusCode),
               let old = self.jsessionId
            {
                print("Reusing old JSESSIONID:", old)
                return old
            }
            
            // 10. Unexpected case: no session found
            print("Login got status \(http.statusCode) but no session")
            return nil
            
        } catch {
            print("Network or JSON error:", error)
            return nil
        }
    }
    
    /// Fetch session info using stored JSESSIONID
    /// - Parameter tcEndpointUrl: URL for session info API
    /// - Returns: Decoded SessionInfoResponse or nil
    public func getTcSessionInfo(tcEndpointUrl: String) async -> SessionInfoResponse? {
        // 1) Ensure we are logged in
        guard let session = self.jsessionId else {
            print("No JSESSIONID found. Please login first.")
            return nil
        }
        
        // 2) Create URL
        guard let url = URL(string: tcEndpointUrl) else {
            print("Invalid URL string: \(tcEndpointUrl)")
            return nil
        }
        
        // 3) Minimal payload with empty header
        let payload: [String: Any] = [
            "header": ["state": [:], "policy": [:]]
        ]
        
        // 4) Encode payload
        let jsonData: Data
        do {
            jsonData = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            print("Failed to serialize JSON payload for session info:", error)
            return nil
        }
        
        // 5) Build request with Cookie header
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("JSESSIONID=\(session)", forHTTPHeaderField: "Cookie")
        request.httpBody = jsonData
        
        do {
            // 6) Send request
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                self.emitRaw(request.url!, http, data)
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                print("No HTTPURLResponse when fetching session info.")
                return nil
            }
            
            // 7) Check for 2xx status code
            guard (200...299).contains(httpResponse.statusCode) else {
                print("Failed to fetch session info. HTTP status:", httpResponse.statusCode)
                return nil
            }
            
            // 8) Decode JSON into SessionInfoResponse
            let decoder = JSONDecoder()
            do {
                let sessionInfo = try decoder.decode(SessionInfoResponse.self, from: data)
                return sessionInfo
            } catch {
                print("Could not decode JSON for session info:", error)
                return nil
            }
            
        } catch {
            print("Network error during session info request:", error)
            return nil
        }
    }
    
    /// Get properties of a single object by UID
    public func getProperties(
        tcEndpointUrl: String,
        uid: String,
        className: String,
        type: String,
        attributes: [String]
    ) async -> [String: String]? {
        // 1a) Check login
        guard let session = self.jsessionId else {
            print("Cannot call getProperties: no JSESSIONID stored. Please login first.")
            return nil
        }
        // 1b) Build URL
        guard let url = URL(string: tcEndpointUrl) else {
            print("Invalid getProperties URL: \(tcEndpointUrl)")
            return nil
        }
        
        // 1c) Single object descriptor dictionary
        let objectEntry: [String: String] = [
            "uid": uid,
            "className": className,
            "type": type
        ]
        
        // 1d) Full payload with header and body
        let payload: [String: Any] = [
            "header": ["state": [:], "policy": [:]],
            "body": [
                "objects": [objectEntry],
                "attributes": attributes
            ]
        ]
        
        // 1e) Serialize JSON
        let jsonData: Data
        do {
            jsonData = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            print("Failed to serialize JSON for getProperties: \(error)")
            return nil
        }
        
        // 1f) Build POST request with Cookie
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("JSESSIONID=\(session)", forHTTPHeaderField: "Cookie")
        request.httpBody = jsonData
        
        do {
            // 1g) Execute network call
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                self.emitRaw(request.url!, http, data)
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                print("getProperties did not return an HTTPURLResponse.")
                return nil
            }
            guard (200...299).contains(httpResponse.statusCode) else {
                print("getProperties failed. HTTP status = \(httpResponse.statusCode).")
                return nil
            }
            
            // 1h) Decode JSON via Codable
            let decoder = JSONDecoder()
            let responseObj = try decoder.decode(GetPropertiesResponse.self, from: data)
            
            // 1i) Locate our single object and its props
            guard
                let modelDict = responseObj.modelObjects,
                let singleObj = modelDict[uid],
                let allProps = singleObj.props
            else {
                print("No modelObjects or props found for UID \(uid).")
                return nil
            }
            
            // 1j) Build result dictionary of first UI value per attribute
            var result: [String: String] = [:]
            for attr in attributes {
                if let propValue = allProps[attr],
                   let firstUi = propValue.uiValues?.first {
                    result[attr] = firstUi
                } else {
                    result[attr] = "" // empty if missing
                }
            }
            return result
            
        } catch {
            print("Network or decoding error during getProperties: \(error)")
            return nil
        }
    }
    
    /// Fetch the home_folder attribute for a given user
    public func getUserHomeFolder(
        tcEndpointUrl: String,
        userUid: String
    ) async -> String? {
        // 1) Ensure login
        guard let session = self.jsessionId else {
            print("No JSESSIONID found. Please login first.")
            return nil
        }
        
        // 2) Build URL
        guard let url = URL(string: tcEndpointUrl) else {
            print("Invalid URL string: \(tcEndpointUrl)")
            return nil
        }
        
        // 3) Payload requesting only home_folder
        let payload: [String: Any] = [
            "header": ["state": [:], "policy": [:]],
            "body": [
                "objects": [[
                    "uid": userUid,
                    "className": "User",
                    "type": "User"
                ]],
                "attributes": ["home_folder"]
            ]
        ]
        
        // 4) Encode to JSON
        let jsonData: Data
        do {
            jsonData = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            print("Failed to serialize JSON for getUserHomeFolder: \(error)")
            return nil
        }
        
        // 5) Build request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("JSESSIONID=\(session)", forHTTPHeaderField: "Cookie")
        request.httpBody = jsonData
        
        do {
            // 6) Send request
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                self.emitRaw(request.url!, http, data)
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                print("getUserHomeFolder did not return an HTTPURLResponse.")
                return nil
            }
            
            // 7) Check for success
            guard (200...299).contains(httpResponse.statusCode) else {
                print("getUserHomeFolder failed. HTTP status =", httpResponse.statusCode)
                return nil
            }
            
            // 8) Decode using GetPropertiesResponse
            let decoder = JSONDecoder()
            let respObj = try decoder.decode(GetPropertiesResponse.self, from: data)
            
            // 9) Find property value
            guard
                let modelDict = respObj.modelObjects,
                let userObj = modelDict[userUid],
                let props = userObj.props
            else {
                print("No modelObjects or props found for user UID \(userUid).")
                return nil
            }
            
            // 10) Return first dbValue for home_folder
            if let homeVal = props["home_folder"]?.dbValues?.first {
                return homeVal
            } else {
                print("\"home_folder\" not found or has no dbValues.")
                return nil
            }
            
        } catch {
            print("Network or decoding error during getUserHomeFolder:", error)
            return nil
        }
    }
    
    /// Expand a folder, then fetch properties for each sub-object
    public func expandFolder(
        tcUrl: String,
        folderUid: String,
        className: String = "Folder",
        type: String = "Fnd0HomeFolder",
        expItemRev: Bool,
        latestNRevs: Int,
        info: [[String: Any]],
        contentTypesFilter: [String],
        propertyAttributes: [String]
    ) async -> [[String: Any]]? {
        // 2a) Ensure login
        guard let session = self.jsessionId else {
            print("Cannot call expandFolder: no JSESSIONID stored. Please login first.")
            return nil
        }
        
        // 2b) Build URLs for expand and getProperties
        let expandUrlString = APIConfig.tcExpandFolder(tcUrl: tcUrl)
        let propsUrlString = APIConfig.tcGetPropertiesUrl(tcUrl: tcUrl)
        
        guard
            let expandUrl = URL(string: expandUrlString),
            URL(string: propsUrlString) != nil
        else {
            print("Invalid expandFolder or getProperties URL.")
            return nil
        }
        
        // 2c) Single folder descriptor
        let folderEntry: [String: String] = [
            "uid": folderUid,
            "className": className,
            "type": type
        ]
        
        // 2d) Preferences dictionary
        let pref: [String: Any] = [
            "expItemRev": expItemRev,
            "latestNRevs": latestNRevs,
            "info": info,
            "contentTypesFilter": contentTypesFilter
        ]
        
        // 2e) Build expandFolder payload
        let expandPayload: [String: Any] = [
            "header": ["state": [:], "policy": [:]],
            "body": [
                "folders": [folderEntry],
                "pref": pref
            ]
        ]
        
        // 2f) Serialize payload
        let expandData: Data
        do {
            expandData = try JSONSerialization.data(withJSONObject: expandPayload)
        } catch {
            print("Failed to serialize JSON for expandFolder: \(error)")
            return nil
        }
        
        // 2g) Build expandFolder request
        var expandRequest = URLRequest(url: expandUrl)
        expandRequest.httpMethod = "POST"
        expandRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        expandRequest.setValue("JSESSIONID=\(session)", forHTTPHeaderField: "Cookie")
        expandRequest.httpBody = expandData
        
        // 2h) Send request and check status
        let responseData: Data
        do {
            let (data, response) = try await URLSession.shared.data(for: expandRequest)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode)
            else {
                print("expandFolder failed. HTTP status not 2xx.")
                return nil
            }
            responseData = data
        } catch {
            print("Network or decoding error during expandFolder: \(error)")
            return nil
        }
        
        // 2i) Decode expandFolder JSON
        let decoder = JSONDecoder()
        let expandResponseObj: ExpandFolderResponse
        do {
            expandResponseObj = try decoder.decode(ExpandFolderResponse.self, from: responseData)
        } catch {
            print("Failed to decode expandFolder JSON: \(error)")
            return nil
        }
        
        // 2j) Extract serviceData modelObjects
        guard let serviceData = expandResponseObj.serviceData else {
            print("No \"ServiceData\" in expandFolder response.")
            return nil
        }
        let modelObjects = serviceData.modelObjects
        
        // 2k) Prepare results array
        var finalResults: [[String: Any]] = []
        
        // 2l) Iterate over each FolderBasic in modelObjects
        for (_, folderInfo) in modelObjects {
            let cls = folderInfo.className
            let typ = folderInfo.type
            let uid = folderInfo.uid
            
            // 2l-ii) Fetch properties for this folder
            guard
                let parsedProps = await getProperties(
                    tcEndpointUrl: propsUrlString,
                    uid: uid,
                    className: cls,
                    type: typ,
                    attributes: propertyAttributes
                )
            else {
                continue // skip on failure
            }
            
            // 2l-iii) Build result dictionary with basic info and attributes
            var resultEntry: [String: Any] = [
                "uid": uid,
                "className": cls,
                "type": typ
            ]
            for (attrName, uiValue) in parsedProps {
                resultEntry[attrName] = uiValue
            }
            
            // 2l-iv) Add to final results
            finalResults.append(resultEntry)
        }
        
        // 2m) Return collected data
        return finalResults
    }
    
    /// Create a new Teamcenter item under a container
    public func createItem(
        tcEndpointUrl: String,
        name: String,
        type: String,
        description: String,
        containerUid: String,
        containerClassName: String,
        containerType: String
    ) async -> (itemUid: String?, itemRevUid: String?) {
        // 1. Check login
        guard let session = jsessionId else {
            print("No JSESSIONID—login first.")
            return (nil, nil)
        }
        
        // 2. Build URL
        guard let url = URL(string: tcEndpointUrl) else {
            print("Bad URL:", tcEndpointUrl)
            return (nil, nil)
        }
        
        // 3. Build create-item payload
        let payload: [String: Any] = [
            "header": ["state": [:], "policy": [:]],
            "body": [
                "properties": [[
                    "clientId": "",
                    "itemId": "",
                    "name": name,
                    "type": type,
                    "revId": "",
                    "uom": "",
                    "description": description,
                    "extendedAttributes": []
                ]],
                "container": [
                    "uid": containerUid,
                    "className": containerClassName,
                    "type": containerType
                ],
                "relationType": ""
            ]
        ]
        
        // 4. Serialize JSON
        let jsonData: Data
        do {
            jsonData = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            print("JSON error:", error)
            return (nil, nil)
        }
        
        // 5. Build POST request
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("JSESSIONID=\(session)", forHTTPHeaderField: "Cookie")
        req.httpBody = jsonData
        
        do {
            // 6. Send request and check status
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                print("HTTP error:", resp)
                return (nil, nil)
            }
            
            // 7. Decode CreateItemsResponse
            let decoder = JSONDecoder()
            let createResp = try decoder.decode(CreateItemsResponse.self, from: data)
            if let first = createResp.output?.first {
                return (first.item.uid, first.itemRev.uid)
            } else {
                print("No output in response")
                return (nil, nil)
            }
        } catch {
            print("Network/decode error:", error)
            return (nil, nil)
        }
    }
    
    /// Create a new folder under a container
    public func createFolder(
        tcEndpointUrl: String,
        name: String,
        desc: String,
        containerUid: String,
        containerClassName: String,
        containerType: String
    ) async -> (uid: String?, className: String?, type: String?) {
        // 1. Ensure login
        guard let session = jsessionId else {
            print("No JSESSIONID—please login first.")
            return (nil, nil, nil)
        }
        
        // 2. Build URL
        guard let url = URL(string: tcEndpointUrl) else {
            print("Invalid URL:", tcEndpointUrl)
            return (nil, nil, nil)
        }
        
        // 3. Build create-folder payload
        let payload: [String: Any] = [
            "header": ["state": [:], "policy": [:]],
            "body": [
                "folders": [[
                    "clientId": "",
                    "name": name,
                    "desc": desc
                ]],
                "container": [
                    "uid": containerUid,
                    "className": containerClassName,
                    "type": containerType
                ],
                "relationType": "contents"
            ]
        ]
        
        // 4. Serialize JSON
        let jsonData: Data
        do {
            jsonData = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            print("JSON serialization error:", error)
            return (nil, nil, nil)
        }
        
        // 5. Build POST request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("JSESSIONID=\(session)", forHTTPHeaderField: "Cookie")
        request.httpBody = jsonData
        
        do {
            // 6. Send request and check status
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                self.emitRaw(request.url!, http, data)
            }
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else {
                print("HTTP error creating folder:", response)
                return (nil, nil, nil)
            }
            
            // 7. Decode CreateFoldersResponse
            let decoder = JSONDecoder()
            let resp = try decoder.decode(CreateFoldersResponse.self, from: data)
            
            // 8. Return first folder info
            if let first = resp.output?.first?.folder {
                return (first.uid, first.className, first.type)
            } else {
                print("No folder info in response.")
                return (nil, nil, nil)
            }
            
        } catch {
            print("Network or decode error in createFolder:", error)
            return (nil, nil, nil)
        }
    }
    
    /// Create a relation between two objects
    public func createRelation(
            tcEndpointUrl: String,
            firstUid: String,
            firstType: String,
            secondUid: String,
            secondType: String,
            relationType: String
        ) async -> FolderBasic? {
            // 1) Check session
            guard let session = jsessionId else {
                print("No JSESSIONID—please login first.")
                return nil
            }
            // 2) URL
            guard let url = URL(string: tcEndpointUrl) else {
                print("Invalid URL:", tcEndpointUrl)
                return nil
            }
            // 3) Payload
            let payload: [String: Any] = [
                "header": ["state": [:], "policy": [:]],
                "body": [
                    "input": [
                        [
                            "primaryObject": [
                                "uid": firstUid,
                                "type": firstType
                            ],
                            "secondaryObject": [
                                "uid": secondUid,
                                "type": secondType
                            ],
                            "relationType": relationType,
                            "clientId": "",
                            "userData": ["uid": "", "type": ""]
                        ]
                    ]
                ]
            ]
            // 4) JSON encode
            let jsonData: Data
            do {
                jsonData = try JSONSerialization.data(withJSONObject: payload)
            } catch {
                print("Failed to serialize JSON for createRelation:", error)
                return nil
            }
            // 5) Build request
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("JSESSIONID=\(session)", forHTTPHeaderField: "Cookie")
            request.httpBody = jsonData

            do {
                // 6) Send
                let (data, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse {
                    self.emitRaw(request.url!, http, data)
                    guard (200...299).contains(http.statusCode) else {
                        print("createRelation failed. HTTP status =", http.statusCode)
                        return nil
                    }
                }
                // 7) Decode
                let decoder = JSONDecoder()
                let resp = try decoder.decode(CreateRelationsResponse.self, from: data)
                guard let first = resp.output?.first else {
                    print("No output in createRelation response")
                    return nil
                }
                // 8) Return the created relation
                return first.relation
            } catch {
                print("Network or decode error in createRelation:", error)
                return nil
            }
        }
    
    /// Fetch an item and its revision by itemId and revIds
    public func getItemFromId(
        tcEndpointUrl: String,
        itemId: String,
        revIds: [String]
    ) async -> (itemUid: String?, itemRevUid: String?) {
        // 1) Make sure we have a session
        guard let session = jsessionId else {
            print("No JSESSIONID—login first.")
            return (nil, nil)
        }
        
        
        
        // 2) Build the URL
        guard let url = URL(string: tcEndpointUrl) else {
            print("Invalid URL:", tcEndpointUrl)
            return (nil, nil)
        }
        
        // 3) Build the JSON payload
        let payload: [String: Any] = [
            "header": ["state": [:], "policy": [:]],
            "body": [
                "infos": [
                    [
                        "itemId": itemId,
                        "revIds": revIds
                    ]
                ],
                "nRev": 1,
                "pref": [:]
            ]
        ]
        
        // 4) Serialize payload
        let jsonData: Data
        do {
            jsonData = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            print("Failed to serialize JSON for getItemFromId:", error)
            return (nil, nil)
        }
        
        // 5) Build the request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("JSESSIONID=\(session)", forHTTPHeaderField: "Cookie")
        request.httpBody = jsonData
        
        do {
            // 6) Send request
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                self.emitRaw(request.url!, http, data)
            }
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else {
                print("HTTP error in getItemFromId:", response)
                return (nil, nil)
            }
            
            // 7) Decode JSON
            let decoder = JSONDecoder()
            let resp = try decoder.decode(GetItemFromIdResponse.self, from: data)
            
            // 8) Pull out the first item + revision
            if let first = resp.output?.first {
                let itemUid = first.item.uid
                let itemRevUid = first.itemRevOutput.first?.itemRevision.uid
                return (itemUid, itemRevUid)
            } else {
                print("No output in getItemFromId response")
                return (nil, nil)
            }
            
        } catch {
            print("Network or decode error in getItemFromId:", error)
            return (nil, nil)
        }
    }
    
    /// Fetch list of all saved queries
    public func getSavedQueries(
            tcEndpointUrl: String
        ) async -> [SavedQueryInfo]? {
            // 1) Ensure we have a session
            guard let session = jsessionId else {
                print("No JSESSIONID—please login first.")
                return nil
            }
            // 2) Build URL
            guard let url = URL(string: tcEndpointUrl) else {
                print("Invalid URL:", tcEndpointUrl)
                return nil
            }
            // 3) Payload with empty header
            let payload: [String: Any] = [
                "header": ["state": [:], "policy": [:]]
            ]
            // 4) Serialize JSON
            let jsonData: Data
            do {
                jsonData = try JSONSerialization.data(withJSONObject: payload)
            } catch {
                print("Failed to serialize JSON for getSavedQueries:", error)
                return nil
            }
            // 5) Build request
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("JSESSIONID=\(session)", forHTTPHeaderField: "Cookie")
            request.httpBody = jsonData

            do {
                // 6) Send request
                let (data, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse {
                    self.emitRaw(request.url!, http, data)
                    guard (200...299).contains(http.statusCode) else {
                        print("getSavedQueries failed. HTTP status =", http.statusCode)
                        return nil
                    }
                }
                // 7) Decode JSON
                let decoder = JSONDecoder()
                let resp = try decoder.decode(GetSavedQueriesResponse.self, from: data)
                guard let entries = resp.queries else {
                    print("No 'queries' array in response")
                    return nil
                }
                // 8) Flatten into SavedQueryInfo
                return entries.map { entry in
                    let q = entry.query
                    return SavedQueryInfo(
                        name: entry.name,
                        description: entry.description,
                        uid: q.uid,
                        objectID: q.uid,
                        className: q.className,
                        type: q.type
                    )
                }
            } catch {
                print("Network or decode error in getSavedQueries:", error)
                return nil
            }
        }
    
    /// Search for saved queries by name/desc pattern
    public func findSavedQueries(
      tcEndpointUrl: String
    ) async -> [SavedQueryInfo]? {
      guard let session = jsessionId else { print(...); return nil }
      guard let url = URL(string: tcEndpointUrl) else { print(...); return nil }
      
      // build payload & JSON‐encode…
      var request = URLRequest(url: url)
      // set method, headers, body…
      
      do {
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse {
          emitRaw(request.url!, http, data)
          guard (200...299).contains(http.statusCode) else {
            print("HTTP error", http.statusCode)
            return nil
          }
        }
        let resp = try JSONDecoder()
                      .decode(FindSavedQueriesResponse.self, from: data)
        guard
          let rawList = resp.savedQueries,
          let models  = resp.serviceData?.modelObjects
        else {
          print("Missing savedQueries or modelObjects")
          return nil
        }

          let result: [SavedQueryInfo] = rawList.compactMap { basic -> SavedQueryInfo? in
            guard
              let model = models[basic.uid],
              let name  = model.props?["query_name"]?.uiValues?.first,
              let desc  = model.props?["query_desc"]?.uiValues?.first
            else {
              return nil
            }
            // if objectID is nil, fall back to uid
            let objID = basic.objectID ?? basic.uid
            return SavedQueryInfo(
              name: name,
              description:  desc,
              uid:         basic.uid,
              objectID:   objID,
              className:   basic.className,
              type:        basic.type
            )
          }
          return result

      } catch {
        print("Network or decode error:", error)
        return nil
      }
    }
    
    /// Fetch all revision rules
    public func getRevisionRules(
            tcEndpointUrl: String
        ) async -> [RevisionRuleEntry]? {
            // 1) Check login
            guard let session = jsessionId else {
                print("No JSESSIONID—please login first.")
                return nil
            }
            // 2) URL
            guard let url = URL(string: tcEndpointUrl) else {
                print("Invalid URL:", tcEndpointUrl)
                return nil
            }
            // 3) Payload
            let payload: [String: Any] = [
                "header": [
                    "state": [
                        "formatProperties": true,
                        "stateless": true,
                        "unloadObjects": false,
                        "enableServerStateHeaders": true,
                        "locale": "en_US"
                    ],
                    "policy": [
                        "types": [
                            [
                                "name": "RevisionRule",
                                "properties": [
                                    ["name": "object_name"]
                                ]
                            ]
                        ]
                    ]
                ]
            ]
            // 4) JSON encode
            let jsonData: Data
            do {
                jsonData = try JSONSerialization.data(withJSONObject: payload)
            } catch {
                print("Could not encode JSON:", error)
                return nil
            }
            // 5) Build request
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("JSESSIONID=\(session)", forHTTPHeaderField: "Cookie")
            request.httpBody = jsonData

            do {
                // 6) Send
                let (data, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse {
                    self.emitRaw(request.url!, http, data)
                    guard (200...299).contains(http.statusCode) else {
                        print("getRevisionRules failed. HTTP status =", http.statusCode)
                        return nil
                    }
                }
                // 7) Decode
                let decoder = JSONDecoder()
                let resp = try decoder.decode(GetRevisionRulesResponse.self, from: data)
                return resp.output
            } catch {
                print("Network or decode error in getRevisionRules:", error)
                return nil
            }
        }
    
    /// Create BOM windows for an item using given revision rule info
    public func createBOMWindows(
        tcEndpointUrl: String,
        itemUid: String,
        revRule: String,
        unitNo: Int,
        date: String,
        today: Bool,
        endItem: String,
        endItemRevision: String
    ) async -> (bomWindowUid: String?, bomLineUid: String?) {
        // 1) Check login
        guard let session = jsessionId else {
            print("No JSESSIONID—please login first.")
            return (nil, nil)
        }
        
        // 2) Build URL
        guard let url = URL(string: tcEndpointUrl) else {
            print("Invalid URL:", tcEndpointUrl)
            return (nil, nil)
        }
        
        // 3) Build payload
        let payload: [String: Any] = [
            "header": [
                "state": [
                    "formatProperties": true,
                    "stateless": true,
                    "unloadObjects": false,
                    "enableServerStateHeaders": true,
                    "locale": "en_US"
                ],
                "policy": [:]
            ],
            "body": [
                "info": [
                    [
                        "clientId": "",
                        "item": itemUid,
                        "revRuleConfigInfo": [
                            "clientId": "",
                            "revRule": revRule,
                            "props": [
                                "unitNo": unitNo,
                                "date": date,
                                "today": today,
                                "endItem": endItem,
                                "endItemRevision": endItemRevision
                            ]
                        ]
                    ]
                ]
            ]
        ]
        
        // 4) Serialize to JSON
        let jsonData: Data
        do {
            jsonData = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            print("JSON error for createBOMWindows:", error)
            return (nil, nil)
        }
        
        // 5) Build request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("JSESSIONID=\(session)", forHTTPHeaderField: "Cookie")
        request.httpBody = jsonData
        
        do {
            // 6) Send request
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                self.emitRaw(request.url!, http, data)
            }
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else {
                print("HTTP error in createBOMWindows:", response)
                return (nil, nil)
            }
            
            // 7) Decode response
            let decoder = JSONDecoder()
            let resp = try decoder.decode(CreateBOMWindowsResponse.self, from: data)
            
            // 8) Return first window and line UIDs
            if let first = resp.output?.first {
                let windowUid = first.bomWindow.uid
                let lineUid = first.bomLine.uid
                return (windowUid, lineUid)
            } else {
                print("No output in createBOMWindows response")
                return (nil, nil)
            }
            
        } catch {
            print("Network or decode error in createBOMWindows:", error)
            return (nil, nil)
        }
    }
    
    /// Add or update child BOM lines under a parent line
    public func addOrUpdateChildrenToParentLine(
        tcEndpointUrl: String,
        parentLine: String,
        createdItemRevUid: String
    ) async -> AddOrUpdateChildrenToParentLineResponse? {
        // 1) Ensure we’re logged in
        guard let session = self.jsessionId else {
            print("No JSESSIONID—please login first.")
            return nil
        }

        // 2) Build URL
        guard let url = URL(string: tcEndpointUrl) else {
            print("Invalid URL:", tcEndpointUrl)
            return nil
        }

        // 3) Build payload
        let payload: [String: Any] = [
            "header": [
                "state": [
                    "formatProperties": true,
                    "stateless": true,
                    "unloadObjects": false,
                    "enableServerStateHeaders": true,
                    "locale": "en_US"
                ],
                "policy": [:]
            ],
            "body": [
                "inputs": [
                    [
                        "parentLine": parentLine,
                        "viewType": "",
                        "items": [
                            [
                                "clientId": "",
                                "item": "",
                                "itemRev": createdItemRevUid,
                                "occType": "",
                                "bomline": "",
                                "itemLineProperties": [
                                    "SampleStringKey": ""
                                ]
                            ]
                        ],
                        "itemElements": []
                    ]
                ]
            ]
        ]

        // 4) Serialize payload
        let jsonData: Data
        do {
            jsonData = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            print("Failed to serialize JSON for addOrUpdateChildrenToParentLine:", error)
            return nil
        }

        // 5) Build and send request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("JSESSIONID=\(session)", forHTTPHeaderField: "Cookie")
        request.httpBody = jsonData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                self.emitRaw(request.url!, http, data)
            }
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else {
                print("HTTP error in addOrUpdateChildrenToParentLine:", response)
                return nil
            }

            // 6) Decode into our response type
            let decoder = JSONDecoder()
            let resp = try decoder.decode(AddOrUpdateChildrenToParentLineResponse.self, from: data)
            return resp

        } catch {
            print("Network or decode error in addOrUpdateChildrenToParentLine:", error)
            return nil
        }
    }

    /// Save one or more BOM windows on the server
    public func saveBOMWindows(
        tcEndpointUrl: String,
        bomWindows: [[String: Any]]
    ) async -> SaveBOMWindowsServiceData? {
        // 1) Check login
        guard let session = jsessionId else {
            print("No JSESSIONID—please login first.")
            return nil
        }
        // 2) Build URL
        guard let url = URL(string: tcEndpointUrl) else {
            print("Invalid URL:", tcEndpointUrl)
            return nil
        }
        // 3) Build payload
        let payload: [String: Any] = [
            "header": [
                "state": [
                    "formatProperties": true,
                    "stateless": true,
                    "unloadObjects": false,
                    "enableServerStateHeaders": true,
                    "locale": "en_US"
                ],
                "policy": [:]
            ],
            "body": [
                "bomWindows": bomWindows
            ]
        ]
        // 4) Serialize to JSON
        let jsonData: Data
        do {
            jsonData = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            print("JSON error for saveBOMWindows:", error)
            return nil
        }
        // 5) Build request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("JSESSIONID=\(session)", forHTTPHeaderField: "Cookie")
        request.httpBody = jsonData
        do {
            // 6) Send request
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                self.emitRaw(request.url!, http, data)
            }
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else {
                print("HTTP error in saveBOMWindows:", response)
                return nil
            }
            // 7) Decode response
            let decoder = JSONDecoder()
            let resp = try decoder.decode(SaveBOMWindowsResponse.self, from: data)
            // 8) Return the serviceData (contains updated UIDs and modelObjects)
            return resp.serviceData
        } catch {
            print("Network or decode error in saveBOMWindows:", error)
            return nil
        }
    }
    
    /// Close one or more BOM windows on the server
    public func closeBOMWindows(
        tcEndpointUrl: String
    ) async -> [String]? {
        // 1) Make sure we’re logged in
        guard let session = jsessionId else {
            print("No JSESSIONID—please login first.")
            return nil
        }
        // 2) Build the URL
        guard let url = URL(string: tcEndpointUrl) else {
            print("Invalid URL:", tcEndpointUrl)
            return nil
        }
        // 3) Build payload
        let payload: [String: Any] = [
            "header": [
                "state": [
                    "formatProperties": true,
                    "stateless": true,
                    "unloadObjects": false,
                    "enableServerStateHeaders": true,
                    "locale": "en_US"
                ],
                "policy": [:]
            ],
            "body": [
                "bomWindows": []
            ]
        ]
        // 4) Serialize to JSON
        let jsonData: Data
        do {
            jsonData = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            print("Failed to serialize JSON for closeBOMWindows:", error)
            return nil
        }
        // 5) Build request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("JSESSIONID=\(session)", forHTTPHeaderField: "Cookie")
        request.httpBody = jsonData
        
        do {
            // 6) Send request
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                self.emitRaw(request.url!, http, data)
            }
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else {
                print("HTTP error in closeBOMWindows:", response)
                return nil
            }
            // 7) Decode response
            let decoder = JSONDecoder()
            let resp = try decoder.decode(CloseBOMWindowsResponse.self, from: data)
            // 8) Return list of deleted UIDs
            return resp.serviceData.deleted
        } catch {
            print("Network or decode error in closeBOMWindows:", error)
            return nil
        }
    }
}

//
//  APIConfig.swift
//  TCSwiftBridge
//
//  Created by Sedoykin Alexey on 03/08/2025.
//

import Foundation

public struct APIConfig {

    public static func awcOpenDataPath(awcUrl: String) -> String {
        "\(awcUrl)/#/com.siemens.splm.clientfx.tcui.xrt.showObject?uid="
    }
    public static func tcLoginUrl(tcUrl: String) -> String {
        "\(tcUrl)/JsonRestServices/Core-2011-06-Session/login"
    }
    public static func tcSessionInfoUrl(tcUrl: String) -> String {
        "\(tcUrl)/JsonRestServices/Core-2007-01-Session/getTCSessionInfo"
    }
    public static func tcGetPropertiesUrl(tcUrl: String) -> String {
        "\(tcUrl)/JsonRestServices/Core-2006-03-DataManagement/getProperties"
    }
    public static func tcExpandFolder(tcUrl: String) -> String {
        "\(tcUrl)/JsonRestServices/Cad-2008-06-DataManagement/expandFoldersForCAD"
    }
    public static func tcCreateItem(tcUrl: String) -> String {
        "\(tcUrl)/JsonRestServices/Core-2006-03-DataManagement/createItems"
    }
    public static func tcCreateFolder(tcUrl: String) -> String {
        "\(tcUrl)/JsonRestServices/Core-2006-03-DataManagement/createFolders"
    }
    public static func getItemFromId(tcUrl: String) -> String {
        "\(tcUrl)/JsonRestServices/Core-2007-01-DataManagement/getItemFromId"
    }
    public static func tcGetSavedQueriesUrl(tcUrl: String) -> String {
           "\(tcUrl)/JsonRestServices/Query-2006-03-SavedQuery/getSavedQueries"
       }
    public static func createBOMWindows(tcUrl: String) -> String {
        "\(tcUrl)/JsonRestServices/Cad-2007-01-StructureManagement/createBOMWindows"
    }
    public static func addOrUpdateBOMLine(tcUrl: String) -> String {
        "\(tcUrl)/JsonRestServices/Bom-2008-06-StructureManagement/addOrUpdateChildrenToParentLine"
    }
    public static func saveBOMWindows(tcUrl: String) -> String {
        "\(tcUrl)/JsonRestServices/Cad-2008-06-StructureManagement/saveBOMWindows"
    }
    public static func closeBOMWindows(tcUrl: String) -> String {
        "\(tcUrl)/JsonRestServices/Cad-2007-01-StructureManagement/closeBOMWindows"
    }
}


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
    public static func tcGetSessionInfoUrl(tcUrl: String) -> String {
        "\(tcUrl)/JsonRestServices/Core-2007-01-Session/getTCSessionInfo"
    }
    public static func tcRefreshtPreferencesUrl(tcUrl: String) -> String {
        "\(tcUrl)/JsonRestServices/Administration-2011-05-PreferenceManagement/refreshPreferences"
    }
    public static func tcGetPreferencesUrl(tcUrl: String) -> String {
        "\(tcUrl)/JsonRestServices/Administration-2012-09-PreferenceManagement/getPreferences"
    }
    public static func tcGetPropertiesUrl(tcUrl: String) -> String {
        "\(tcUrl)/JsonRestServices/Core-2006-03-DataManagement/getProperties"
    }
    public static func tcExpandFolderUrl(tcUrl: String) -> String {
        "\(tcUrl)/JsonRestServices/Cad-2008-06-DataManagement/expandFoldersForCAD"
    }
    public static func tcCreateItemUrl(tcUrl: String) -> String {
        "\(tcUrl)/JsonRestServices/Core-2006-03-DataManagement/createItems"
    }
    public static func tcCreateFolderUrl(tcUrl: String) -> String {
        "\(tcUrl)/JsonRestServices/Core-2006-03-DataManagement/createFolders"
    }
    public static func tcCreateRelationUrl(tcUrl: String) -> String {
        "\(tcUrl)/JsonRestServices/Core-2006-03-DataManagement/createRelations"
    }
    public static func tcGetItemFromIdUrl(tcUrl: String) -> String {
        "\(tcUrl)/JsonRestServices/Core-2007-01-DataManagement/getItemFromId"
    }
    public static func tcGetRevisionRulesUrl(tcUrl: String) -> String {
        "\(tcUrl)/JsonRestServices/Cad-2007-01-StructureManagement/getRevisionRules"
    }
    public static func tcGetSavedQueriesUrl(tcUrl: String) -> String {
           "\(tcUrl)/JsonRestServices/Query-2006-03-SavedQuery/getSavedQueries"
    }
    public static func tcFindSavedQueriesUrl(tcUrl: String) -> String {
           "\(tcUrl)/JsonRestServices/Query-2010-04-SavedQuery/findSavedQueries"
    }
    public static func tcDescribeSavedQueriesUrl(tcUrl: String) -> String {
           "\(tcUrl)/JsonRestServices/Query-2006-03-SavedQuery/describeSavedQueries"
    }
    public static func tcCreateBOMWindowsUrl(tcUrl: String) -> String {
        "\(tcUrl)/JsonRestServices/Cad-2007-01-StructureManagement/createBOMWindows"
    }
    public static func tcAddOrUpdateBOMLineUrl(tcUrl: String) -> String {
        "\(tcUrl)/JsonRestServices/Bom-2008-06-StructureManagement/addOrUpdateChildrenToParentLine"
    }
    public static func tcSaveBOMWindowsUrl(tcUrl: String) -> String {
        "\(tcUrl)/JsonRestServices/Cad-2008-06-StructureManagement/saveBOMWindows"
    }
    public static func tcCloseBOMWindowsUrl(tcUrl: String) -> String {
        "\(tcUrl)/JsonRestServices/Cad-2007-01-StructureManagement/closeBOMWindows"
    }
}


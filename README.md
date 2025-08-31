### What is this?

This is a wrapper library around the Teamcenter REST API that lets you use some public Teamcenter methods in your Swift applications.
The library only includes what I use in my own projects: login, item creation, folder creation, retrieving saved queries, and so on.
The library will expand as my needs grow. Want more? Fork it or send a pull request to my GitHub.

For testing, use this app. It shows how to call methods from my library and displays raw responses from Teamcenter:
https://github.com/Krusty84/TCSwiftClientDebug

### Features
#### Release 1.2 (Implemented methods):

- `Administration-2011-05-PreferenceManagement/refreshPreferences`
- `Administration-2012-09-PreferenceManagement/getPreferences`
- `Core-2006-03-DataManagement/createRelations`
- `Cad-2007-01-StructureManagement/getRevisionRules`
- `Query-2010-04-SavedQuery/findSavedQueries`
- `Query-2006-03-SavedQuery/describeSavedQueries`

#### Release 1.0 (Implemented methods):

- `Core-2011-06-Session/login`  
- `Core-2007-01-Session/getTCSessionInfo`  
- `Core-2006-03-DataManagement/getProperties`  
- `Cad-2008-06-DataManagement/expandFoldersForCAD`  
- `Core-2006-03-DataManagement/createItems`  
- `Core-2006-03-DataManagement/createFolders`  
- `Core-2007-01-DataManagement/getItemFromId`  
- `Query-2006-03-SavedQuery/getSavedQueries`  
- `Cad-2007-01-StructureManagement/createBOMWindows`  
- `Bom-2008-06-StructureManagement/addOrUpdateChildrenToParentLine`  
- `Cad-2008-06-StructureManagement/saveBOMWindows`  
- `Cad-2007-01-StructureManagement/closeBOMWindows`  

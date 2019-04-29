////////////////////////////////////////////////////////////////////////////////
// Copyright 2016 Prominic.NET, Inc.
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
// http://www.apache.org/licenses/LICENSE-2.0 
// 
// Unless required by applicable law or agreed to in writing, software 
// distributed under the License is distributed on an "AS IS" BASIS, 
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and 
// limitations under the License
//
// Author: Prominic.NET, Inc. 
// No warranty of merchantability or fitness of any kind. 
// Use this software at your own risk.
////////////////////////////////////////////////////////////////////////////////
package actionScripts.utils
{
	import flash.display.DisplayObject;
	import flash.events.Event;
	import flash.net.SharedObject;
	
	import mx.collections.ArrayCollection;
	import mx.core.FlexGlobals;
	import mx.core.IFlexDisplayObject;
	import mx.events.CloseEvent;
	import mx.managers.PopUpManager;
	
	import actionScripts.events.AddTabEvent;
	import actionScripts.events.GlobalEventDispatcher;
	import actionScripts.factory.FileLocation;
	import actionScripts.locator.IDEModel;
	import actionScripts.plugin.settings.vo.ISetting;
	import actionScripts.plugin.settings.vo.StaticLabelSetting;
	import actionScripts.plugin.templating.settings.PathAccessSetting;
	import actionScripts.ui.IContentWindow;
	import actionScripts.ui.tabview.CloseTabEvent;
	import actionScripts.valueObjects.ConstantsCoreVO;
	import actionScripts.valueObjects.ProjectVO;
	
	import components.popup.DefineWorkspacePopup;

	public class OSXBookmarkerNotifiers
	{
		public static var workspaceLocation: FileLocation;
		public static var isWorkspaceAcknowledged: Boolean;
		public static var availableBookmarkedPaths: String = "";
		
		private static const ERROR_TYPE_UNACCESSIBLE:String = "ERROR_TYPE_UNACCESSIBLE";
		private static const ERROR_TYPE_NOT_EXISTS:String = "ERROR_TYPE_NOT_EXISTS";
		
		private static var workspacePopup: DefineWorkspacePopup;
		private static var accessManagerPopup: IFlexDisplayObject;
		
		public static function get availableBookmarkedPathsArr():Array
		{
			return (availableBookmarkedPaths ? availableBookmarkedPaths.split(",") : []);
		}
		
		public static function defineWorkspace():void
		{
			workspacePopup = PopUpManager.createPopUp(FlexGlobals.topLevelApplication as DisplayObject, DefineWorkspacePopup, false) as DefineWorkspacePopup;
			workspacePopup.addEventListener(CloseEvent.CLOSE, onWorkspaceClosed, false, 0, true);
			PopUpManager.centerPopUp(workspacePopup);
		}
		
		public static function checkAccessDependencies(projects:ArrayCollection, title:String="Access Manager", openByMenu:Boolean=false): Boolean
		{
			// probable termination for non-sandbox build
			if (!ConstantsCoreVO.IS_APP_STORE_VERSION) return true;
			
			// gets bookmark access
			var settings:Vector.<ISetting> = new Vector.<ISetting>();
			for each (var project:ProjectVO in projects)
			{
				var classSettings:Vector.<ISetting>;
				
				// check project's root path
				if (!isPathBookmarked(project.folderLocation.fileBridge.nativePath))
				{
					classSettings = new Vector.<ISetting>();
					classSettings.push(getNewPathSetting(ERROR_TYPE_UNACCESSIBLE, false, project.folderLocation, project.folderLocation.fileBridge.nativePath, project));
					
					var fileLabel:StaticLabelSetting = new StaticLabelSetting("Project Path", 14);
					classSettings.unshift(fileLabel);
					settings = settings.concat(classSettings);
				}
				
				// check property existence basis
				if (project.hasOwnProperty("classpaths"))
				{
					classSettings = getUnbookmarkedPaths(project, "classpaths", availableBookmarkedPathsArr, "Class Paths: "+ project.name);
					if (classSettings.length > 0) settings = settings.concat(classSettings);
				}
				if (project.hasOwnProperty("resourcePaths"))
				{
					classSettings = getUnbookmarkedPaths(project, "resourcePaths", availableBookmarkedPathsArr, "Resource Paths: "+ project.name);
					if (classSettings.length > 0) settings = settings.concat(classSettings);
				}
				if (project.hasOwnProperty("externalLibraries"))
				{
					classSettings = getUnbookmarkedPaths(project, "externalLibraries", availableBookmarkedPathsArr, "External Libraries: "+ project.name);
					if (classSettings.length > 0) settings = settings.concat(classSettings);
				}
				if (project.hasOwnProperty("libraries"))
				{
					classSettings = getUnbookmarkedPaths(project, "libraries", availableBookmarkedPathsArr, "Libraries: "+ project.name);
					if (classSettings.length > 0) settings = settings.concat(classSettings);
				}
				if (project.hasOwnProperty("nativeExtensions"))
				{
					classSettings = getUnbookmarkedPaths(project, "nativeExtensions", availableBookmarkedPathsArr, "Native Extensions: "+ project.name);
					if (classSettings.length > 0) settings = settings.concat(classSettings);
				}
			}
			
			// # Opening the access manager popup if requires
			// ====================================================
			if (settings.length > 0 || projects.length == 0 || openByMenu)
			{
				// Show About Panel in Tab
				var model: IDEModel = IDEModel.getInstance();
				for each (var tab:IContentWindow in model.editors)
				{
					if (tab == accessManagerPopup) 
					{
						tab["label"] = title;
						tab["requisitePaths"] = settings;
						model.activeEditor = tab;
						return false;
					}
				}
				
				if (!accessManagerPopup) 
				{
					accessManagerPopup = model.flexCore.getAccessManagerPopup();
					accessManagerPopup.addEventListener(CloseTabEvent.EVENT_TAB_CLOSED, onAccessManagerClosed, false, 0, true);
				}
				
				/*var classType: Class = IDEModel.getInstance().flexCore.getAccessManagerPopup();
				accessManagerPopup = PopUpManager.createPopUp(FlexGlobals.topLevelApplication as DisplayObject, Class(classType), false);
				accessManagerPopup.addEventListener(CloseEvent.CLOSE, onAccessManagerClosed, false, 0, true);*/
				accessManagerPopup["label"] = title;
				accessManagerPopup["requisitePaths"] = settings;
				//PopUpManager.centerPopUp(accessManagerPopup);
				
				GlobalEventDispatcher.getInstance().dispatchEvent(
					new AddTabEvent(accessManagerPopup as IContentWindow)
				);
				
				return false;
			}
			
			// this means all good no problem
			return true;
		}
		
		public static function isPathBookmarked(value:String):Boolean
		{
			// probable termination for non-sandbox build
			if (!ConstantsCoreVO.IS_APP_STORE_VERSION) return true;
			
			// sandbox application default directory
			if (value.indexOf("Library/Containers/com.moonshine-ide/Data/Documents") != -1) return true;
			
			var separator:String = IDEModel.getInstance().fileCore.separator;
			
			// # Resources that may needs access parse
			// ====================================================
			//availableBookmarkedPathsArr = (availableBookmarkedPaths) ? availableBookmarkedPaths.split(",") : [];
			if (availableBookmarkedPathsArr.length >= 1)
			{
				if (availableBookmarkedPathsArr[0] == "") availableBookmarkedPathsArr.shift(); // [0] will always blank
				else if (availableBookmarkedPathsArr[0] == "INITIALIZED") availableBookmarkedPathsArr.shift(); // very first time initialization after Moonshine installation
			}
			
			for each (var i:String in availableBookmarkedPathsArr)
			{
				if ((value.indexOf(i) != -1) ||
					(value.indexOf(i + separator) != -1)) return true;
			}
			
			return false;
		}
		
		public static function isValidLocalePath(file:FileLocation):String
		{
			var classPath:String = file.fileBridge.nativePath;
			if (classPath.indexOf("{locale}") != -1)
			{
				var tmpLocalePath:Array = classPath.split(file.fileBridge.separator);
				if (tmpLocalePath[tmpLocalePath.length - 1] == "{locale}")
				{
					tmpLocalePath.splice(tmpLocalePath.length - 1, 1);
					classPath = tmpLocalePath.join(file.fileBridge.separator);
					return classPath;
				}
			}
			
			// if invalid
			return null;
		}
		
		public static  function removeFlashCookies():void
		{
			var cookie:SharedObject = SharedObject.getLocal(SharedObjectConst.MOONSHINE_IDE_LOCAL);
			delete cookie.data["lastSelectedProjectPath"];
			delete cookie.data["recentProjectPath"];
			cookie.flush();

			IDEModel.getInstance().recentSaveProjectPath = new ArrayCollection();
		}
		
		private static function getUnbookmarkedPaths(provider:Object, className:String, bList:Array, title:String):Vector.<ISetting>
		{
			var settings:Vector.<ISetting> = new Vector.<ISetting>();
			var projectNativePath:String = ProjectVO(provider).folderLocation.fileBridge.nativePath;
			
			// check if project's varied file fields has access
			for each(var i:FileLocation in provider[className])
			{
				var classPath:String = i.fileBridge.nativePath;
				var isLocalePath:Boolean = false;
				
				// special case to treating {locale} attribute
				var tmpLocalCheckPath:String = isValidLocalePath(i);
				if (tmpLocalCheckPath != null)
				{
					isLocalePath = true;
					classPath = tmpLocalCheckPath;
				}
				
				// usual cases continues				
				var isFound:Boolean = false;
				var path:PathAccessSetting = null;
				if (classPath.indexOf(projectNativePath) != -1)
				{
					isFound = true;
				}
				else
				{
					for each(var j:String in bList)
					{
						if (classPath.indexOf(j) != -1)
						{
							isFound = true;
							break;
						}
					}
				}
				
				if (!isFound)
				{
					path = getNewPathSetting(ERROR_TYPE_UNACCESSIBLE, isLocalePath, i, (!isLocalePath ? classPath : i.fileBridge.nativePath), provider as ProjectVO);
					settings.push(path);
				}
				
				if (!i.fileBridge.exists)
				{
					// in case of {locale} case
					if (isLocalePath && (new FileLocation(classPath).fileBridge.exists)) break;
					
					if (path) path.errorType = "The dependency file/folder does not exist:\n"+ (!isLocalePath ? classPath : i.fileBridge.nativePath);
					else
					{
						settings.push(getNewPathSetting(ERROR_TYPE_NOT_EXISTS, isLocalePath, i, (!isLocalePath ? classPath : i.fileBridge.nativePath), provider as ProjectVO));
					}
				}
			}
			
			// do only if there are items in settings
			if (settings.length > 0)
			{
				var fileLabel:StaticLabelSetting = new StaticLabelSetting(title, 14);
				settings.unshift(fileLabel);
			}
			
			return settings;
		}
		
		private static function getNewPathSetting(errorType:String, isLocale:Boolean, fl:FileLocation, finalPath:String, project:ProjectVO):PathAccessSetting
		{
			var path:PathAccessSetting = new PathAccessSetting(fl);
			path.project = project;
			path.isLocalePath = isLocale;
			
			switch(errorType)
			{
				case ERROR_TYPE_UNACCESSIBLE:
					path.errorType = "Moonshine does not have access to:\n"+ finalPath;
					break;
				case ERROR_TYPE_NOT_EXISTS:
					path.errorType = "The dependency file/folder does not exist:\n"+ finalPath;
					break;
			}
			
			return path;
		}
		
		private static function onWorkspaceClosed(event:CloseEvent):void
		{
			workspacePopup.removeEventListener(CloseEvent.CLOSE, onWorkspaceClosed);
			workspacePopup = null;
		}
		
		private static function onAccessManagerClosed(event:Event):void
		{
			accessManagerPopup.removeEventListener(CloseTabEvent.EVENT_TAB_CLOSED, onAccessManagerClosed);
			accessManagerPopup = null;
		}
	}
}
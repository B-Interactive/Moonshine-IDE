package actionScripts.plugin.groovy.groovyproject
{
	import actionScripts.events.AddTabEvent;
	import actionScripts.events.GlobalEventDispatcher;
	import actionScripts.events.NewProjectEvent;
	import actionScripts.events.ProjectEvent;
	import actionScripts.events.RefreshTreeEvent;
	import actionScripts.factory.FileLocation;
	import actionScripts.locator.IDEModel;
	import actionScripts.plugin.groovy.groovyproject.importer.GrailsImporter;
	import actionScripts.plugin.groovy.groovyproject.vo.GrailsProjectVO;
	import actionScripts.plugin.settings.SettingsView;
	import actionScripts.plugin.settings.vo.AbstractSetting;
	import actionScripts.plugin.settings.vo.ISetting;
	import actionScripts.plugin.settings.vo.PathSetting;
	import actionScripts.plugin.settings.vo.SettingsWrapper;
	import actionScripts.plugin.settings.vo.StaticLabelSetting;
	import actionScripts.plugin.settings.vo.StringSetting;
	import actionScripts.plugin.templating.TemplatingHelper;
	import actionScripts.ui.tabview.CloseTabEvent;
	import actionScripts.utils.SharedObjectConst;

	import flash.display.DisplayObject;
	import flash.events.Event;
	import flash.filesystem.File;
	import flash.net.SharedObject;

	import mx.controls.Alert;
	import actionScripts.plugin.groovy.groovyproject.exporter.GrailsExporter;
	import mx.utils.ObjectUtil;
	import mx.collections.ArrayCollection;

	public class CreateGrailsProject
	{
		public function CreateGrailsProject(event:NewProjectEvent)
		{
			createGrailsProject(event);
		}

		private var project:GrailsProjectVO;
		private var newProjectNameSetting:StringSetting;
		private var newProjectPathSetting:PathSetting;
		private var isInvalidToSave:Boolean;
		private var cookie:SharedObject;
		private var templateLookup:Object = {};

		private var model:IDEModel = IDEModel.getInstance();
		private var dispatcher:GlobalEventDispatcher = GlobalEventDispatcher.getInstance();

		private var _currentCauseToBeInvalid:String;

		private function createGrailsProject(event:NewProjectEvent):void
		{
			var lastSelectedProjectPath:String;
			
			CONFIG::OSX
			{
				if (OSXBookmarkerNotifiers.availableBookmarkedPaths == "") OSXBookmarkerNotifiers.removeFlashCookies();
			}
			
            cookie = SharedObject.getLocal(SharedObjectConst.MOONSHINE_IDE_LOCAL);
			if (cookie.data.hasOwnProperty('recentProjectPath'))
			{
				model.recentSaveProjectPath.source = cookie.data.recentProjectPath;
				if (cookie.data.hasOwnProperty('lastSelectedProjectPath')) lastSelectedProjectPath = cookie.data.lastSelectedProjectPath;
			}

			var tmpProjectSourcePath:String = (lastSelectedProjectPath && model.recentSaveProjectPath.getItemIndex(lastSelectedProjectPath) != -1) ? lastSelectedProjectPath : model.recentSaveProjectPath.source[model.recentSaveProjectPath.length - 1];
			var folderLocation:FileLocation = new FileLocation(tmpProjectSourcePath);

			// Remove spaces from project name
			var projectName:String = (event.templateDir.fileBridge.name.indexOf("(") != -1) ? event.templateDir.fileBridge.name.substr(0, event.templateDir.fileBridge.name.indexOf("(")) : event.templateDir.fileBridge.name;
			projectName = "New" + projectName.replace(/ /g, "");

			project = new GrailsProjectVO(folderLocation, projectName);

			var settingsView:SettingsView = new SettingsView();
			settingsView.exportProject = event.exportProject;
			settingsView.Width = 150;
			settingsView.defaultSaveLabel = event.isExport ? "Export" : "Create";
			settingsView.isNewProjectSettings = true;
			
			settingsView.addCategory("");

			var settings:SettingsWrapper = getProjectSettings(project, event);

			settingsView.addEventListener(SettingsView.EVENT_SAVE, createSave);
			settingsView.addEventListener(SettingsView.EVENT_CLOSE, createClose);
			settingsView.addSetting(settings, "");
			
			settingsView.label = "New Project";
			settingsView.associatedData = project;
			
			dispatcher.dispatchEvent(new AddTabEvent(settingsView));
			
			templateLookup[project] = event.templateDir;
		}

		private function getProjectSettings(project:GrailsProjectVO, eventObject:NewProjectEvent):SettingsWrapper
		{
			var historyPaths:ArrayCollection = ObjectUtil.copy(model.recentSaveProjectPath) as ArrayCollection;
			if (historyPaths.length == 0)
			{
				historyPaths.addItem(project.folderPath);
			}

            newProjectNameSetting = new StringSetting(project, 'projectName', 'Project name', '^ ~`!@#$%\\^&*()\\-+=[{]}\\\\|:;\'",<.>/?');
			newProjectPathSetting = new PathSetting(project, 'folderPath', 'Parent directory', true, null, false, true);
			newProjectPathSetting.dropdownListItems = historyPaths;
			newProjectPathSetting.addEventListener(AbstractSetting.PATH_SELECTED, onProjectPathChanged);
			newProjectNameSetting.addEventListener(StringSetting.VALUE_UPDATED, onProjectNameChanged);

			if (eventObject.isExport)
			{
				//newProjectNameSetting.isEditable = false;
                return new SettingsWrapper("Name & Location", Vector.<ISetting>([
                    new StaticLabelSetting('New ' + eventObject.templateDir.fileBridge.name),
                    newProjectNameSetting, // No space input either plx
                    newProjectPathSetting
                ]));
			}

            return new SettingsWrapper("Name & Location", Vector.<ISetting>([
				new StaticLabelSetting('New '+ eventObject.templateDir.fileBridge.name),
				newProjectNameSetting, // No space input either plx
				newProjectPathSetting,
			]));
		}
		
		private function checkIfProjectDirectory(value:FileLocation):void
		{
			var tmpFile:FileLocation = GrailsImporter.test(value.fileBridge.getFile);
			if (!tmpFile && value.fileBridge.exists)
			{
				tmpFile = value;
			}
			
			if (tmpFile) 
			{
				newProjectPathSetting.setMessage((_currentCauseToBeInvalid = "Project can not be created to an existing project directory:\n"+ value.fileBridge.nativePath), AbstractSetting.MESSAGE_CRITICAL);
			}
			else
			{
				newProjectPathSetting.setMessage(value.fileBridge.nativePath);
			}
			
			if (newProjectPathSetting.stringValue == "") 
			{
				isInvalidToSave = true;
				_currentCauseToBeInvalid = 'Unable to access Project Directory:\n'+ value.fileBridge.nativePath +'\nPlease try to create the project again and use the "Change" link to open the target directory again.';
			}
			else
			{
				isInvalidToSave = tmpFile ? true : false;
			}
		}
		
		private function onProjectPathChanged(event:Event, makeNull:Boolean=true):void
		{
			if (makeNull) project.projectFolder = null;
			project.folderLocation = new FileLocation(newProjectPathSetting.stringValue);
			newProjectPathSetting.label = "Parent Directory";
			checkIfProjectDirectory(project.folderLocation.resolvePath(newProjectNameSetting.stringValue));
		}
		
		private function onProjectNameChanged(event:Event):void
		{
			checkIfProjectDirectory(project.folderLocation.resolvePath(newProjectNameSetting.stringValue));
		}
		
		private function createClose(event:Event):void
		{
			var settings:SettingsView = event.target as SettingsView;
			
			settings.removeEventListener(SettingsView.EVENT_CLOSE, createClose);
			settings.removeEventListener(SettingsView.EVENT_SAVE, createSave);
			if (newProjectPathSetting) 
			{
				newProjectPathSetting.removeEventListener(AbstractSetting.PATH_SELECTED, onProjectPathChanged);
				newProjectNameSetting.removeEventListener(StringSetting.VALUE_UPDATED, onProjectNameChanged);
			}
			
			delete templateLookup[settings.associatedData];
			
			dispatcher.dispatchEvent(
				new CloseTabEvent(CloseTabEvent.EVENT_CLOSE_TAB, event.target as DisplayObject)
			);
		}
		
		private function createSave(event:Event):void
		{
			if (isInvalidToSave) 
			{
				throwError();
				return;
			}
			
			var view:SettingsView = event.target as SettingsView;
			var project:GrailsProjectVO = view.associatedData as GrailsProjectVO;
			var targetFolder:FileLocation = project.folderLocation;

			//save project path in shared object
			cookie = SharedObject.getLocal(SharedObjectConst.MOONSHINE_IDE_LOCAL);
			var tmpParent:FileLocation = project.folderLocation;

			if (!model.recentSaveProjectPath.contains(tmpParent.fileBridge.nativePath))
			{
				model.recentSaveProjectPath.addItem(tmpParent.fileBridge.nativePath);
            }
			
			cookie.data["lastSelectedProjectPath"] = project.folderLocation.fileBridge.nativePath;
			cookie.data["recentProjectPath"] = model.recentSaveProjectPath.source;
			cookie.flush();

            project = createFileSystemBeforeSave(project, view.exportProject as GrailsProjectVO);
			if (!project) return;

            targetFolder = targetFolder.resolvePath(project.projectName);
			
			// Close settings view
			createClose(event);
			
			// Open main file for editing
			dispatcher.dispatchEvent(
				new ProjectEvent(ProjectEvent.ADD_PROJECT, project)
			);
			
			/*dispatcher.dispatchEvent( 
				new OpenFileEvent(OpenFileEvent.OPEN_FILE, project.targets[0], -1, project.projectFolder)
			);*/

			if (view.exportProject)
			{
                dispatcher.dispatchEvent(new RefreshTreeEvent(project.folderLocation));
			}
		}
		
		private function throwError():void
		{
			Alert.show(_currentCauseToBeInvalid +" Project creation terminated.", "Error!");
			//dispatcher.dispatchEvent(new ConsoleOutputEvent(ConsoleOutputEvent.CONSOLE_PRINT, _currentCauseToBeInvalid +"\nProject creation terminated.", false, false, ConsoleOutputEvent.TYPE_ERROR));
		}

		private function createFileSystemBeforeSave(pvo:GrailsProjectVO, exportProject:GrailsProjectVO = null):GrailsProjectVO
		{	
			var templateDir:FileLocation = templateLookup[pvo];
			var projectName:String = pvo.projectName;
			var sourceFile:String = pvo.projectName;
			var sourceFileWithExtension:String = pvo.projectName + ".groovy";
			var sourcePath:String = "src" + File.separator + "main" + File.separator + "groovy";

			var targetFolder:FileLocation = pvo.folderLocation;
			
			// Create project root directory
			CONFIG::OSX
				{
					if (!OSXBookmarkerNotifiers.isPathBookmarked(targetFolder.fileBridge.nativePath))
					{
						_currentCauseToBeInvalid = 'Unable to access Parent Directory:\n'+ targetFolder.fileBridge.nativePath +'\nPlease try to create the project again and use the "Change" link to open the target directory again.';
						throwError();
						return null;
					}
				}
			
			targetFolder = targetFolder.resolvePath(projectName);
			targetFolder.fileBridge.createDirectory();
			
			// Time to do the templating thing!
			var th:TemplatingHelper = new TemplatingHelper();
			th.isProjectFromExistingSource = false;
			th.templatingData["$ProjectName"] = projectName;
			
			var pattern:RegExp = new RegExp(/(_)/g);
			th.templatingData["$ProjectID"] = projectName.replace(pattern, "");
			th.templatingData["$Settings"] = projectName;
			th.templatingData["$SourcePath"] = sourcePath;
			th.templatingData["$SourceFile"] = sourceFileWithExtension ? (sourcePath + File.separator + sourceFileWithExtension) : "";

            th.projectTemplate(templateDir, targetFolder);

			var projectSettingsFileName:String = projectName + ".grailsproj";
			var settingsFile:FileLocation = targetFolder.resolvePath(projectSettingsFileName);
			pvo = GrailsImporter.parse(settingsFile, projectName);

			GrailsExporter.export(pvo);

			return pvo;
		}
	}
}
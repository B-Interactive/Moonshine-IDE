////////////////////////////////////////////////////////////////////////////////
//
//  Copyright (C) STARTcloud, Inc. 2015-2022. All rights reserved.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the Server Side Public License, version 1,
//  as published by MongoDB, Inc.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
//  Server Side Public License for more details.
//
//  You should have received a copy of the Server Side Public License
//  along with this program. If not, see
//
//  http://www.mongodb.com/licensing/server-side-public-license
//
//  As a special exception, the copyright holders give permission to link the
//  code of portions of this program with the OpenSSL library under certain
//  conditions as described in each individual source file and distribute
//  linked combinations including the program with the OpenSSL library. You
//  must comply with the Server Side Public License in all respects for
//  all of the code used other than as permitted herein. If you modify file(s)
//  with this exception, you may extend this exception to your version of the
//  file(s), but you are not obligated to do so. If you do not wish to do so,
//  delete this exception statement from your version. If you delete this
//  exception statement from all source files in the program, then also delete
//  it in the license file.
//
////////////////////////////////////////////////////////////////////////////////
package actionScripts.plugin.templating
{
	import actionScripts.events.SettingsEvent;
	import actionScripts.plugin.settings.vo.MultiOptionSetting;
	import actionScripts.plugin.settings.vo.NameValuePair;

	import flash.display.DisplayObject;
	import flash.events.Event;
	import flash.utils.setTimeout;
	
	import mx.collections.ArrayCollection;
	import mx.controls.Alert;
	import mx.core.FlexGlobals;
	import mx.events.CloseEvent;
	import mx.managers.PopUpManager;
	import mx.resources.ResourceManager;
	import mx.utils.StringUtil;
	
	import __AS3__.vec.Vector;
	
	import actionScripts.events.ASModulesEvent;
	import actionScripts.events.AddTabEvent;
	import actionScripts.events.EditorPluginEvent;
	import actionScripts.events.ExportVisualEditorProjectEvent;
	import actionScripts.events.GeneralEvent;
	import actionScripts.events.GlobalEventDispatcher;
	import actionScripts.events.NewFileEvent;
	import actionScripts.events.NewProjectEvent;
	import actionScripts.events.OpenFileEvent;
	import actionScripts.events.ProjectEvent;
	import actionScripts.events.RenameApplicationEvent;
	import actionScripts.events.TemplatingEvent;
	import actionScripts.events.TreeMenuItemEvent;
	import actionScripts.factory.FileLocation;
	import actionScripts.plugin.IMenuPlugin;
	import actionScripts.plugin.PluginBase;
	import actionScripts.plugin.actionscript.as3project.vo.AS3ProjectVO;
	import actionScripts.plugin.settings.ISettingsProvider;
	import actionScripts.plugin.settings.vo.ISetting;
	import actionScripts.plugin.settings.vo.StaticLabelSetting;
	import actionScripts.plugin.templating.event.TemplateEvent;
	import actionScripts.plugin.templating.settings.NewTemplateSetting;
	import actionScripts.plugin.templating.settings.TemplateSetting;
	import actionScripts.plugin.templating.settings.renderer.NewTemplateRenderer;
	import actionScripts.plugin.templating.settings.renderer.TemplateRenderer;
	import actionScripts.ui.IContentWindow;
	import actionScripts.ui.editor.BasicTextEditor;
	import actionScripts.ui.menu.vo.MenuItem;
	import actionScripts.ui.menu.vo.ProjectMenuTypes;
	import actionScripts.ui.renderers.FTETreeItemRenderer;
	import actionScripts.ui.tabview.CloseTabEvent;
	import actionScripts.utils.SerializeUtil;
	import actionScripts.utils.TextUtil;
	import actionScripts.utils.UtilsCore;
	import actionScripts.valueObjects.AS3ClassAttributes;
	import actionScripts.valueObjects.ConstantsCoreVO;
	import actionScripts.valueObjects.FileWrapper;
	import actionScripts.valueObjects.ProjectVO;
	import actionScripts.valueObjects.TemplateVO;
	
	import components.popup.newFile.NewASFilePopup;
	import components.popup.newFile.NewCSSFilePopup;
	import components.popup.newFile.NewDominoFormPopup;
	import components.popup.newFile.NewDominoPagePopup;
	import components.popup.newFile.NewDominoSubFormPopup;
	import components.popup.newFile.NewDominoViewPopup;
	import components.popup.newFile.NewDominoViewShareColumnPopup;
	import components.popup.newFile.NewDominoShareFieldPopup;
	import components.popup.newFile.NewDominoActionPopup;

	import components.popup.newFile.NewFilePopup;
	import components.popup.newFile.NewGroovyFilePopup;
	import components.popup.newFile.NewHaxeFilePopup;
	import components.popup.newFile.NewJavaFilePopup;
	import components.popup.newFile.NewMXMLFilePopup;
	import components.popup.newFile.NewMXMLGenericFilePopup;
	import components.popup.newFile.NewVisualEditorFilePopup;
	import components.popup.newFile.NewOnDiskFilePopup;

	import actionScripts.interfaces.IVisualEditorProjectVO;
	import actionScripts.plugin.ondiskproj.OnDiskProjectPlugin;
	import actionScripts.utils.TextUtil;
    /*
    Templating plugin

    Provides templates & possibility to customize them

    Standard templates ship in the app-dir, but since we can't change those files once installed
    we override them by copying them to app-storage-dir & let the user modify them there.
    */
	
	public class TemplatingPlugin extends PluginBase implements ISettingsProvider,IMenuPlugin
	{
		protected static const CATEGORY_PROJECTS:String = "categoryProjects";
		protected static const CATEGORY_FILES:String = "categoryFiles";

		override public function get name():String 			{return "Templating";}
		override public function get author():String 		{return ConstantsCoreVO.MOONSHINE_IDE_LABEL +" Project Team";}
		override public function get description():String 	{return ResourceManager.getInstance().getString('resources','plugin.desc.templating');}
		
		public static var fileTemplates:Array = [];
		public static var projectTemplates:Array = [];

		public var categoryType:String = CATEGORY_PROJECTS;
		
		protected var templatesDir:FileLocation;
		protected var customTemplatesDir:FileLocation;
		
		protected var settingsList:Vector.<ISetting>;
		protected var newFileTemplateSetting:NewTemplateSetting;
		protected var newProjectTemplateSetting:NewTemplateSetting;
		protected var newMXMLComponentPopup:NewMXMLFilePopup;
		protected var newAS3ComponentPopup:NewASFilePopup;
		protected var newJavaComponentPopup:NewJavaFilePopup;
		protected var newGroovyComponentPopup:NewGroovyFilePopup;
		protected var newHaxeComponentPopup:NewHaxeFilePopup;
		protected var newCSSComponentPopup:NewCSSFilePopup;
		protected var newDominoFormComponentPopup:NewDominoFormPopup;
		protected var newDominoPageComponentPopup:NewDominoPagePopup;
		protected var newDominoSubformComponentPopup:NewDominoSubFormPopup;
		protected var newDominoViewComponentPopup:NewDominoViewPopup
		protected var newDominoViewShareColumnPopup:NewDominoViewShareColumnPopup
		protected var newDominoSharedFieldComponentPopup:NewDominoShareFieldPopup;
		protected var newDominoActionComponentPopup:NewDominoActionPopup;
		protected var newMXMLModuleComponentPopup:NewMXMLGenericFilePopup;
		protected var newVisualEditorFilePopup:NewVisualEditorFilePopup;
		protected var newOnDiskFilePopup:NewOnDiskFilePopup;
		protected var newFilePopup:NewFilePopup;
		
		
		private var resetIndex:int = -1;

		private var templateConfigs:Array;
		private var allLoadedTemplates:Array;
		private var settings:Vector.<ISetting>;

		private var templateHaxeClass:FileLocation;
		private var templateHaxeInterface:FileLocation;

		private var templateJavaClass:FileLocation;
		private var templateJavaInterface:FileLocation;

		private var templateGroovyClass:FileLocation;
		private var templateGroovyInterface:FileLocation;

		public function TemplatingPlugin()
		{
			super();
			
			if (ConstantsCoreVO.IS_AIR)
			{
				templatesDir = model.fileCore.resolveApplicationDirectoryPath("elements".concat(model.fileCore.separator, "templates"));
				customTemplatesDir = model.fileCore.resolveApplicationStorageDirectoryPath("templates");
				readTemplates();
			}
		}
		
		override public function activate():void
		{
			super.activate();

			dispatcher.addEventListener(TemplateEvent.CREATE_NEW_FILE, handleCreateFileTemplate);
			
			// For web Moonshine, we won't depend on getMenu()
			// getMenu() exclusively calls for desktop Moonshine
			if (!ConstantsCoreVO.IS_AIR)
			{
				for each (var m:FileLocation in ConstantsCoreVO.TEMPLATES_FILES)
				{
					var fileName:String = m.fileBridge.name.substring(0,m.fileBridge.name.lastIndexOf("."));
					dispatcher.addEventListener(fileName, handleNewTemplateFile);
				}
				
				for each (var project:FileLocation in ConstantsCoreVO.TEMPLATES_PROJECTS)
				{
					dispatcher.addEventListener(project.fileBridge.name, handleNewProjectFile);
				}
			}
			else
			{
	            dispatcher.addEventListener(ExportVisualEditorProjectEvent.EVENT_EXPORT_VISUALEDITOR_PROJECT_TO_FLEX, handleExportNewProjectFromTemplate);
				dispatcher.addEventListener(NewFileEvent.EVENT_NEW_VISUAL_EDITOR_FILE, onVisualEditorFileCreateRequest, false, 0, true);
				dispatcher.addEventListener(NewFileEvent.EVENT_FILE_CREATED, onNewFileBeingCreated, false, 0, true);
			}
		}
		
		override public function resetSettings():void
		{
			resetIndex = 0;
			for (resetIndex; resetIndex < settingsList.length; resetIndex++)
			{
				if (settingsList[resetIndex] is TemplateSetting) 
				{
					TemplateSetting(settingsList[resetIndex]).resetTemplate();
				}
			}
			
			readTemplates();
		}
		
		public static function checkAndUpdateIfTemplateModified(event:NewFileEvent):void
		{
			var modifiedTemplate:FileLocation = TemplatingHelper.getCustomFileFor(event.fromTemplate);
			if (modifiedTemplate.fileBridge.exists) event.fromTemplate = modifiedTemplate;
		}
		
		protected function readTemplates():void
		{
			fileTemplates = [];
			projectTemplates = [];
			
			// Find default templates
			var files:FileLocation = templatesDir.resolvePath("files");
			var list:Array = files.fileBridge.getDirectoryListing();
			for each (var file:Object in list)
			{
				if (!file.isHidden && !file.isDirectory)
					fileTemplates.push(new FileLocation(file.nativePath));
			}
			
			files = templatesDir.resolvePath("files/mxml/flex");
			list = files.fileBridge.getDirectoryListing();
			for each (file in list)
			{
				if (!file.isHidden && !file.isDirectory)
					ConstantsCoreVO.TEMPLATES_MXML_COMPONENTS.addItem(file);
			}

            files = templatesDir.resolvePath("files/visualeditor/flex");
            list = files.fileBridge.getDirectoryListing();
            for each (file in list)
            {
                if (!file.isHidden && !file.isDirectory)
                    ConstantsCoreVO.TEMPLATES_VISUALEDITOR_FILES_FLEX.addItem(file);
            }
			//domino template ,need copy folder
			files = templatesDir.resolvePath("files/visualeditor/domino/nsfs/nsf-moonshine/odp/Forms/");
			ConstantsCoreVO.TEMPLATES_VISUALEDITOR_FILES_DOMINO.addItem(files);
			list = files.fileBridge.getDirectoryListing();
			for each (file in list)
            {
                if (!file.isHidden && !file.isDirectory)
                    ConstantsCoreVO.TEMPLATES_VISUALEDITOR_FILES_DOMINO.addItem(file);
            }


			files = templatesDir.resolvePath("files/visualeditor/domino/nsfs/nsf-moonshine/odp/Forms/DominoVisualEditorExample.form");
			if (!files.fileBridge.isHidden && !files.fileBridge.isDirectory)
				ConstantsCoreVO.TEMPLATES_VISUALEDITOR_FILES_DOMINO_FORM = files;

            files = templatesDir.resolvePath("files/visualeditor/primeFaces");
            list = files.fileBridge.getDirectoryListing();
            for each (file in list)
            {
                if (!file.isHidden && !file.isDirectory)
                    ConstantsCoreVO.TEMPLATES_VISUALEDITOR_FILES_PRIMEFACES.addItem(file);
            }
			
			files = templatesDir.resolvePath("files/MXML Module.mxml.template");
			if (!files.fileBridge.isHidden && !files.fileBridge.isDirectory)
				ConstantsCoreVO.TEMPLATE_MXML_MODULE = files;

			files = templatesDir.resolvePath("files/AS3 Class.as.template");
			if (!files.fileBridge.isHidden && !files.fileBridge.isDirectory)
				ConstantsCoreVO.TEMPLATE_AS3CLASS = files;
			
			files = templatesDir.resolvePath("files/AS3 Interface.as.template");
			if (!files.fileBridge.isHidden && !files.fileBridge.isDirectory)
				ConstantsCoreVO.TEMPLATE_AS3INTERFACE = files;
			
			files = templatesDir.resolvePath("files/CSS File.css.template");
			if (!files.fileBridge.isHidden && !files.fileBridge.isDirectory)
				ConstantsCoreVO.TEMPLATE_CSS = files;
			
			files = templatesDir.resolvePath("files/XML File.xml.template");
			if (!files.fileBridge.isHidden && !files.fileBridge.isDirectory)
				ConstantsCoreVO.TEMPLATE_XML = files;
			
			files = templatesDir.resolvePath("files/File.txt.template");
			if (!files.fileBridge.isHidden && !files.fileBridge.isDirectory)
				ConstantsCoreVO.TEMPLATE_TEXT = files;
			
			files = templatesDir.resolvePath("files/Java Class.java.template");
			if (!files.fileBridge.isHidden && !files.fileBridge.isDirectory)
				templateJavaClass = files;
			
			files = templatesDir.resolvePath("files/Java Interface.java.template");
			if (!files.fileBridge.isHidden && !files.fileBridge.isDirectory)
				templateJavaInterface = files;
			
			files = templatesDir.resolvePath("files/Groovy Class.groovy.template");
			if (!files.fileBridge.isHidden && !files.fileBridge.isDirectory)
				templateGroovyClass = files;
			
			files = templatesDir.resolvePath("files/Groovy Interface.groovy.template");
			if (!files.fileBridge.isHidden && !files.fileBridge.isDirectory)
				templateGroovyInterface = files;
			
			files = templatesDir.resolvePath("files/Haxe Class.hx.template");
			if (!files.fileBridge.isHidden && !files.fileBridge.isDirectory)
				templateHaxeClass = files;
			
			files = templatesDir.resolvePath("files/Haxe Interface.hx.template");
			if (!files.fileBridge.isHidden && !files.fileBridge.isDirectory)
				templateHaxeInterface = files;
			
			files = templatesDir.resolvePath("files/Domino Visual Editor Form.form.template");
			if (!files.fileBridge.isHidden && !files.fileBridge.isDirectory)
				ConstantsCoreVO.TEMPLATE_DOMINO_FORM = files;

			files = templatesDir.resolvePath("files/Domino Visual Editor Page.page.template");
			if (!files.fileBridge.isHidden && !files.fileBridge.isDirectory)
				ConstantsCoreVO.TEMPLATE_DOMINO_PAGE = files;
			
			files = templatesDir.resolvePath("files/Domino Visual Editor Subform.subform.template");
			if (!files.fileBridge.isHidden && !files.fileBridge.isDirectory)
				ConstantsCoreVO.TEMPLATE_DOMINO_SUBFORM = files;


			files = templatesDir.resolvePath("files/Domino Visual Share Field.field.template");
			if (!files.fileBridge.isHidden && !files.fileBridge.isDirectory)
				ConstantsCoreVO.TEMPLATE_DOMINO_SHAREDFIELD = files;

			files = templatesDir.resolvePath("files/Domino Visual Editor Action.action.template");
			if (!files.fileBridge.isHidden && !files.fileBridge.isDirectory)
				ConstantsCoreVO.TEMPLATE_DOMINO_ACTION = files;	
			// Just to generate a divider in relevant UI
			//ConstantsCoreVO.TEMPLATES_MXML_COMPONENTS.addItem("NOTHING");


			files = templatesDir.resolvePath("files/Domino Visual Editor View.view.template");
			if (!files.fileBridge.isHidden && !files.fileBridge.isDirectory)
				ConstantsCoreVO.TEMPLATE_DOMINO_VIEW = files;

			files = templatesDir.resolvePath("files/Domino Visual Editor View Shared Column.column.template");
			if (!files.fileBridge.isHidden && !files.fileBridge.isDirectory)
				ConstantsCoreVO.TEMPLATE_DOMINO_VIEW_SHARE_COLUMN = files;	
			
			files = templatesDir.resolvePath("files/mxml/flexjs");
			list = files.fileBridge.getDirectoryListing();
			for each (file in list)
			{
				if (!file.isHidden && !file.isDirectory)
					ConstantsCoreVO.TEMPLATES_MXML_FLEXJS_COMPONENTS.addItem(file);
			}

            files = templatesDir.resolvePath("files/mxml/royale");
            list = files.fileBridge.getDirectoryListing();
            for each (file in list)
            {
                if (!file.isHidden && !file.isDirectory)
                    ConstantsCoreVO.TEMPLATES_MXML_ROYALE_COMPONENTS.addItem(file);
            }
			
			files = templatesDir.resolvePath("files/Visual Editor DXL File.dve.template");
			if (!files.fileBridge.isHidden && !files.fileBridge.isDirectory)
				ConstantsCoreVO.TEMPLATE_ODP_VISUALEDITOR_FILE = files;
			
			files = templatesDir.resolvePath("files/Form Builder DXL File.dfb.template");
			if (!files.fileBridge.isHidden && !files.fileBridge.isDirectory)
				ConstantsCoreVO.TEMPLATE_ODP_FORMBUILDER_FILE = files;

			var projects:FileLocation = templatesDir.resolvePath("projects");
			list = projects.fileBridge.getDirectoryListing();
			list = list.filter(function(item:Object, index:int, arr:Array):Boolean {
				return item.extension == "xml";
			});

			templateConfigs = [];

			for each (file in list)
			{
				if (!file.isHidden)
				{
					//Alert.show("template:"+file.nativePath);
					var projectTemplateConfigLocation:FileLocation = new FileLocation(file.nativePath);
					var projectTemplateConfig:XML = new XML(projectTemplateConfigLocation.fileBridge.read());
					var projectTemplateConfigs:XMLList = projectTemplateConfig.template;

					for each (var template:XML in projectTemplateConfigs)
					{
						var templateName:String = String(template.name);
						projectTemplates.push(projects.resolvePath(templateName));
						templateConfigs.push(template);
					}
				}
			}
			
			// Find user-added custom templates
			if (!customTemplatesDir.fileBridge.exists) customTemplatesDir.fileBridge.createDirectory();
			
			files = customTemplatesDir.resolvePath("files");
			if (!files.fileBridge.exists) files.fileBridge.createDirectory();
			var fileList:Array = files.fileBridge.getDirectoryListing();
			
			for each (file in fileList)
			{
				if (TemplatingHelper.getOriginalFileForCustom(new FileLocation(file.nativePath)).fileBridge.exists == false
					&& !file.isHidden)
				{
					fileTemplates.push(new FileLocation(file.nativePath));
				}
			}
			
			// sort when done
			fileTemplates.sortOn("name", Array.CASEINSENSITIVE);
			
			projects = customTemplatesDir.resolvePath("projects");
			if (!projects.fileBridge.exists) projects.fileBridge.createDirectory();
			var projectList:Array = projects.fileBridge.getDirectoryListing();
			
			for each (file in projectList)
			{
				if (TemplatingHelper.getOriginalFileForCustom(new FileLocation(file.nativePath)).fileBridge.exists == false
					&& !file.isHidden && file.isDirectory)
				{
					projectTemplates.push(new FileLocation(file.nativePath));
				}
			}

			generateTemplateProjects();
		}

        private function generateTemplateProjects():void
        {
            var projectTemplateCollection:ArrayCollection = new ArrayCollection();
			var actionScriptProjectTemplates:ArrayCollection = new ArrayCollection();
            var feathersProjectTemplates:ArrayCollection = new ArrayCollection();
			var royaleProjectTemplates:ArrayCollection = new ArrayCollection();
			var royaleVisualProjectTemplates:ArrayCollection = new ArrayCollection();
			var royaleDominoExportTemplates:ArrayCollection = new ArrayCollection();
			var javaProjectTemplates:ArrayCollection = new ArrayCollection();
			var grailsProjectTemplates:ArrayCollection = new ArrayCollection();
			var haxeProjectTemplates:ArrayCollection = new ArrayCollection();

			allLoadedTemplates = [];
            for each (var templateConfig:XML in templateConfigs)
            {
				var templateName:String = SerializeUtil.deserializeString(templateConfig.name);

				var projectsLocation:FileLocation = templatesDir.resolvePath("projects" + templatesDir.fileBridge.separator + templateName);
                if (projectsLocation.fileBridge.exists)
                {
                    var template:TemplateVO = new TemplateVO();
                    template.title = SerializeUtil.deserializeString(templateConfig.title);
					template.homeTitle = SerializeUtil.deserializeString(templateConfig.homeTitle);
					template.displayHome = SerializeUtil.deserializeBoolean(templateConfig.@displayHome);
                    template.file = projectsLocation;
                    template.description = String(templateConfig.description);

					var iconsLocation:FileLocation = projectsLocation.fileBridge.parent.resolvePath("icons");
					var iconFile:Object = iconsLocation.fileBridge.getFile.resolvePath(String(templateConfig.icon));
                    if (iconFile.exists)
					{
						template.logoImagePath = iconFile.url;
                    }

                    if (templateName.indexOf("Feathers SDK") != -1 || templateName.indexOf("Away3D") != -1)
					{
						feathersProjectTemplates.addItem(template);
                    }
                    else
					{
						projectTemplateCollection.addItem(template);
                    }
					
					if (templateName.indexOf("ActionScript") != -1)
					{
						actionScriptProjectTemplates.addItem(template);
					}

					if (templateName.indexOf("Royale") != -1 && templateName.indexOf("FlexJS") == -1
							&& templateName.indexOf("REST") == -1 && templateName.indexOf("Domino Export") == -1)
					{
                        royaleProjectTemplates.addItem(template);
					}
					if (templateName.indexOf("Royale") != -1 && templateName.indexOf("FlexJS") == -1
							&& templateName.indexOf("REST") != -1
							&& templateName.indexOf("Visual") == -1)
					{
                        royaleVisualProjectTemplates.addItem(template);
					}

					if (templateName.indexOf("Royale") != -1 && templateName.indexOf("FlexJS") == -1
							&& templateName.indexOf("Domino Export") != -1
							&& templateName.indexOf("Visual") == -1)
					{
						royaleDominoExportTemplates.addItem(template);
					}

					if (templateName.indexOf("Java") != -1)
					{
                        javaProjectTemplates.addItem(template);
					}

					if (template.title.indexOf("Grails") != -1)
					{
                        grailsProjectTemplates.addItem(template);
					}

					if (template.title.indexOf("Haxe") != -1)
					{
                        haxeProjectTemplates.addItem(template);
					}

					allLoadedTemplates.push(template);
                }
            }

            ConstantsCoreVO.TEMPLATES_PROJECTS = projectTemplateCollection;
            ConstantsCoreVO.TEMPLATES_PROJECTS_SPECIALS = feathersProjectTemplates;
			royaleProjectTemplates.source = royaleProjectTemplates.source.reverse();
			ConstantsCoreVO.TEMPLATES_PROJECTS_ROYALE = royaleProjectTemplates;
			royaleVisualProjectTemplates.source=royaleVisualProjectTemplates.source.reverse();
			ConstantsCoreVO.TEMPLATES_PROJECTS_ROYALE_VISUAL=royaleVisualProjectTemplates;
			ConstantsCoreVO.TEMPLATES_PROJECTS_ROYALE_DOMINO_EXPORT = royaleDominoExportTemplates;
			ConstantsCoreVO.TEMPLATES_PROJECTS_JAVA = javaProjectTemplates;
			ConstantsCoreVO.TEMPLATES_PROJECTS_GRAILS = grailsProjectTemplates;
			ConstantsCoreVO.TEMPLATES_PROJECTS_HAXE = haxeProjectTemplates;
			ConstantsCoreVO.TEMPLATES_PROJECTS_ACTIONSCRIPT = actionScriptProjectTemplates;
        }

		public function getSettingsList():Vector.<ISetting>
		{	
			// Build settings on each template (just a File object pointing to a directory)
			//  requires good names for the directories, but shouldn't be a problem
			settings = new Vector.<ISetting>();
			
			var categorySetting:MultiOptionSetting = new MultiOptionSetting(this, 'categoryType', "Select Category",
					Vector.<NameValuePair>([
						new NameValuePair("Projects", CATEGORY_PROJECTS),
						new NameValuePair("Files", CATEGORY_FILES)
					])
			);
			categorySetting.addEventListener(MultiOptionSetting.EVENT_MULTIOPTION_CHANGE, onCategorySettingsChanged, false, 0, true);
			settings.push(categorySetting);

			addProjectsOptions();

			settingsList = settings;
			return settings;
		}

		public function getMenu():MenuItem
		{	
			var newFileMenu:MenuItem = new MenuItem('New');
			var enableTypes:Array;
			newFileMenu.parents = ["File", "New"];
			newFileMenu.items = new Vector.<MenuItem>();
			for each (var fileTemplate:FileLocation in fileTemplates)
			{
				if (fileTemplate.fileBridge.isHidden) continue;
				var lbl:String = TemplatingHelper.getTemplateLabel(fileTemplate);
				
				// TODO: Do MenuEvent and have data:* for this kind of thing
				var eventType:String = "eventNewFileFromTemplate"+lbl;
				
				dispatcher.addEventListener(eventType, handleNewTemplateFile);
				
				enableTypes = TemplatingHelper.getTemplateMenuType(lbl);
				
				var menuItem:MenuItem = new MenuItem(lbl, null, enableTypes, eventType);
				menuItem.data = fileTemplate; 
				
				newFileMenu.items.push(menuItem);
			}
			
			var separator:MenuItem = new MenuItem(null);
			newFileMenu.items.push(separator);

			var filteredProjectTemplatesToMenu:Array = allLoadedTemplates.filter(filterProjectsTemplates);
			filteredProjectTemplatesToMenu.sortOn("homeTitle", Array.CASEINSENSITIVE);

			for each (var projectTemplate:TemplateVO in filteredProjectTemplatesToMenu)
			{
				if (projectTemplate.file.fileBridge.isHidden)
				{
					continue;
				}

				eventType = "eventNewProjectFromTemplate" + TemplatingHelper.getTemplateLabel(projectTemplate.file);
				
				dispatcher.addEventListener(eventType, handleNewProjectFile);
				
				menuItem = new MenuItem(projectTemplate.homeTitle, null, null, eventType);
				menuItem.data = projectTemplate;
				
				newFileMenu.items.push(menuItem);	
			}
			
			return newFileMenu;
		}

		protected function addFilesOptions():void
		{
			var fileLabel:StaticLabelSetting = new StaticLabelSetting("Files", 14);
			settings.push(fileLabel);

			var setting:TemplateSetting;
			for each (var t:FileLocation in fileTemplates)
			{
				if (t.fileBridge.isHidden) continue;
				setting = getTemplateSetting(t);
				settings.push(setting);
			}

			newFileTemplateSetting = new NewTemplateSetting("Add file template");
			newFileTemplateSetting.renderer.addEventListener('create', handleFileTemplateCreate, false, 0, true);

			settings.push(newFileTemplateSetting);
		}

		protected function addProjectsOptions():void
		{
			var projectLabel:StaticLabelSetting = new StaticLabelSetting("Projects", 14);
			settings.push(projectLabel);

			var setting:TemplateSetting;
			for each (var p:FileLocation in projectTemplates)
			{
				if (p.fileBridge.isHidden) continue;
				setting = getTemplateSetting(p);
				settings.push(setting);
			}

			newProjectTemplateSetting = new NewTemplateSetting("Add project template");
			newProjectTemplateSetting.renderer.addEventListener('create', handleProjectTemplateCreate, false, 0, true);

			settings.push(newProjectTemplateSetting);
		}
		
		protected function getTemplateSetting(template:FileLocation):TemplateSetting
		{
			var originalTemplate:FileLocation;
			var customTemplate:FileLocation;
			
			if (isCustom(template))
			{
				originalTemplate = null;
				customTemplate = template;
			}
			else
			{
				originalTemplate = template;
				customTemplate = TemplatingHelper.getCustomFileFor(template);
			}
			
			var setting:TemplateSetting = new TemplateSetting(originalTemplate, customTemplate, template.fileBridge.name);
			setting.renderer.addEventListener(TemplateRenderer.EVENT_MODIFY, handleTemplateModify, false, 0, true);
			setting.renderer.addEventListener(TemplateRenderer.EVENT_RESET, handleTemplateReset, false, 0, true);
			setting.renderer.addEventListener(TemplateRenderer.EVENT_REMOVE, handleTemplateReset, false, 0, true);
			setting.renderer.addEventListener(GeneralEvent.DONE, onRenameDone, false, 0, true);
			
			return setting;
		}
		
		
		protected function handleFileTemplateCreate(event:Event):void
		{
			// Create new file
			var increamentalNumber:int = 1;
			var newTemplate:FileLocation = this.customTemplatesDir.resolvePath("files/New file template.txt.template");
			while (newTemplate.fileBridge.exists)
			{
				newTemplate = this.customTemplatesDir.resolvePath("files/New file template("+ increamentalNumber +").txt.template");
				increamentalNumber++;
			}
			
			newTemplate.fileBridge.save("");
			
			// Add setting for it so we can remove it
			var t:TemplateSetting = new TemplateSetting(null, newTemplate, newTemplate.fileBridge.name);
			t.renderer.addEventListener(TemplateRenderer.EVENT_MODIFY, handleTemplateModify, false, 0, true);
			t.renderer.addEventListener(TemplateRenderer.EVENT_REMOVE, handleTemplateReset, false, 0, true);
			t.renderer.addEventListener(TemplateRenderer.EVENT_RESET, handleTemplateReset, false, 0, true);
			t.renderer.addEventListener(GeneralEvent.DONE, onRenameDone, false, 0, true);
			var newPos:int = this.settingsList.indexOf(newFileTemplateSetting);
			settingsList.splice(newPos, 0, t);
			
			// Force settings view to redraw
			NewTemplateRenderer(event.target).dispatchEvent(new Event('refresh'));
			
			// Add to project view so user can rename it
			GlobalEventDispatcher.getInstance().dispatchEvent(
				new OpenFileEvent(OpenFileEvent.OPEN_FILE, [newTemplate])
			);
			
			// Update internal template list
			fileTemplates.push(newTemplate);
			fileTemplates.sortOn("name", Array.CASEINSENSITIVE);
			
			// send event to get the new item added immediately to File/New menu
			var lbl:String = TemplatingHelper.getTemplateLabel(newTemplate);
			var eventType:String = "eventNewFileFromTemplate"+lbl;
			dispatcher.addEventListener(eventType, handleNewTemplateFile, false, 0, true);
			dispatcher.dispatchEvent(new TemplatingEvent(TemplatingEvent.ADDED_NEW_TEMPLATE, false, lbl, eventType));
		}
		
		protected function handleProjectTemplateCreate(event:Event):void
		{
			var increamentalNumber:int = 1;
			var newTemplate:FileLocation = this.customTemplatesDir.resolvePath("projects/New Project Template/");
			while (newTemplate.fileBridge.exists)
			{
				newTemplate = this.customTemplatesDir.resolvePath("projects/New Project Template("+ increamentalNumber +")/");
				increamentalNumber++;
			}
			
			newTemplate.fileBridge.createDirectory();
			
			var t:TemplateSetting = new TemplateSetting(null, newTemplate, newTemplate.fileBridge.name);
			t.renderer.addEventListener(TemplateRenderer.EVENT_MODIFY, handleTemplateModify, false, 0, true);
			t.renderer.addEventListener(TemplateRenderer.EVENT_REMOVE, handleTemplateReset, false, 0, true);
			t.renderer.addEventListener(GeneralEvent.DONE, onRenameDone, false, 0, true);
			var newPos:int = this.settingsList.indexOf(newProjectTemplateSetting);
			settingsList.splice(newPos, 0, t);
			
			var newProject:AS3ProjectVO = new AS3ProjectVO(newTemplate, newTemplate.fileBridge.name);
			newProject.classpaths[0] = newTemplate;
			newProject.projectFolder.projectReference.isTemplate = true;
			
			dispatcher.dispatchEvent(
				new ProjectEvent(ProjectEvent.ADD_PROJECT, newProject)
			);
			
			NewTemplateRenderer(event.target).dispatchEvent(new Event('refresh'));
			
			projectTemplates.push(newTemplate);
			projectTemplates.sortOn("homeTitle", Array.CASEINSENSITIVE);
			
			// send event to get the new item added immediately to File/New menu
			// send event to get the new item added immediately to File/New menu
			var lbl:String = TemplatingHelper.getTemplateLabel(newTemplate);
			var eventType:String = "eventNewProjectFromTemplate"+lbl;
			dispatcher.addEventListener(eventType, handleNewProjectFile, false, 0, true);
			dispatcher.dispatchEvent(new TemplatingEvent(TemplatingEvent.ADDED_NEW_TEMPLATE, true, lbl, eventType));
		}
		
		protected function handleTemplateModify(event:Event):void
		{
			var rdr:TemplateRenderer = TemplateRenderer(event.target);
			var original:FileLocation = rdr.setting.originalTemplate;
			var custom:FileLocation = rdr.setting.customTemplate;
			
			var p:AS3ProjectVO;
			
			if ((!original || !original.fileBridge.exists) && custom.fileBridge.isDirectory)
			{
				p = new AS3ProjectVO(custom, custom.fileBridge.name)
			}
			else if (!custom.fileBridge.exists && (original && original.fileBridge.exists && original.fileBridge.isDirectory))
			{
				// Copy to app-storage so we can edit
				original.fileBridge.copyTo(custom);
				p = new AS3ProjectVO(custom, custom.fileBridge.name);
			}
			else if (!custom.fileBridge.exists && original && original.fileBridge.exists && !original.fileBridge.isDirectory)
			{
				original.fileBridge.copyTo(custom);
			}
			else if (custom && custom.fileBridge.exists && custom.fileBridge.isDirectory)
			{
				p = new AS3ProjectVO(custom, custom.fileBridge.name);
			}
			
			// If project or custom, show in Project View so user can rename it
			if (p)
			{
				p.classpaths[0] = p.folderLocation;
				p.projectFolder.projectReference.isTemplate = true;
				p.menuType = ProjectMenuTypes.TEMPLATE;
				dispatcher.dispatchEvent(
					new ProjectEvent(ProjectEvent.ADD_PROJECT, p)
				);
			}
				
				// If not a project, open the template for editing
			else if (!custom.fileBridge.isDirectory)
			{
				dispatcher.dispatchEvent(
					new OpenFileEvent(OpenFileEvent.OPEN_FILE, [custom])
				);
			}
		}
		
		protected function handleTemplateReset(event:Event):void
		{
			// Resetting a template just removes it from app-storage
			var rdr:TemplateRenderer = TemplateRenderer(event.target);
			var original:FileLocation = rdr.setting.originalTemplate;
			var custom:FileLocation = rdr.setting.customTemplate;
			var lbl:String = TemplatingHelper.getTemplateLabel(custom);
			
			if (custom.fileBridge.exists)
			{
				if (custom.fileBridge.isDirectory) 
				{
					var isProjectOpen:Boolean = false;
					for each (var i:ProjectVO in model.projects)
					{
						if (i.folderLocation.fileBridge.nativePath == custom.fileBridge.nativePath)
						{
							isProjectOpen = true;
							i.projectFolder.isRoot = true;
							model.mainView.getTreeViewPanel().tree.dispatchEvent(new TreeMenuItemEvent(TreeMenuItemEvent.RIGHT_CLICK_ITEM_SELECTED, FTETreeItemRenderer.DELETE_PROJECT, i.projectFolder, false));
							break;
						}
					}
					
					if (!isProjectOpen) 
					{
						custom.fileBridge.deleteDirectory(true);
					}
				}
				else 
				{
					// if the template file is already opened to an editor
					for each (var tab:IContentWindow in model.editors)
					{
						var ed:BasicTextEditor = tab as BasicTextEditor;
						if (ed 
							&& ed.currentFile
							&& ed.currentFile.fileBridge.nativePath == custom.fileBridge.nativePath)
						{
							// close the tab
							GlobalEventDispatcher.getInstance().dispatchEvent(
								new CloseTabEvent(CloseTabEvent.EVENT_CLOSE_TAB, ed, true)
							);
						}
					}
					
					// deletes the file
					custom.fileBridge.deleteFile();
				}
				
				resetIndex --;
			}
			
			if (!original)
			{
				var idx:int = settingsList.indexOf(rdr.setting);
				settingsList.splice(idx, 1);
				rdr.dispatchEvent(new Event('refresh'));
				
				//readTemplates();
				if (custom.fileBridge.isDirectory) 
				{
					// remove the item from New/File menu
					dispatcher.dispatchEvent(new TemplatingEvent(TemplatingEvent.REMOVE_TEMPLATE, true, lbl));
					
					projectTemplates.splice(projectTemplates.indexOf(custom), 1);
				}
				else 
				{
					// remove the item from New/File menu
					dispatcher.dispatchEvent(new TemplatingEvent(TemplatingEvent.REMOVE_TEMPLATE, false, lbl));
					
					fileTemplates.splice(fileTemplates.indexOf(custom), 1);
				}
			}
		}
		
		protected function onRenameDone(event:GeneralEvent):void
		{
			// Resetting a template just removes it from app-storage
			var rdr:TemplateRenderer = TemplateRenderer(event.target);
			var custom:FileLocation = rdr.setting.customTemplate;
			var tmpOldIndex:int;
			var oldFileName:String = TemplatingHelper.getTemplateLabel(custom);
			var newFileNameWithExtension:String = event.value as String;
			var newFileName:String = newFileNameWithExtension.split(".")[0];
			
			if (custom.fileBridge.exists)
			{
				var customNewLocation:FileLocation = custom.fileBridge.parent.resolvePath(newFileNameWithExtension +(!custom.fileBridge.isDirectory ? ".template" : ""));
				// check if no duplicate naming happens
				if (customNewLocation.fileBridge.exists)
				{
					Alert.show(newFileNameWithExtension +" is already available.", "!Error");
					return;
				}
				
				var isDirectory:Boolean = custom.fileBridge.isDirectory; // detect this before moveTo else it'll always return false to older file instance
				custom.fileBridge.moveTo(customNewLocation, true);
				
				if (!isDirectory)
				{
					// we need to update file location of the (if any) opened instance 
					// of the file template
					for each (var tab:IContentWindow in model.editors)
					{
						var ed:BasicTextEditor = tab as BasicTextEditor;
						if (ed 
							&& ed.currentFile
							&& ed.currentFile.fileBridge.nativePath == custom.fileBridge.nativePath)
						{
							ed.currentFile = customNewLocation;
						}
					}
					
					// remove the existing File/New listener
					dispatcher.removeEventListener("eventNewFileFromTemplate"+ oldFileName, handleNewTemplateFile);
					dispatcher.addEventListener("eventNewFileFromTemplate"+ newFileName, handleNewTemplateFile);
					
					// update file list
					tmpOldIndex = fileTemplates.indexOf(custom);
					if (tmpOldIndex != -1) 
					{
						fileTemplates[tmpOldIndex] = customNewLocation;
						setTimeout(function():void
						{
							fileTemplates.sortOn("name", Array.CASEINSENSITIVE);
						}, 1000);
					}
					
					// updating file/new menu
					dispatcher.dispatchEvent(new TemplatingEvent(TemplatingEvent.RENAME_TEMPLATE, false, oldFileName, null, newFileName, customNewLocation));
				}
				else 
				{
					dispatcher.dispatchEvent(new RenameApplicationEvent(RenameApplicationEvent.RENAME_APPLICATION_FOLDER, custom, customNewLocation));
					
					// remove the existing File/New listener
					dispatcher.removeEventListener("eventNewProjectFromTemplate"+ oldFileName, handleNewProjectFile);
					dispatcher.addEventListener("eventNewProjectFromTemplate"+ newFileName, handleNewProjectFile);
					
					// update file list
					tmpOldIndex = projectTemplates.indexOf(custom);
					if (tmpOldIndex != -1) 
					{
						projectTemplates[tmpOldIndex] = customNewLocation;
						projectTemplates.sortOn("homeTitle", Array.CASEINSENSITIVE);
					}
					
					// updating file/new menu
					dispatcher.dispatchEvent(new TemplatingEvent(TemplatingEvent.RENAME_TEMPLATE, true, oldFileName, null, newFileName, customNewLocation));
				}
				
				rdr.setting.customTemplate = customNewLocation;
				rdr.setting.label = rdr.setting.customTemplate.fileBridge.name;
				rdr.dispatchEvent(new Event('refresh'));
			}
		}
		
		protected function handleCreateFileTemplate(event:TemplateEvent):void
		{
			// If we know where to place it we replace strings inside it
			if (event.location)
			{
				// Request additional data for templating
				var newEvent:TemplateEvent = new TemplateEvent(TemplateEvent.REQUEST_ADDITIONAL_DATA, event.template, event.location);
				dispatcher.dispatchEvent(newEvent);
				
				var helper:TemplatingHelper = new TemplatingHelper();
				helper.templatingData = newEvent.templatingData;
				helper.fileTemplate(newEvent.template, newEvent.location);
				
				dispatcher.dispatchEvent(
					new OpenFileEvent(OpenFileEvent.OPEN_FILE, [newEvent.location])
				);
			}
			else
			{
				// Otherwise we just create the file
				createFile(event.template);
			}
		}
		
		protected function handleNewTemplateFile(event:Event):void
		{
			var eventName:String;
			var i:int;
			var fileTemplate:FileLocation;
			if (ConstantsCoreVO.IS_AIR)
			{
				eventName = event.type.substr(24);
				// MXML type choose
				switch (eventName)
				{
					case "MXML File":
						openMXMLComponentTypeChoose(event);
                        break;
					case "AS3 Class":
						openAS3ComponentTypeChoose(event, false);
                        break;
					case "AS3 Interface":
						openAS3ComponentTypeChoose(event, true);
                        break;
					case "CSS File":
						openCSSComponentTypeChoose(event);
                        break;
					case "MXML Module":
						openMXMLModuleTypeChoose(event);
						break;
					case "XML File":
						openNewComponentTypeChoose(event, NewFilePopup.AS_XML);
                        break;
					case "File":
						openNewComponentTypeChoose(event, NewFilePopup.AS_PLAIN_TEXT);
                        break;
					case "Visual Editor Flex File":
					case "Visual Editor PrimeFaces File":
						openVisualEditorComponentTypeChoose(event);
						break;
					case "Domino Visual Editor Form":
						openDominoFormComponentTypeChoose(event);
						break;
					case "Domino Visual Editor Subform":
						openDominoSubFormComponentTypeChoose(event);
						break;
					case "Domino Visual Editor View":
						openDominoViewComponentTypeChoose(event);
						break;
					case "Domino Visual Editor View Shared Column":
						openDominoViewShareColumnComponentTypeChoose(event);
						break;		
					case "Domino Visual Share Field":
						openDominoShareFieldComponentTypeChoose(event);
						break;	
					case "Domino Visual Editor Action":
						openDominoActionComponentTypeChoose(event);
						break;	
					case "Domino Visual Editor Page":
						openDominoPageComponentTypeChoose(event);
						break;
					case "Visual Editor Domino File":
						openVisualEditorComponentTypeChoose(event);
						break;
					case "Java Class":
						openJavaTypeChoose(event, false);
						break;
					case "Java Interface":
						openJavaTypeChoose(event, true);
						break;
					case "Groovy Class":
						openGroovyTypeChoose(event, false);
						break;
					case "Groovy Interface":
						openGroovyTypeChoose(event, true);
						break;
					case "Haxe Class":
						openHaxeTypeChoose(event, false);
						break;
					case "Haxe Interface":
						openHaxeTypeChoose(event, true);
						break;
					case "Form Builder DXL File":
						openOnDiskFormBuilderTypeChoose(event);
						break;
					case "Visual Editor DXL File":
						openOnDiskVisualEditorTypeChoose(event);
						break;
					default:
						for (i = 0; i < fileTemplates.length; i++)
						{
							fileTemplate = fileTemplates[i];
							if ( TemplatingHelper.getTemplateLabel(fileTemplate) == eventName )
							{
								if (fileTemplate.fileBridge.exists)
								{
									openNewComponentTypeChoose(event, NewFilePopup.AS_CUSTOM, fileTemplate);
									break;
								}
							}
						}
						break;
				}
			}
			else
			{
				eventName = event.type;
				// Figure out which menu item was clicked (add extra data var to MenuPlugin/event dispatching?)
				for (i = 0; i < ConstantsCoreVO.TEMPLATES_FILES.length; i++)
				{
					fileTemplate = ConstantsCoreVO.TEMPLATES_FILES[i];
					if ( TemplatingHelper.getTemplateLabel(fileTemplate) == eventName )
					{
						createFile(fileTemplate);
						return;
					}
				}
			}
		}
		
		protected function createFile(template:FileLocation):void
		{
			var editor:BasicTextEditor = new BasicTextEditor();
			
			// Let plugins hook in syntax highlighters & other functionality
			var editorEvent:EditorPluginEvent = new EditorPluginEvent(EditorPluginEvent.EVENT_EDITOR_OPEN);
			editorEvent.editor = editor.getEditorComponent();
			editorEvent.newFile = true;
			editorEvent.fileExtension = TemplatingHelper.getExtension(template);
			dispatcher.dispatchEvent(editorEvent);
			
			editor.defaultLabel = "New " + TemplatingHelper.stripTemplate(template.fileBridge.name);
			
			// Read file data
			var content:String = ConstantsCoreVO.IS_AIR ? String(template.fileBridge.read()) : String(template.fileBridge.data);
			
			// Request additional data for templating
			var event:TemplateEvent = new TemplateEvent(TemplateEvent.REQUEST_ADDITIONAL_DATA, template);
			dispatcher.dispatchEvent(event);
			
			// Replace content if any
			content = TemplatingHelper.replace(content, event.templatingData);
			
			// Set content to editor
			editor.setContent(content);
			
			// Remove empty editor if one is focused
			if (model.activeEditor.isEmpty())
			{
				model.editors.removeItemAt(model.editors.getItemIndex(model.activeEditor));
			}
			
			dispatcher.dispatchEvent(
				new AddTabEvent(editor)
			);
		}
		
		protected function openMXMLComponentTypeChoose(event:Event):void
		{
			if (!newMXMLComponentPopup)
			{
				newMXMLComponentPopup = PopUpManager.createPopUp(FlexGlobals.topLevelApplication as DisplayObject, NewMXMLFilePopup, true) as NewMXMLFilePopup;
				newMXMLComponentPopup.addEventListener(CloseEvent.CLOSE, handleMXMLPopupClose);
				newMXMLComponentPopup.addEventListener(NewFileEvent.EVENT_NEW_FILE, onMXMLFileCreateRequest);
				
				// newFileEvent sends by TreeView when right-clicked 
				// context menu
				if (event is NewFileEvent) 
				{
					newMXMLComponentPopup.folderLocation = new FileLocation((event as NewFileEvent).filePath);
					newMXMLComponentPopup.wrapperOfFolderLocation = (event as NewFileEvent).insideLocation;
					newMXMLComponentPopup.wrapperBelongToProject = UtilsCore.getProjectFromProjectFolder((event as NewFileEvent).insideLocation);
				}
				else
				{
					// try to check if there is any selection in 
					// TreeView item
					var treeSelectedItem:FileWrapper = model.mainView.getTreeViewPanel().tree.selectedItem as FileWrapper;
					if (treeSelectedItem)
					{
						var creatingItemIn:FileWrapper = (treeSelectedItem.file.fileBridge.isDirectory) ? treeSelectedItem : FileWrapper(model.mainView.getTreeViewPanel().tree.getParentItem(treeSelectedItem));
						newMXMLComponentPopup.folderLocation = creatingItemIn.file;
						newMXMLComponentPopup.wrapperOfFolderLocation = creatingItemIn;
						newMXMLComponentPopup.wrapperBelongToProject = UtilsCore.getProjectFromProjectFolder(creatingItemIn);
					}
				}
				
				PopUpManager.centerPopUp(newMXMLComponentPopup);
			}
		}

        protected function openVisualEditorComponentTypeChoose(event:Event):void
        {
            if (!newVisualEditorFilePopup)
            {
                newVisualEditorFilePopup = PopUpManager.createPopUp(FlexGlobals.topLevelApplication as DisplayObject, NewVisualEditorFilePopup, true) as NewVisualEditorFilePopup;
                newVisualEditorFilePopup.addEventListener(CloseEvent.CLOSE, handleNewVisualEditorFilePopupClose);

                // newFileEvent sends by TreeView when right-clicked
                // context menu
                if (event is NewFileEvent)
                {
                    newVisualEditorFilePopup.folderLocation = new FileLocation((event as NewFileEvent).filePath);
                    newVisualEditorFilePopup.wrapperOfFolderLocation = (event as NewFileEvent).insideLocation;
                    newVisualEditorFilePopup.wrapperBelongToProject = UtilsCore.getProjectFromProjectFolder((event as NewFileEvent).insideLocation);
                }
                else
                {
                    // try to check if there is any selection in
                    // TreeView item
                    var treeSelectedItem:FileWrapper = model.mainView.getTreeViewPanel().tree.selectedItem as FileWrapper;
                    if (treeSelectedItem)
                    {
                        var creatingItemIn:FileWrapper = (treeSelectedItem.file.fileBridge.isDirectory) ? treeSelectedItem : FileWrapper(model.mainView.getTreeViewPanel().tree.getParentItem(treeSelectedItem));
                        newVisualEditorFilePopup.folderLocation = creatingItemIn.file;
                        newVisualEditorFilePopup.wrapperOfFolderLocation = creatingItemIn;
                        newVisualEditorFilePopup.wrapperBelongToProject = UtilsCore.getProjectFromProjectFolder(creatingItemIn);
                    }
                }

                PopUpManager.centerPopUp(newVisualEditorFilePopup);
            }
        }
		
		protected function openDominoVisualEditorFormTypeChoose(event:Event):void
        {
			var insideLocation:FileWrapper = (event is NewFileEvent) ?
					(event as NewFileEvent).insideLocation :
					(model.mainView.getTreeViewPanel().tree.selectedItem as FileWrapper);
			if (insideLocation && !insideLocation.file.fileBridge.isDirectory)
			{
				insideLocation = FileWrapper(model.mainView.getTreeViewPanel().tree.getParentItem(insideLocation));
			}
			if (insideLocation)
			{
				var tmpOnDiskEvent:NewFileEvent = new NewFileEvent(
						OnDiskProjectPlugin.EVENT_NEW_FILE_WINDOW, insideLocation.nativePath,
						ConstantsCoreVO.TEMPLATES_VISUALEDITOR_FILES_DOMINO_FORM, insideLocation
				);
				tmpOnDiskEvent.ofProject = (event is NewFileEvent) ? (event as NewFileEvent).ofProject : model.activeProject;

				dispatcher.dispatchEvent(tmpOnDiskEvent);
			}
			else
			{
				error("error: Select location before creating a new file.");
			}
        }

		protected function openOnDiskFormBuilderTypeChoose(event:Event):void
		{
			var insideLocation:FileWrapper = (event is NewFileEvent) ?
					(event as NewFileEvent).insideLocation :
					(model.mainView.getTreeViewPanel().tree.selectedItem as FileWrapper);
			if (insideLocation && !insideLocation.file.fileBridge.isDirectory)
			{
				insideLocation = FileWrapper(model.mainView.getTreeViewPanel().tree.getParentItem(insideLocation));
			}
			if (insideLocation)
			{
				var tmpOnDiskEvent:NewFileEvent = new NewFileEvent(
						OnDiskProjectPlugin.EVENT_NEW_FILE_WINDOW, insideLocation.nativePath,
						ConstantsCoreVO.TEMPLATE_ODP_FORMBUILDER_FILE, insideLocation
				);
				tmpOnDiskEvent.ofProject = (event is NewFileEvent) ? (event as NewFileEvent).ofProject : model.activeProject;

				dispatcher.dispatchEvent(tmpOnDiskEvent);
			}
			else
			{
				error("error: Select location before creating a new file.");
			}
		}
		
		protected function openOnDiskVisualEditorTypeChoose(event:Event):void
		{
			// if(!newOnDiskFilePopup){
			// 	newOnDiskFilePopup = PopUpManager.createPopUp(FlexGlobals.topLevelApplication as DisplayObject, NewOnDiskFilePopup, true) as NewOnDiskFilePopup;
			// 	newOnDiskFilePopup.addEventListener(CloseEvent.CLOSE, handleNewFilePopupClose);
			// 	if (event is NewFileEvent)
            //     {
            //         newOnDiskFilePopup.folderLocation = new FileLocation((event as NewFileEvent).filePath);
			// 		newOnDiskFilePopup.wrapperOfFolderLocation = (event as NewFileEvent).insideLocation;
			// 		newOnDiskFilePopup.wrapperBelongToProject = UtilsCore.getProjectFromProjectFolder((event as NewFileEvent).insideLocation);
			
            //     }
            //     else
            //     {
			// 		var treeSelectedItem:FileWrapper = model.mainView.getTreeViewPanel().tree.selectedItem as FileWrapper;
            //         if (treeSelectedItem)
            //         {
            //             var creatingItemIn:FileWrapper = (treeSelectedItem.file.fileBridge.isDirectory) ? treeSelectedItem : FileWrapper(model.mainView.getTreeViewPanel().tree.getParentItem(treeSelectedItem));
            //             newOnDiskFilePopup.folderLocation = creatingItemIn.file;
            //             newOnDiskFilePopup.wrapperOfFolderLocation = creatingItemIn;
            //             newOnDiskFilePopup.wrapperBelongToProject = UtilsCore.getProjectFromProjectFolder(creatingItemIn);
            //         }
			// 	}
			// 	PopUpManager.centerPopUp(newOnDiskFilePopup);
			// }
			
			var tmpOnDiskEvent:NewFileEvent =null;
			if(event is NewFileEvent){
				tmpOnDiskEvent= new NewFileEvent(
				OnDiskProjectPlugin.EVENT_NEW_FILE_WINDOW, (event as NewFileEvent).filePath,
				ConstantsCoreVO.TEMPLATE_ODP_VISUALEDITOR_FILE, (event as NewFileEvent).insideLocation
				);
				tmpOnDiskEvent.ofProject = (event as NewFileEvent).ofProject;
			}else{
				var treeSelectedItem:FileWrapper = model.mainView.getTreeViewPanel().tree.selectedItem as FileWrapper;
				if(treeSelectedItem){
				var creatingItemIn:FileWrapper = (treeSelectedItem.file.fileBridge.isDirectory) ? treeSelectedItem : FileWrapper(model.mainView.getTreeViewPanel().tree.getParentItem(treeSelectedItem));
				tmpOnDiskEvent= new NewFileEvent(
				OnDiskProjectPlugin.EVENT_NEW_FILE_WINDOW, creatingItemIn.file.fileBridge.nativePath,
				ConstantsCoreVO.TEMPLATE_ODP_VISUALEDITOR_FILE, creatingItemIn
				);
				}
			}
			
			//tmpOnDiskEvent.ofProject = (event as NewFileEvent).ofProject;
			
			dispatcher.dispatchEvent(tmpOnDiskEvent);
		}

		protected function handleNewFilePopupClose(event:CloseEvent):void
		{
			newOnDiskFilePopup.removeEventListener(CloseEvent.CLOSE, handleNewFilePopupClose);
			// newOnDiskFilePopup.removeEventListener(NewFileEvent.EVENT_NEW_FILE, onNewFileCreateRequest);
			newOnDiskFilePopup = null;
		}

		protected function openCSSComponentTypeChoose(event:Event):void
		{
			if (!newCSSComponentPopup)
			{
				newCSSComponentPopup = PopUpManager.createPopUp(FlexGlobals.topLevelApplication as DisplayObject, NewCSSFilePopup, true) as NewCSSFilePopup;
				newCSSComponentPopup.addEventListener(CloseEvent.CLOSE, handleCSSPopupClose);
				newCSSComponentPopup.addEventListener(NewFileEvent.EVENT_NEW_FILE, onCSSFileCreateRequest);
				
				// newFileEvent sends by TreeView when right-clicked 
				// context menu
				if (event is NewFileEvent) 
				{
					newCSSComponentPopup.folderLocation = new FileLocation((event as NewFileEvent).filePath);
					newCSSComponentPopup.wrapperOfFolderLocation = (event as NewFileEvent).insideLocation;
					newCSSComponentPopup.wrapperBelongToProject = UtilsCore.getProjectFromProjectFolder((event as NewFileEvent).insideLocation);
				}
				else
				{
					// try to check if there is any selection in 
					// TreeView item
					var treeSelectedItem:FileWrapper = model.mainView.getTreeViewPanel().tree.selectedItem as FileWrapper;
					if (treeSelectedItem)
					{
						var creatingItemIn:FileWrapper = (treeSelectedItem.file.fileBridge.isDirectory) ? treeSelectedItem : FileWrapper(model.mainView.getTreeViewPanel().tree.getParentItem(treeSelectedItem));
						newCSSComponentPopup.folderLocation = creatingItemIn.file;
						newCSSComponentPopup.wrapperOfFolderLocation = creatingItemIn;
						newCSSComponentPopup.wrapperBelongToProject = UtilsCore.getProjectFromProjectFolder(creatingItemIn);
					}
				}
				
				PopUpManager.centerPopUp(newCSSComponentPopup);
			}
		}

		protected function openDominoFormComponentTypeChoose(event:Event):void
		{
			var dominoFormFolderStr:String;
			var dominoFormFolder:FileLocation;
			var treeSelectedItem:FileWrapper = model.mainView.getTreeViewPanel().tree.selectedItem as FileWrapper;

			if (!newDominoFormComponentPopup)
			{
				newDominoFormComponentPopup = PopUpManager.createPopUp(FlexGlobals.topLevelApplication as DisplayObject, NewDominoFormPopup, true) as NewDominoFormPopup;
				newDominoFormComponentPopup.addEventListener(CloseEvent.CLOSE, handleDominoFormPopupClose);
				newDominoFormComponentPopup.addEventListener(NewFileEvent.EVENT_NEW_FILE, onDominoFormFileCreateRequest);
                //setting default folder or selected folder for new file
			    if (event is NewFileEvent) 
				{
					newDominoFormComponentPopup.folderLocation = new FileLocation((event as NewFileEvent).filePath);
					newDominoFormComponentPopup.wrapperOfFolderLocation = (event as NewFileEvent).insideLocation;
					newDominoFormComponentPopup.wrapperBelongToProject = UtilsCore.getProjectFromProjectFolder((event as NewFileEvent).insideLocation);
				}
				else
				{
					
					if (treeSelectedItem)
					{
						var creatingItemIn:FileWrapper = (treeSelectedItem.file.fileBridge.isDirectory) ? treeSelectedItem : FileWrapper(model.mainView.getTreeViewPanel().tree.getParentItem(treeSelectedItem));
						newDominoFormComponentPopup.folderLocation = creatingItemIn.file;
						newDominoFormComponentPopup.wrapperOfFolderLocation = creatingItemIn;
						newDominoFormComponentPopup.wrapperBelongToProject = UtilsCore.getProjectFromProjectFolder(creatingItemIn);
					}
				}
				//only for fixed folder for domino form file
				
			
				if(treeSelectedItem && UtilsCore.endsWith(treeSelectedItem.nativePath,"Subforms")){
					dominoFormFolderStr =newDominoFormComponentPopup.wrapperBelongToProject.projectFolder.nativePath +  model.fileCore.separator +"nsfs"+model.fileCore.separator+"nsf-moonshine"+model.fileCore.separator+"odp"+model.fileCore.separator+"SharedElements"+model.fileCore.separator+"Subforms";
				}else{
					dominoFormFolderStr =newDominoFormComponentPopup.wrapperBelongToProject.projectFolder.nativePath +  model.fileCore.separator +"nsfs"+model.fileCore.separator+"nsf-moonshine"+model.fileCore.separator+"odp"+model.fileCore.separator+"Forms";
				}
				dominoFormFolder =new FileLocation(dominoFormFolderStr);
				
				
				//if it is a subform it should be fix again to sub form 

				if(dominoFormFolder.fileBridge.exists){
					//set the tree selct to domino form folder
					UtilsCore.wrappersFoundThroughFindingAWrapper = new Vector.<FileWrapper>();
					var dominoFormFolderWrapper:FileWrapper = UtilsCore.findDominoFileWrapperInDepth(newDominoFormComponentPopup.wrapperBelongToProject.projectFolder, dominoFormFolderStr);
					model.mainView.getTreeViewPanel().tree.callLater(function ():void
					{
						var wrappers:Vector.<FileWrapper> = UtilsCore.wrappersFoundThroughFindingAWrapper;
					
						for (var j:int = 0; j < (wrappers.length - 1); j++)
						{
							model.mainView.getTreeViewPanel().tree.expandItem(wrappers[j], true);
						}
		
						// selection
						model.mainView.getTreeViewPanel().tree.selectedItem = dominoFormFolderWrapper;
						// scroll-to
						model.mainView.getTreeViewPanel().tree.callLater(function ():void
						{
							model.mainView.getTreeViewPanel().tree.scrollToIndex(model.mainView.getTreeViewPanel().tree.getItemIndex(dominoFormFolderWrapper));
						});
					});
					
					
					//model.mainView.getTreeViewPanel().tree.selectedItem = dominoFormFolderWrapper;
					newDominoFormComponentPopup.wrapperOfFolderLocation = dominoFormFolderWrapper;
					newDominoFormComponentPopup.folderLocation =dominoFormFolder;
					PopUpManager.centerPopUp(newDominoFormComponentPopup);
				}else{
					Alert.show("Can't found the form folder from the project,please make sure it is ODP domino project!");
				}
				
			}
		}
		protected function openDominoSubFormComponentTypeChoose(event:Event):void
		{
			if (!newDominoSubformComponentPopup)
			{
				newDominoSubformComponentPopup = PopUpManager.createPopUp(FlexGlobals.topLevelApplication as DisplayObject, NewDominoSubFormPopup, true) as NewDominoSubFormPopup;
				newDominoSubformComponentPopup.addEventListener(CloseEvent.CLOSE, handleDominoSubformPopupClose);
				newDominoSubformComponentPopup.addEventListener(NewFileEvent.EVENT_NEW_FILE, onDominoSubformFileCreateRequest);
                //setting default folder or selected folder for new file
			    if (event is NewFileEvent) 
				{
					newDominoSubformComponentPopup.folderLocation = new FileLocation((event as NewFileEvent).filePath);
					newDominoSubformComponentPopup.wrapperOfFolderLocation = (event as NewFileEvent).insideLocation;
					newDominoSubformComponentPopup.wrapperBelongToProject = UtilsCore.getProjectFromProjectFolder((event as NewFileEvent).insideLocation);
				}
				else
				{
					// try to check if there is any selection in 
					// TreeView item
					var treeSelectedItem:FileWrapper = model.mainView.getTreeViewPanel().tree.selectedItem as FileWrapper;
					if (treeSelectedItem)
					{
						var creatingItemIn:FileWrapper = (treeSelectedItem.file.fileBridge.isDirectory) ? treeSelectedItem : FileWrapper(model.mainView.getTreeViewPanel().tree.getParentItem(treeSelectedItem));
						newDominoSubformComponentPopup.folderLocation = creatingItemIn.file;
						newDominoSubformComponentPopup.wrapperOfFolderLocation = creatingItemIn;
						newDominoSubformComponentPopup.wrapperBelongToProject = UtilsCore.getProjectFromProjectFolder(creatingItemIn);
					}
				}
				//only for fixed folder for domino form file
			
			
				var dominoSubformFolderStr:String=newDominoSubformComponentPopup.wrapperBelongToProject.projectFolder.nativePath +  model.fileCore.separator +"nsfs"+model.fileCore.separator+"nsf-moonshine"+model.fileCore.separator+"odp"+model.fileCore.separator+"SharedElements"+model.fileCore.separator+"Subforms";
				var dominoSubformFolder:FileLocation=new FileLocation(dominoSubformFolderStr);
				if(dominoSubformFolder.fileBridge.exists){
					//set the tree selct to domino form folder
					UtilsCore.wrappersFoundThroughFindingAWrapper = new Vector.<FileWrapper>();
					var dominoSubformFolderWrapper:FileWrapper = UtilsCore.findDominoFileWrapperInDepth(newDominoSubformComponentPopup.wrapperBelongToProject.projectFolder, dominoSubformFolderStr);
					model.mainView.getTreeViewPanel().tree.callLater(function ():void
					{
						var wrappers:Vector.<FileWrapper> = UtilsCore.wrappersFoundThroughFindingAWrapper;
					
						for (var j:int = 0; j < (wrappers.length - 1); j++)
						{
							model.mainView.getTreeViewPanel().tree.expandItem(wrappers[j], true);
						}
		
						// selection
						model.mainView.getTreeViewPanel().tree.selectedItem = dominoSubformFolderWrapper;
						// scroll-to
						model.mainView.getTreeViewPanel().tree.callLater(function ():void
						{
							model.mainView.getTreeViewPanel().tree.scrollToIndex(model.mainView.getTreeViewPanel().tree.getItemIndex(dominoSubformFolderWrapper));
						});
					});
					
					
					//model.mainView.getTreeViewPanel().tree.selectedItem = dominoFormFolderWrapper;
					newDominoSubformComponentPopup.wrapperOfFolderLocation = dominoSubformFolderWrapper;
					newDominoSubformComponentPopup.folderLocation =dominoSubformFolder;
					PopUpManager.centerPopUp(newDominoSubformComponentPopup);
				}else{
					Alert.show("Can't found the form folder from the project,please make sure it is ODP domino project!");
				}
				
			}
		}
		//newDominoSharedFieldComponentPopup
		protected function openDominoShareFieldComponentTypeChoose(event:Event):void
		{
			if (!newDominoSharedFieldComponentPopup)
			{
				newDominoSharedFieldComponentPopup = PopUpManager.createPopUp(FlexGlobals.topLevelApplication as DisplayObject, NewDominoShareFieldPopup, true) as NewDominoShareFieldPopup;
				newDominoSharedFieldComponentPopup.addEventListener(CloseEvent.CLOSE, handleDominoShareFieldPopupClose);
				newDominoSharedFieldComponentPopup.addEventListener(NewFileEvent.EVENT_NEW_FILE, onDominoSharedFieldFileCreateRequest);
                //setting default folder or selected folder for new file
			    if (event is NewFileEvent) 
				{
					newDominoSharedFieldComponentPopup.folderLocation = new FileLocation((event as NewFileEvent).filePath);
					newDominoSharedFieldComponentPopup.wrapperOfFolderLocation = (event as NewFileEvent).insideLocation;
					newDominoSharedFieldComponentPopup.wrapperBelongToProject = UtilsCore.getProjectFromProjectFolder((event as NewFileEvent).insideLocation);
				}
				else
				{
					// try to check if there is any selection in 
					// TreeView item
					var treeSelectedItem:FileWrapper = model.mainView.getTreeViewPanel().tree.selectedItem as FileWrapper;
					if (treeSelectedItem)
					{
						var creatingItemIn:FileWrapper = (treeSelectedItem.file.fileBridge.isDirectory) ? treeSelectedItem : FileWrapper(model.mainView.getTreeViewPanel().tree.getParentItem(treeSelectedItem));
						newDominoSharedFieldComponentPopup.folderLocation = creatingItemIn.file;
						newDominoSharedFieldComponentPopup.wrapperOfFolderLocation = creatingItemIn;
						newDominoSharedFieldComponentPopup.wrapperBelongToProject = UtilsCore.getProjectFromProjectFolder(creatingItemIn);
					}
				}
				//only for fixed folder for domino form file
			
				
				if(newDominoSharedFieldComponentPopup.wrapperBelongToProject==null){
					Alert.show("Please select a project that you want create the shread field!");
				}else{
					var dominoShareFieldFolderStr:String=newDominoSharedFieldComponentPopup.wrapperBelongToProject.projectFolder.nativePath +  model.fileCore.separator +"nsfs"+model.fileCore.separator+"nsf-moonshine"+model.fileCore.separator+"odp"+model.fileCore.separator+"SharedElements"+model.fileCore.separator+"Fields";
					var dominoShareFieldFolder:FileLocation=new FileLocation(dominoShareFieldFolderStr);
					if(!dominoShareFieldFolder.fileBridge.exists){
						dominoShareFieldFolder.fileBridge.createDirectory();
					}
				
				if(dominoShareFieldFolder.fileBridge.exists){
					//set the tree selct to domino form folder
					UtilsCore.wrappersFoundThroughFindingAWrapper = new Vector.<FileWrapper>();
					var dominoShareFieldFolderWrapper:FileWrapper = UtilsCore.findDominoFileWrapperInDepth(newDominoSharedFieldComponentPopup.wrapperBelongToProject.projectFolder, dominoShareFieldFolderStr);
					model.mainView.getTreeViewPanel().tree.callLater(function ():void
					{
						var wrappers:Vector.<FileWrapper> = UtilsCore.wrappersFoundThroughFindingAWrapper;
					
						for (var j:int = 0; j < (wrappers.length - 1); j++)
						{
							model.mainView.getTreeViewPanel().tree.expandItem(wrappers[j], true);
						}
		
						// selection
						model.mainView.getTreeViewPanel().tree.selectedItem = dominoShareFieldFolderWrapper;
						// scroll-to
						model.mainView.getTreeViewPanel().tree.callLater(function ():void
						{
							model.mainView.getTreeViewPanel().tree.scrollToIndex(model.mainView.getTreeViewPanel().tree.getItemIndex(dominoShareFieldFolderWrapper));
						});
					});
					
					
					//model.mainView.getTreeViewPanel().tree.selectedItem = dominoFormFolderWrapper;
					newDominoSharedFieldComponentPopup.wrapperOfFolderLocation = dominoShareFieldFolderWrapper;
					newDominoSharedFieldComponentPopup.folderLocation =dominoShareFieldFolder;
					PopUpManager.centerPopUp(newDominoSharedFieldComponentPopup);
					}else{
						Alert.show("Can't found the form folder from the project,please make sure it is ODP domino project!");
					}
				}
				
				
			}
		}

		public  function openDominoActionComponentTypeChoose(event:Event):void
		{

			
			var tmpOnDiskEvent:NewFileEvent=null;
			var insideLocation:FileWrapper =  model.mainView.getTreeViewPanel().tree.selectedItem as FileWrapper;
		
			if (insideLocation)
			{
				tmpOnDiskEvent = new NewFileEvent(
						NewFileEvent.EVENT_NEW_FILE, insideLocation.nativePath,
						ConstantsCoreVO.TEMPLATE_DOMINO_ACTION, insideLocation
				);
				tmpOnDiskEvent.ofProject = (event is NewFileEvent) ? (event as NewFileEvent).ofProject : model.activeProject;

				dispatcher.dispatchEvent(tmpOnDiskEvent);

				if (!newDominoActionComponentPopup)
				{
					newDominoActionComponentPopup = PopUpManager.createPopUp(FlexGlobals.topLevelApplication as DisplayObject, NewDominoActionPopup, true) as NewDominoActionPopup;
					newDominoActionComponentPopup.addEventListener(CloseEvent.CLOSE, handleDominoActionPopupClose);
					newDominoActionComponentPopup.addEventListener(NewFileEvent.EVENT_NEW_FILE, onDominoActionFileCreateRequest);
					//setting default folder or selected folder for new file
					if (tmpOnDiskEvent is NewFileEvent) 
					{
						
						newDominoActionComponentPopup.folderLocation = new FileLocation((tmpOnDiskEvent as NewFileEvent).filePath);
						newDominoActionComponentPopup.wrapperOfFolderLocation = (tmpOnDiskEvent as NewFileEvent).insideLocation;
						newDominoActionComponentPopup.wrapperBelongToProject = UtilsCore.getProjectFromProjectFolder((tmpOnDiskEvent as NewFileEvent).insideLocation);
						
					}
					else
					{
						
						
						// try to check if there is any selection in 
						// TreeView item
						
					}
					//only for fixed folder for domino form file
					var dominoActionFolderStr:String="";
					if(newDominoActionComponentPopup.wrapperBelongToProject){
						dominoActionFolderStr=newDominoActionComponentPopup.wrapperBelongToProject.projectFolder.nativePath +  model.fileCore.separator +"nsfs"+ model.fileCore.separator+"nsf-moonshine"+ model.fileCore.separator+"odp"+ model.fileCore.separator+"SharedElements"+ model.fileCore.separator+"Actions";
					}else{
						dominoActionFolderStr=model.activeProject.projectFolder.nativePath;
					}
					
					var dominoActionFolder:FileLocation=new FileLocation(dominoActionFolderStr);
					if(!dominoActionFolder.fileBridge.exists){
						dominoActionFolder.fileBridge.createDirectory();
					}
					
				
					
					if(dominoActionFolder.fileBridge.exists){
						//set the tree selct to domino form folder
						UtilsCore.wrappersFoundThroughFindingAWrapper = new Vector.<FileWrapper>();
						//Alert.show("insideLocation:"+insideLocation.file.fileBridge.nativePath);
						model.mainView.getTreeViewPanel().tree.callLater(function ():void
						{
							var wrappers:Vector.<FileWrapper> = UtilsCore.wrappersFoundThroughFindingAWrapper;
						
							for (var j:int = 0; j < (wrappers.length - 1); j++)
							{
								model.mainView.getTreeViewPanel().tree.expandItem(wrappers[j], true);
							}
			
							// selection
							model.mainView.getTreeViewPanel().tree.selectedItem = insideLocation;
							// scroll-to
							model.mainView.getTreeViewPanel().tree.callLater(function ():void
							{
								model.mainView.getTreeViewPanel().tree.scrollToIndex(model.mainView.getTreeViewPanel().tree.getItemIndex(insideLocation));
							});
						});
						
						
						//model.mainView.getTreeViewPanel().tree.selectedItem = dominoFormFolderWrapper;
						newDominoActionComponentPopup.wrapperOfFolderLocation = insideLocation;
						newDominoActionComponentPopup.folderLocation =dominoActionFolder;
						PopUpManager.centerPopUp(newDominoActionComponentPopup);
					}else{
						Alert.show("Can't found the form folder from the project,please make sure it is ODP domino project!");
					}
					
				}

			}
			else
			{
				Alert.show("Please select the project where the shared action should be created.");
				//error("error: Select location before creating a new file.");
			}
			
			
			
		}

		protected function openDominoViewShareColumnComponentTypeChoose(event:Event):void
		{
			if (!newDominoViewShareColumnPopup)
			{
				newDominoViewShareColumnPopup = PopUpManager.createPopUp(FlexGlobals.topLevelApplication as DisplayObject, NewDominoViewShareColumnPopup, true) as NewDominoViewShareColumnPopup;
				newDominoViewShareColumnPopup.addEventListener(CloseEvent.CLOSE, handleDominoViewShareColumnPopupClose);
				newDominoViewShareColumnPopup.addEventListener(NewFileEvent.EVENT_NEW_FILE, onDominoViewShareColumnFileCreateRequest);
                //setting default folder or selected folder for new file
			    if (event is NewFileEvent) 
				{
					newDominoViewShareColumnPopup.folderLocation = new FileLocation((event as NewFileEvent).filePath);
					newDominoViewShareColumnPopup.wrapperOfFolderLocation = (event as NewFileEvent).insideLocation;
					newDominoViewShareColumnPopup.wrapperBelongToProject = UtilsCore.getProjectFromProjectFolder((event as NewFileEvent).insideLocation);
				}
				else
				{
					// try to check if there is any selection in 
					// TreeView item
					var treeSelectedItem:FileWrapper = model.mainView.getTreeViewPanel().tree.selectedItem as FileWrapper;
					if (treeSelectedItem)
					{
						var creatingItemIn:FileWrapper = (treeSelectedItem.file.fileBridge.isDirectory) ? treeSelectedItem : FileWrapper(model.mainView.getTreeViewPanel().tree.getParentItem(treeSelectedItem));
						newDominoViewShareColumnPopup.folderLocation = creatingItemIn.file;
						newDominoViewShareColumnPopup.wrapperOfFolderLocation = creatingItemIn;
						newDominoViewShareColumnPopup.wrapperBelongToProject = UtilsCore.getProjectFromProjectFolder(creatingItemIn);
					}
				}
				//only for fixed folder for domino form file
			
			
				var dominoViewFolderStr:String=newDominoViewShareColumnPopup.wrapperBelongToProject.projectFolder.nativePath +  model.fileCore.separator +"nsfs"+model.fileCore.separator+"nsf-moonshine"+model.fileCore.separator+"odp"+model.fileCore.separator+"SharedElements"+model.fileCore.separator+"Columns";
				var dominoViewFolder:FileLocation=new FileLocation(dominoViewFolderStr);
				if(dominoViewFolder.fileBridge.exists){
					//set the tree selct to domino form folder
					UtilsCore.wrappersFoundThroughFindingAWrapper = new Vector.<FileWrapper>();
					var dominoViewFolderWrapper:FileWrapper = UtilsCore.findDominoFileWrapperInDepth(newDominoViewShareColumnPopup.wrapperBelongToProject.projectFolder, dominoViewFolderStr);
					model.mainView.getTreeViewPanel().tree.callLater(function ():void
					{
						var wrappers:Vector.<FileWrapper> = UtilsCore.wrappersFoundThroughFindingAWrapper;
					
						for (var j:int = 0; j < (wrappers.length - 1); j++)
						{
							model.mainView.getTreeViewPanel().tree.expandItem(wrappers[j], true);
						}
		
						// selection
						model.mainView.getTreeViewPanel().tree.selectedItem = dominoViewFolderWrapper;
						// scroll-to
						model.mainView.getTreeViewPanel().tree.callLater(function ():void
						{
							model.mainView.getTreeViewPanel().tree.scrollToIndex(model.mainView.getTreeViewPanel().tree.getItemIndex(dominoViewFolderWrapper));
						});
					});
					
					
					//model.mainView.getTreeViewPanel().tree.selectedItem = dominoFormFolderWrapper;
					newDominoViewShareColumnPopup.wrapperOfFolderLocation = dominoViewFolderWrapper;
					newDominoViewShareColumnPopup.folderLocation =dominoViewFolder;
					PopUpManager.centerPopUp(newDominoViewShareColumnPopup);
				}else{
					Alert.show("Can't found the form folder from the project,please make sure it is ODP domino project!");
				}
				
			}
		}


		protected function openDominoViewComponentTypeChoose(event:Event):void
		{
			if (!newDominoViewComponentPopup)
			{
				newDominoViewComponentPopup = PopUpManager.createPopUp(FlexGlobals.topLevelApplication as DisplayObject, NewDominoViewPopup, true) as NewDominoViewPopup;
				newDominoViewComponentPopup.addEventListener(CloseEvent.CLOSE, handleDominoViewPopupClose);
				newDominoViewComponentPopup.addEventListener(NewFileEvent.EVENT_NEW_FILE, onDominoViewFileCreateRequest);
                //setting default folder or selected folder for new file
			    if (event is NewFileEvent) 
				{
					newDominoViewComponentPopup.folderLocation = new FileLocation((event as NewFileEvent).filePath);
					newDominoViewComponentPopup.wrapperOfFolderLocation = (event as NewFileEvent).insideLocation;
					newDominoViewComponentPopup.wrapperBelongToProject = UtilsCore.getProjectFromProjectFolder((event as NewFileEvent).insideLocation);
				}
				else
				{
					// try to check if there is any selection in 
					// TreeView item
					var treeSelectedItem:FileWrapper = model.mainView.getTreeViewPanel().tree.selectedItem as FileWrapper;
					if (treeSelectedItem)
					{
						var creatingItemIn:FileWrapper = (treeSelectedItem.file.fileBridge.isDirectory) ? treeSelectedItem : FileWrapper(model.mainView.getTreeViewPanel().tree.getParentItem(treeSelectedItem));
						newDominoViewComponentPopup.folderLocation = creatingItemIn.file;
						newDominoViewComponentPopup.wrapperOfFolderLocation = creatingItemIn;
						newDominoViewComponentPopup.wrapperBelongToProject = UtilsCore.getProjectFromProjectFolder(creatingItemIn);
					}
				}
				//only for fixed folder for domino form file
			
			
				var dominoViewFolderStr:String=newDominoViewComponentPopup.wrapperBelongToProject.projectFolder.nativePath +  model.fileCore.separator +"nsfs"+model.fileCore.separator+"nsf-moonshine"+model.fileCore.separator+"odp"+model.fileCore.separator+"Views";
				var dominoViewFolder:FileLocation=new FileLocation(dominoViewFolderStr);
				if(dominoViewFolder.fileBridge.exists){
					//set the tree selct to domino form folder
					UtilsCore.wrappersFoundThroughFindingAWrapper = new Vector.<FileWrapper>();
					var dominoViewFolderWrapper:FileWrapper = UtilsCore.findDominoFileWrapperInDepth(newDominoViewComponentPopup.wrapperBelongToProject.projectFolder, dominoViewFolderStr);
					model.mainView.getTreeViewPanel().tree.callLater(function ():void
					{
						var wrappers:Vector.<FileWrapper> = UtilsCore.wrappersFoundThroughFindingAWrapper;
					
						for (var j:int = 0; j < (wrappers.length - 1); j++)
						{
							model.mainView.getTreeViewPanel().tree.expandItem(wrappers[j], true);
						}
		
						// selection
						model.mainView.getTreeViewPanel().tree.selectedItem = dominoViewFolderWrapper;
						// scroll-to
						model.mainView.getTreeViewPanel().tree.callLater(function ():void
						{
							model.mainView.getTreeViewPanel().tree.scrollToIndex(model.mainView.getTreeViewPanel().tree.getItemIndex(dominoViewFolderWrapper));
						});
					});
					
					
					//model.mainView.getTreeViewPanel().tree.selectedItem = dominoFormFolderWrapper;
					newDominoViewComponentPopup.wrapperOfFolderLocation = dominoViewFolderWrapper;
					newDominoViewComponentPopup.folderLocation =dominoViewFolder;
					PopUpManager.centerPopUp(newDominoViewComponentPopup);
				}else{
					Alert.show("Can't found the form folder from the project,please make sure it is ODP domino project!");
				}
				
			}
		}


		protected function openDominoPageComponentTypeChoose(event:Event):void
		{
			if (!newDominoPageComponentPopup)
			{
				newDominoPageComponentPopup = PopUpManager.createPopUp(FlexGlobals.topLevelApplication as DisplayObject, NewDominoPagePopup, true) as NewDominoPagePopup;
				newDominoPageComponentPopup.addEventListener(CloseEvent.CLOSE, handleDominoPagePopupClose);
				newDominoPageComponentPopup.addEventListener(NewFileEvent.EVENT_NEW_FILE, onDominoPageFileCreateRequest);
                //setting default folder or selected folder for new file
			    if (event is NewFileEvent) 
				{
					newDominoPageComponentPopup.folderLocation = new FileLocation((event as NewFileEvent).filePath);
					newDominoPageComponentPopup.wrapperOfFolderLocation = (event as NewFileEvent).insideLocation;
					newDominoPageComponentPopup.wrapperBelongToProject = UtilsCore.getProjectFromProjectFolder((event as NewFileEvent).insideLocation);
				}
				else
				{
					// try to check if there is any selection in 
					// TreeView item
					var treeSelectedItem:FileWrapper = model.mainView.getTreeViewPanel().tree.selectedItem as FileWrapper;
					if (treeSelectedItem)
					{
						var creatingItemIn:FileWrapper = (treeSelectedItem.file.fileBridge.isDirectory) ? treeSelectedItem : FileWrapper(model.mainView.getTreeViewPanel().tree.getParentItem(treeSelectedItem));
						newDominoPageComponentPopup.folderLocation = creatingItemIn.file;
						newDominoPageComponentPopup.wrapperOfFolderLocation = creatingItemIn;
						newDominoPageComponentPopup.wrapperBelongToProject = UtilsCore.getProjectFromProjectFolder(creatingItemIn);
					}
				}
				//only for fixed folder for domino form file
			
			
				var dominoPageFolderStr:String=newDominoPageComponentPopup.wrapperBelongToProject.projectFolder.nativePath +  model.fileCore.separator +"nsfs"+model.fileCore.separator+"nsf-moonshine"+model.fileCore.separator+"odp"+model.fileCore.separator+"Pages";
				var dominoPageFolder:FileLocation=new FileLocation(dominoPageFolderStr);
				if(dominoPageFolder.fileBridge.exists){
					//set the tree selct to domino form folder
					UtilsCore.wrappersFoundThroughFindingAWrapper = new Vector.<FileWrapper>();
					var dominoPageFolderWrapper:FileWrapper = UtilsCore.findDominoFileWrapperInDepth(newDominoPageComponentPopup.wrapperBelongToProject.projectFolder, dominoPageFolderStr);
					model.mainView.getTreeViewPanel().tree.callLater(function ():void
					{
						var wrappers:Vector.<FileWrapper> = UtilsCore.wrappersFoundThroughFindingAWrapper;
					
						for (var j:int = 0; j < (wrappers.length - 1); j++)
						{
							model.mainView.getTreeViewPanel().tree.expandItem(wrappers[j], true);
						}
		
						// selection
						model.mainView.getTreeViewPanel().tree.selectedItem = dominoPageFolderWrapper;
						// scroll-to
						model.mainView.getTreeViewPanel().tree.callLater(function ():void
						{
							model.mainView.getTreeViewPanel().tree.scrollToIndex(model.mainView.getTreeViewPanel().tree.getItemIndex(dominoPageFolderWrapper));
						});
					});
					
					
					//model.mainView.getTreeViewPanel().tree.selectedItem = dominoFormFolderWrapper;
					newDominoPageComponentPopup.wrapperOfFolderLocation = dominoPageFolderWrapper;
					newDominoPageComponentPopup.folderLocation =dominoPageFolder;
					PopUpManager.centerPopUp(newDominoPageComponentPopup);
				}else{
					Alert.show("Can't found the form folder from the project,please make sure it is ODP domino project!");
				}
				
			}
		}
		
		protected function openMXMLModuleTypeChoose(event:Event):void
		{
			if (!newMXMLModuleComponentPopup)
			{
				newMXMLModuleComponentPopup = PopUpManager.createPopUp(FlexGlobals.topLevelApplication as DisplayObject, NewMXMLGenericFilePopup, true) as NewMXMLGenericFilePopup;
				newMXMLModuleComponentPopup.title = "New MXML Module File";
				newMXMLModuleComponentPopup.fileTemplate = ConstantsCoreVO.TEMPLATE_MXML_MODULE;
				newMXMLModuleComponentPopup.addEventListener(CloseEvent.CLOSE, handleMXMLModulePopupClose);
				newMXMLModuleComponentPopup.addEventListener(NewFileEvent.EVENT_NEW_FILE, onMXMLModuleFileCreateRequest);
				
				// newFileEvent sends by TreeView when right-clicked 
				// context menu
				if (event is NewFileEvent) 
				{
					newMXMLModuleComponentPopup.folderLocation = new FileLocation((event as NewFileEvent).filePath);
					newMXMLModuleComponentPopup.wrapperOfFolderLocation = (event as NewFileEvent).insideLocation;
					newMXMLModuleComponentPopup.wrapperBelongToProject = UtilsCore.getProjectFromProjectFolder((event as NewFileEvent).insideLocation);
				}
				else
				{
					// try to check if there is any selection in 
					// TreeView item
					var treeSelectedItem:FileWrapper = model.mainView.getTreeViewPanel().tree.selectedItem as FileWrapper;
					if (treeSelectedItem)
					{
						var creatingItemIn:FileWrapper = (treeSelectedItem.file.fileBridge.isDirectory) ? treeSelectedItem : FileWrapper(model.mainView.getTreeViewPanel().tree.getParentItem(treeSelectedItem));
						newMXMLModuleComponentPopup.folderLocation = creatingItemIn.file;
						newMXMLModuleComponentPopup.wrapperOfFolderLocation = creatingItemIn;
						newMXMLModuleComponentPopup.wrapperBelongToProject = UtilsCore.getProjectFromProjectFolder(creatingItemIn);
					}
				}
				
				PopUpManager.centerPopUp(newMXMLModuleComponentPopup);
			}
		}
		
		protected function openNewComponentTypeChoose(event:Event, openType:String, fileTemplate:FileLocation=null):void
		{
			if (!newFilePopup)
			{
				newFilePopup = PopUpManager.createPopUp(FlexGlobals.topLevelApplication as DisplayObject, NewFilePopup, true) as NewFilePopup;
				newFilePopup.addEventListener(CloseEvent.CLOSE, handleFilePopupClose);
				newFilePopup.addEventListener(NewFileEvent.EVENT_NEW_FILE, onFileCreateRequest);
				newFilePopup.openType = openType;
				newFilePopup.fileTemplate = fileTemplate;
				
				// newFileEvent sends by TreeView when right-clicked 
				// context menu
				if (event is NewFileEvent) 
				{
					newFilePopup.wrapperOfFolderLocation = (event as NewFileEvent).insideLocation;
					newFilePopup.wrapperBelongToProject = UtilsCore.getProjectFromProjectFolder((event as NewFileEvent).insideLocation);
				}
				else
				{
					// try to check if there is any selection in 
					// TreeView item
					var treeSelectedItem:FileWrapper = model.mainView.getTreeViewPanel().tree.selectedItem as FileWrapper;
					if (treeSelectedItem)
					{
						var creatingItemIn:FileWrapper = (treeSelectedItem.file.fileBridge.isDirectory) ? treeSelectedItem : FileWrapper(model.mainView.getTreeViewPanel().tree.getParentItem(treeSelectedItem));
						newFilePopup.wrapperOfFolderLocation = creatingItemIn;
						newFilePopup.wrapperBelongToProject = UtilsCore.getProjectFromProjectFolder(creatingItemIn);
					}
				}
				//Alert.show("wrapperOfFolderLocation:"+ newFilePopup.wrapperOfFolderLocation.nativePath);
				var eventName:String = event.type.substr(24)
				if(eventName){
					if(eventName=="Domino Visual Editor Form" ||eventName=="Domino Visual Editor Page"  ){
						if(newFilePopup.wrapperBelongToProject){
							(newFilePopup.wrapperBelongToProject as IVisualEditorProjectVO).isDominoVisualEditorProject = true;
							//Alert.show("Domino Visual set to true");
						}
						
					}
				}
				
				PopUpManager.centerPopUp(newFilePopup);
			}
		}
		
		protected function handleFilePopupClose(event:CloseEvent):void
		{
			newFilePopup.removeEventListener(CloseEvent.CLOSE, handleFilePopupClose);
			newFilePopup.removeEventListener(NewFileEvent.EVENT_NEW_FILE, onFileCreateRequest);
			newFilePopup = null;
		}
		
		protected function handleCSSPopupClose(event:CloseEvent):void
		{
			newCSSComponentPopup.removeEventListener(CloseEvent.CLOSE, handleCSSPopupClose);
			newCSSComponentPopup.removeEventListener(NewFileEvent.EVENT_NEW_FILE, onCSSFileCreateRequest);
			newCSSComponentPopup = null;
		}

		protected function handleDominoFormPopupClose(event:CloseEvent):void
		{
			newDominoFormComponentPopup.removeEventListener(CloseEvent.CLOSE, handleDominoFormPopupClose);
			newDominoFormComponentPopup.removeEventListener(NewFileEvent.EVENT_NEW_FILE, onDominoFormFileCreateRequest);
			newDominoFormComponentPopup = null;
		}


		protected function handleDominoViewPopupClose(event:CloseEvent):void
		{
			newDominoViewComponentPopup.removeEventListener(CloseEvent.CLOSE, handleDominoViewPopupClose);
			newDominoViewComponentPopup.removeEventListener(NewFileEvent.EVENT_NEW_FILE, onDominoViewFileCreateRequest);
			newDominoViewComponentPopup = null;
		}

		protected function handleDominoViewShareColumnPopupClose(event:CloseEvent):void
		{
			newDominoViewShareColumnPopup.removeEventListener(CloseEvent.CLOSE, handleDominoViewShareColumnPopupClose);
			newDominoViewShareColumnPopup.removeEventListener(NewFileEvent.EVENT_NEW_FILE, onDominoViewShareColumnFileCreateRequest);
			newDominoViewShareColumnPopup = null;
		}

		protected function handleDominoPagePopupClose(event:CloseEvent):void
		{
			newDominoPageComponentPopup.removeEventListener(CloseEvent.CLOSE, handleDominoPagePopupClose);
			newDominoPageComponentPopup.removeEventListener(NewFileEvent.EVENT_NEW_FILE, onDominoPageFileCreateRequest);
			newDominoPageComponentPopup = null;
		}

		protected function handleDominoSubformPopupClose(event:CloseEvent):void
		{
			newDominoSubformComponentPopup.removeEventListener(CloseEvent.CLOSE, handleDominoSubformPopupClose);
			newDominoSubformComponentPopup.removeEventListener(NewFileEvent.EVENT_NEW_FILE, onDominoSubformFileCreateRequest);
			newDominoSubformComponentPopup = null;
		}


		protected function handleDominoShareFieldPopupClose(event:CloseEvent):void
		{
			newDominoSharedFieldComponentPopup.removeEventListener(CloseEvent.CLOSE, handleDominoShareFieldPopupClose);
			newDominoSharedFieldComponentPopup.removeEventListener(NewFileEvent.EVENT_NEW_FILE, onDominoSharedFieldFileCreateRequest);
			newDominoSharedFieldComponentPopup = null;
		}


		protected function handleDominoActionPopupClose(event:CloseEvent):void
		{
			newDominoActionComponentPopup.removeEventListener(CloseEvent.CLOSE, handleDominoActionPopupClose);
			newDominoActionComponentPopup.removeEventListener(NewFileEvent.EVENT_NEW_FILE, onDominoActionFileCreateRequest);
			newDominoActionComponentPopup = null;
		}


		
		
		protected function handleMXMLModulePopupClose(event:CloseEvent):void
		{
			newMXMLModuleComponentPopup.removeEventListener(CloseEvent.CLOSE, handleMXMLModulePopupClose);
			newMXMLModuleComponentPopup.removeEventListener(NewFileEvent.EVENT_NEW_FILE, onMXMLModuleFileCreateRequest);
			newMXMLModuleComponentPopup = null;
		}
		
		protected function handleMXMLPopupClose(event:CloseEvent):void
		{
			newMXMLComponentPopup.removeEventListener(CloseEvent.CLOSE, handleMXMLPopupClose);
			newMXMLComponentPopup.removeEventListener(NewFileEvent.EVENT_NEW_FILE, onMXMLFileCreateRequest);
			newMXMLComponentPopup = null;
		}

        protected function handleNewVisualEditorFilePopupClose(event:CloseEvent):void
        {
            newVisualEditorFilePopup.removeEventListener(CloseEvent.CLOSE, handleNewVisualEditorFilePopupClose);
            newVisualEditorFilePopup = null;
        }

		protected function openAS3ComponentTypeChoose(event:Event, isInterfaceDialog:Boolean):void
		{
			if (!newAS3ComponentPopup)
			{
				newAS3ComponentPopup = PopUpManager.createPopUp(FlexGlobals.topLevelApplication as DisplayObject, NewASFilePopup, true) as NewASFilePopup;
				newAS3ComponentPopup.addEventListener(CloseEvent.CLOSE, handleAS3PopupClose);
				newAS3ComponentPopup.addEventListener(NewFileEvent.EVENT_NEW_FILE, isInterfaceDialog ? onNewInterfaceCreateRequest : onNewFileCreateRequest);
				newAS3ComponentPopup.isInterfaceDialog = isInterfaceDialog;
				
				// newFileEvent sends by TreeView when right-clicked 
				// context menu
				if (event is NewFileEvent) 
				{
					newAS3ComponentPopup.folderLocation = new FileLocation((event as NewFileEvent).filePath);
					newAS3ComponentPopup.wrapperOfFolderLocation = (event as NewFileEvent).insideLocation;
					newAS3ComponentPopup.wrapperBelongToProject = UtilsCore.getProjectFromProjectFolder((event as NewFileEvent).insideLocation);
				}
				else
				{
					// try to check if there is any selection in 
					// TreeView item
					var treeSelectedItem:FileWrapper = model.mainView.getTreeViewPanel().tree.selectedItem as FileWrapper;
					if (treeSelectedItem)
					{
						var creatingItemIn:FileWrapper = (treeSelectedItem.file.fileBridge.isDirectory) ? treeSelectedItem : FileWrapper(model.mainView.getTreeViewPanel().tree.getParentItem(treeSelectedItem));
						newAS3ComponentPopup.folderLocation = creatingItemIn.file;
						newAS3ComponentPopup.wrapperOfFolderLocation = creatingItemIn;
						newAS3ComponentPopup.wrapperBelongToProject = UtilsCore.getProjectFromProjectFolder(creatingItemIn);
					}
				}
				
				PopUpManager.centerPopUp(newAS3ComponentPopup);
			}
		}
		
		protected function handleAS3PopupClose(event:CloseEvent):void
		{
			newAS3ComponentPopup.removeEventListener(CloseEvent.CLOSE, handleAS3PopupClose);
			newAS3ComponentPopup.removeEventListener(NewFileEvent.EVENT_NEW_FILE, onNewFileCreateRequest);
			newAS3ComponentPopup.removeEventListener(NewFileEvent.EVENT_NEW_FILE, onNewInterfaceCreateRequest);
			newAS3ComponentPopup = null;
		}

		protected function handleJavaPopupClose(event:CloseEvent):void
		{
			newJavaComponentPopup.removeEventListener(CloseEvent.CLOSE, handleJavaPopupClose);
			newJavaComponentPopup.removeEventListener(NewFileEvent.EVENT_NEW_FILE, onNewFileCreateRequest);
			newJavaComponentPopup.removeEventListener(NewFileEvent.EVENT_NEW_FILE, onNewInterfaceCreateRequest);
			newJavaComponentPopup = null;
		}

		protected function handleGroovyPopupClose(event:CloseEvent):void
		{
			newGroovyComponentPopup.removeEventListener(CloseEvent.CLOSE, handleGroovyPopupClose);
			newGroovyComponentPopup.removeEventListener(NewFileEvent.EVENT_NEW_FILE, onNewFileCreateRequest);
			newGroovyComponentPopup.removeEventListener(NewFileEvent.EVENT_NEW_FILE, onNewInterfaceCreateRequest);
			newGroovyComponentPopup = null;
		}

		protected function handleHaxePopupClose(event:CloseEvent):void
		{
			newHaxeComponentPopup.removeEventListener(CloseEvent.CLOSE, handleHaxePopupClose);
			newHaxeComponentPopup.removeEventListener(NewFileEvent.EVENT_NEW_FILE, onNewFileCreateRequest);
			newHaxeComponentPopup.removeEventListener(NewFileEvent.EVENT_NEW_FILE, onNewInterfaceCreateRequest);
			newHaxeComponentPopup = null;
		}

		protected function openJavaTypeChoose(event:Event, isInterfaceDialog:Boolean):void
		{
			if (!newJavaComponentPopup)
			{
				newJavaComponentPopup = new NewJavaFilePopup();
				newJavaComponentPopup.addEventListener(CloseEvent.CLOSE, handleJavaPopupClose);
				newJavaComponentPopup.addEventListener(NewFileEvent.EVENT_NEW_FILE, isInterfaceDialog ? onNewInterfaceCreateRequest : onNewFileCreateRequest);
				newJavaComponentPopup.isInterfaceDialog = isInterfaceDialog;
				newJavaComponentPopup.templateJavaClass = templateJavaClass;
				newJavaComponentPopup.templateJavaInterface = templateJavaInterface;
				PopUpManager.addPopUp(newJavaComponentPopup, FlexGlobals.topLevelApplication as DisplayObject, true);

				// newFileEvent sends by TreeView when right-clicked
				// context menu
				if (event is NewFileEvent)
				{
					newJavaComponentPopup.folderLocation = new FileLocation((event as NewFileEvent).filePath);
					newJavaComponentPopup.wrapperOfFolderLocation = (event as NewFileEvent).insideLocation;
					newJavaComponentPopup.wrapperBelongToProject = UtilsCore.getProjectFromProjectFolder((event as NewFileEvent).insideLocation);
				}
				else
				{
					// try to check if there is any selection in
					// TreeView item
					var treeSelectedItem:FileWrapper = model.mainView.getTreeViewPanel().tree.selectedItem as FileWrapper;
					if (treeSelectedItem)
					{
						var creatingItemIn:FileWrapper = (treeSelectedItem.file.fileBridge.isDirectory) ? treeSelectedItem : FileWrapper(model.mainView.getTreeViewPanel().tree.getParentItem(treeSelectedItem));
						newJavaComponentPopup.folderLocation = creatingItemIn.file;
						newJavaComponentPopup.wrapperOfFolderLocation = creatingItemIn;
						newJavaComponentPopup.wrapperBelongToProject = UtilsCore.getProjectFromProjectFolder(creatingItemIn);
					}
				}

				PopUpManager.centerPopUp(newJavaComponentPopup);
			}
		}
		
		protected function openGroovyTypeChoose(event:Event, isInterfaceDialog:Boolean):void
		{
			if (!newGroovyComponentPopup)
			{
				newGroovyComponentPopup = new NewGroovyFilePopup();
				newGroovyComponentPopup.addEventListener(CloseEvent.CLOSE, handleGroovyPopupClose);
				newGroovyComponentPopup.addEventListener(NewFileEvent.EVENT_NEW_FILE, isInterfaceDialog ? onNewInterfaceCreateRequest : onNewFileCreateRequest);
				newGroovyComponentPopup.isInterfaceDialog = isInterfaceDialog;
				newGroovyComponentPopup.templateGroovyClass = templateGroovyClass;
				newGroovyComponentPopup.templateGroovyInterface = templateGroovyInterface;
				PopUpManager.addPopUp(newGroovyComponentPopup, FlexGlobals.topLevelApplication as DisplayObject, true);

				// newFileEvent sends by TreeView when right-clicked
				// context menu
				if (event is NewFileEvent)
				{
					newGroovyComponentPopup.folderLocation = new FileLocation((event as NewFileEvent).filePath);
					newGroovyComponentPopup.wrapperOfFolderLocation = (event as NewFileEvent).insideLocation;
					newGroovyComponentPopup.wrapperBelongToProject = UtilsCore.getProjectFromProjectFolder((event as NewFileEvent).insideLocation);
				}
				else
				{
					// try to check if there is any selection in
					// TreeView item
					var treeSelectedItem:FileWrapper = model.mainView.getTreeViewPanel().tree.selectedItem as FileWrapper;
					if (treeSelectedItem)
					{
						var creatingItemIn:FileWrapper = (treeSelectedItem.file.fileBridge.isDirectory) ? treeSelectedItem : FileWrapper(model.mainView.getTreeViewPanel().tree.getParentItem(treeSelectedItem));
						newGroovyComponentPopup.folderLocation = creatingItemIn.file;
						newGroovyComponentPopup.wrapperOfFolderLocation = creatingItemIn;
						newGroovyComponentPopup.wrapperBelongToProject = UtilsCore.getProjectFromProjectFolder(creatingItemIn);
					}
				}

				PopUpManager.centerPopUp(newGroovyComponentPopup);
			}
		}

		protected function openHaxeTypeChoose(event:Event, isInterfaceDialog:Boolean):void
		{
			if (!newHaxeComponentPopup)
			{
				newHaxeComponentPopup = new NewHaxeFilePopup();
				newHaxeComponentPopup.addEventListener(CloseEvent.CLOSE, handleHaxePopupClose);
				newHaxeComponentPopup.addEventListener(NewFileEvent.EVENT_NEW_FILE, isInterfaceDialog ? onNewInterfaceCreateRequest : onNewFileCreateRequest);
				newHaxeComponentPopup.isInterfaceDialog = isInterfaceDialog;
				newHaxeComponentPopup.templateHaxeClass = templateHaxeClass;
				newHaxeComponentPopup.templateHaxeInterface = templateHaxeInterface;
				PopUpManager.addPopUp(newHaxeComponentPopup, FlexGlobals.topLevelApplication as DisplayObject, true);

				// newFileEvent sends by TreeView when right-clicked
				// context menu
				if (event is NewFileEvent)
				{
					newHaxeComponentPopup.folderLocation = new FileLocation((event as NewFileEvent).filePath);
					newHaxeComponentPopup.wrapperOfFolderLocation = (event as NewFileEvent).insideLocation;
					newHaxeComponentPopup.wrapperBelongToProject = UtilsCore.getProjectFromProjectFolder((event as NewFileEvent).insideLocation);
				}
				else
				{
					// try to check if there is any selection in
					// TreeView item
					var treeSelectedItem:FileWrapper = model.mainView.getTreeViewPanel().tree.selectedItem as FileWrapper;
					if (treeSelectedItem)
					{
						var creatingItemIn:FileWrapper = (treeSelectedItem.file.fileBridge.isDirectory) ? treeSelectedItem : FileWrapper(model.mainView.getTreeViewPanel().tree.getParentItem(treeSelectedItem));
						newHaxeComponentPopup.folderLocation = creatingItemIn.file;
						newHaxeComponentPopup.wrapperOfFolderLocation = creatingItemIn;
						newHaxeComponentPopup.wrapperBelongToProject = UtilsCore.getProjectFromProjectFolder(creatingItemIn);
					}
				}

				PopUpManager.centerPopUp(newHaxeComponentPopup);
			}
		}
		
		protected function onNewFileCreateRequest(event:NewFileEvent):void
		{
			checkAndUpdateIfTemplateModified(event);
			if (event.fromTemplate.fileBridge.exists)
			{
				var content:String = String(event.fromTemplate.fileBridge.read());
				var pattern:RegExp = new RegExp(TextUtil.escapeRegex("$fileName"), "g");
				var as3FileAttributes:AS3ClassAttributes = event.extraParameters[0] as AS3ClassAttributes;

				content = content.replace(pattern, getNestingClassName(event.fileName));

				var packagePath:String = (event.ofProject.hasOwnProperty("classpaths")) ?
						UtilsCore.getPackageReferenceByProjectPath(event.ofProject["classpaths"], getNestedPackagePath(event.fileName, event.insideLocation.nativePath), null, null, false) : "";
				if (packagePath != "")
				{
					packagePath = packagePath.substr(1, packagePath.length);
				} // removing . at index 0
				else
				{
					if (event.fileExtension == ".java")
					{
						content = content.replace("package", "");
						content = content.replace(";", "");
					}
					if (event.fileExtension == ".groovy")
					{
						content = content.replace("package", "");
					}
					if (event.fileExtension == ".hx")
					{
						content = content.replace("package", "");
						content = content.replace(";", "");
					}
				}

				content = content.replace("$packageName", packagePath);
				content = content.replace("$imports", as3FileAttributes.getImports());
				content = content.replace("$modifierA", as3FileAttributes.modifierA);

				var tmpModifierBData:String = as3FileAttributes.getModifiersB();
				content = content.replace(((tmpModifierBData != "") ? "$modifierB" : "$modifierB "), tmpModifierBData);

				var extendClass:String = as3FileAttributes.extendsClassInterface;
				content = content.replace("$extends", extendClass ? "extends " + extendClass : "");

                var implementsInterface:String = as3FileAttributes.implementsInterface;
                content = content.replace("$implements", implementsInterface ? "implements " + implementsInterface : "");

                content = StringUtil.trim(content);

				var fileToSave:FileLocation = new FileLocation(event.insideLocation.nativePath + event.fromTemplate.fileBridge.separator + event.fileName + event.fileExtension);
				fileToSave.fileBridge.save(content);

                notifyNewFileCreated(event.insideLocation, fileToSave);
			}
		}
		
		protected function onNewInterfaceCreateRequest(event:NewFileEvent):void
		{
			checkAndUpdateIfTemplateModified(event);
			if (event.fromTemplate.fileBridge.exists)
			{
				var content:String = String(event.fromTemplate.fileBridge.read());
				var pattern:RegExp = new RegExp(TextUtil.escapeRegex("$fileName"), "g");
                var as3InterfaceAttributes:AS3ClassAttributes = event.extraParameters[0] as AS3ClassAttributes;

				content = content.replace(pattern, getNestingClassName(event.fileName));
				
				var packagePath:String = UtilsCore.getPackageReferenceByProjectPath(event.ofProject["classpaths"], getNestedPackagePath(event.fileName, event.insideLocation.nativePath), null, null, false);
				if (packagePath != "") packagePath = packagePath.substr(1, packagePath.length); // removing . at index 0
				content = content.replace("$packageName", packagePath);
                content = content.replace("$imports", as3InterfaceAttributes.getImports());
				content = content.replace("$modifierA", as3InterfaceAttributes.modifierA);

                var extendClass:String = as3InterfaceAttributes.implementsInterface;
                content = content.replace("$extends", extendClass ? "extends " + extendClass : "");

				var fileToSave:FileLocation = new FileLocation(event.insideLocation.nativePath + event.fromTemplate.fileBridge.separator + event.fileName + event.fileExtension);
				fileToSave.fileBridge.save(content);

                notifyNewFileCreated(event.insideLocation, fileToSave);
			}
		}

		protected function onMXMLFileCreateRequest(event:NewFileEvent):FileLocation
		{
			checkAndUpdateIfTemplateModified(event);
			if (event.fromTemplate.fileBridge.exists)
			{
				var content:String = String(event.fromTemplate.fileBridge.read());
				var fileToSave:FileLocation = new FileLocation(event.insideLocation.nativePath + event.fromTemplate.fileBridge.separator + event.fileName +".mxml");
				fileToSave.fileBridge.save(content);

                notifyNewFileCreated(event.insideLocation, fileToSave);
				return fileToSave;
			}
			
			return null;
		}
		
		protected function onMXMLModuleFileCreateRequest(event:NewFileEvent):void
		{
			if (event.fromTemplate.fileBridge.exists)
			{
				var tmpFile:FileLocation = onMXMLFileCreateRequest(event);
				if (tmpFile)
				{
					dispatcher.dispatchEvent(new ASModulesEvent(ASModulesEvent.EVENT_ADD_MODULE, tmpFile, (event.ofProject as AS3ProjectVO)));
				}
			}
		}
		
		protected function onFileCreateRequest(event:NewFileEvent):void
		{
			checkAndUpdateIfTemplateModified(event);
			if (event.fromTemplate.fileBridge.exists)
			{
				var isCustomExtension:Boolean = newFilePopup.openType == NewFilePopup.AS_PLAIN_TEXT;
				
				var content:String = String(event.fromTemplate.fileBridge.read());
				var tmpArr:Array = event.fromTemplate.fileBridge.name.split(".");
				var fileToSave:FileLocation = new FileLocation(event.insideLocation.nativePath + event.fromTemplate.fileBridge.separator + event.fileName + 
					(isCustomExtension ? "" : "."+ tmpArr[tmpArr.length - 2]));
				fileToSave.fileBridge.save(content);

                notifyNewFileCreated(event.insideLocation, fileToSave);
			}
		}

        protected function onVisualEditorFileCreateRequest(event:NewFileEvent):void
        {
			checkAndUpdateIfTemplateModified(event);
            if (event.fromTemplate.fileBridge.exists)
            {
                var content:String = String(event.fromTemplate.fileBridge.read());
				var extension:String = ".mxml";
				var project:AS3ProjectVO = event.ofProject as AS3ProjectVO;
				var shallNotifyToTree:Boolean = true;
				
				// to handle event relay in custom way in case of
				// auto-xhtml-file-generation - this will not relay the
				// immediate event to treeview
				if (event.extraParameters.length != 0 && ('relayEvent' in event.extraParameters[0]))
				{
					shallNotifyToTree = event.extraParameters[0].relayEvent;
				}
				
				if (project && project.isPrimeFacesVisualEditorProject)
				{
                    extension = ".xhtml";
                    var fileToSave:FileLocation = new FileLocation(event.insideLocation.nativePath + event.fromTemplate.fileBridge.separator + event.fileName + extension);

                    var primeFacesXML:XML = new XML(content);
					var hNamespace:Namespace = primeFacesXML.namespace("h");
					var head:XMLList = primeFacesXML..hNamespace::["head"];
					if (head.length() > 0)
					{
						var headXML:XML = head[0];
                        var cssStyleSheetXml:XML = new XML("<link></link>");
                        cssStyleSheetXml.@rel = "stylesheet";
                        cssStyleSheetXml.@type = "text/css";
                        cssStyleSheetXml.@href = "resources/moonshine-layout-styles.css";

                        headXML.appendChild(cssStyleSheetXml);

                        var relativeFilePath:String = fileToSave.fileBridge.getRelativePath(project.folderLocation, true);
                        cssStyleSheetXml = new XML("<link></link>");
                        cssStyleSheetXml.@rel = "stylesheet";
                        cssStyleSheetXml.@type = "text/css";
                        cssStyleSheetXml.@href = relativeFilePath + "/assets/moonshine-layout-styles.css";

                        headXML.appendChild(cssStyleSheetXml);
                        var markAsXml:String = "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n";

						content = markAsXml + primeFacesXML.toXMLString();
					}
				}
				else
				{
                    fileToSave = new FileLocation(event.insideLocation.nativePath + event.fromTemplate.fileBridge.separator + event.fileName + extension);
				}

                fileToSave.fileBridge.save(content);
				if (shallNotifyToTree) notifyNewFileCreated(event.insideLocation, fileToSave, event.isOpenAfterCreate);
            }
        }

		protected function onCSSFileCreateRequest(event:NewFileEvent):void
		{
			checkAndUpdateIfTemplateModified(event);
			if (event.fromTemplate.fileBridge.exists)
			{
				var content:String = String(event.fromTemplate.fileBridge.read());
				var fileToSave:FileLocation = new FileLocation(event.insideLocation.nativePath + event.fromTemplate.fileBridge.separator + event.fileName +".css");
				fileToSave.fileBridge.save(content);

                notifyNewFileCreated(event.insideLocation, fileToSave);
			}
		}

		protected function onDominoFormFileCreateRequest(event:NewFileEvent):void
		{
			checkAndUpdateIfTemplateModified(event);
			if (event.fromTemplate.fileBridge.exists)
			{
				var content:String = String(event.fromTemplate.fileBridge.read());
				var fileToSave:FileLocation = new FileLocation(event.insideLocation.nativePath + event.fromTemplate.fileBridge.separator + event.fileName +".form");
				fileToSave.fileBridge.save(content);

				//create the view for each form 
				var parent:FileLocation=event.fromTemplate.fileBridge.parent;
				var viewTemplate:FileLocation=new FileLocation(parent.fileBridge.nativePath+parent.fileBridge.separator+"domino"+parent.fileBridge.separator+"All By UNID_5cCRUD_5c%form%.view");

				if(viewTemplate.fileBridge.exists){
					var viewFolder:FileLocation= fileToSave.fileBridge.parent;
					viewFolder=viewFolder.fileBridge.parent;
				
					var viewfileToSave:FileLocation = new FileLocation( viewFolder.fileBridge.nativePath+ event.fromTemplate.fileBridge.separator+"Views"+ event.fromTemplate.fileBridge.separator+ "All By UNID_5cCRUD_5c"+TextUtil.htmlEscape(event.fileName) +".view");
					if(!viewfileToSave.fileBridge.exists){
						var viewcontent:String = String(viewTemplate.fileBridge.read());
						var re:RegExp = new RegExp("%form%", "g");
						viewcontent = viewcontent.replace(re, event.fileName);
						viewfileToSave.fileBridge.save(viewcontent);
					}
					

				}

                notifyNewFileCreated(event.insideLocation, fileToSave);
			}
			

		}

		protected function onDominoPageFileCreateRequest(event:NewFileEvent):void
		{
			checkAndUpdateIfTemplateModified(event);
			if (event.fromTemplate.fileBridge.exists)
			{
				var content:String = String(event.fromTemplate.fileBridge.read());
				
				//replace page name 
				content=content.replace(/\$Domino_Visual_Editor_Page/g,event.fileName);
				
				var fileToSave:FileLocation = new FileLocation(event.insideLocation.nativePath + event.fromTemplate.fileBridge.separator + event.fileName +".page");
				fileToSave.fileBridge.save(content);

                notifyNewFileCreated(event.insideLocation, fileToSave);
			}
		}

		protected function onDominoSubformFileCreateRequest(event:NewFileEvent):void
		{
			checkAndUpdateIfTemplateModified(event);
			if (event.fromTemplate.fileBridge.exists)
			{
				var content:String = String(event.fromTemplate.fileBridge.read());
				var replaceName:String= TextUtil.fixDominoViewName(event.fileName);
			
				var sourceSubformNameFormat:String= TextUtil.toDominoViewNormalName(replaceName);
				content=content.replace("Domino Visual Editor Sub Form",sourceSubformNameFormat);
				
				var fileToSave:FileLocation = new FileLocation(event.insideLocation.nativePath + event.fromTemplate.fileBridge.separator + replaceName +".subform");
				fileToSave.fileBridge.save(content);

                notifyNewFileCreated(event.insideLocation, fileToSave);
			}
		}

		protected function onDominoViewFileCreateRequest(event:NewFileEvent):void
		{
			checkAndUpdateIfTemplateModified(event);
			if (event.fromTemplate.fileBridge.exists)
			{
				var content:String = String(event.fromTemplate.fileBridge.read());
				//replace \  to 5c from view name
				
				var replaceName:String= TextUtil.fixDominoViewName(event.fileName);
				//replace the view name to file name:
				var sourceViewNameFormat:String= TextUtil.toDominoViewNormalName(replaceName);
				content=content.replace("$ViewName",sourceViewNameFormat);
				
				var fileToSave:FileLocation = new FileLocation(event.insideLocation.nativePath + event.fromTemplate.fileBridge.separator + replaceName +".view");
				fileToSave.fileBridge.save(content);

                notifyNewFileCreated(event.insideLocation, fileToSave);
			}
		}

		protected function onDominoViewShareColumnFileCreateRequest(event:NewFileEvent):void
		{
			checkAndUpdateIfTemplateModified(event);
			if (event.fromTemplate.fileBridge.exists)
			{
				var content:String = String(event.fromTemplate.fileBridge.read());
				//replace \  to 5c from view name
				
				var replaceName:String= TextUtil.fixDominoViewName(event.fileName);
				
				var replaceNameSplitList:Array=replaceName.split("_5c");
				var sharedColumnName:String="";
				if(replaceNameSplitList.length>1){
					sharedColumnName=replaceNameSplitList[replaceNameSplitList.length-1];
				}else{
					sharedColumnName=replaceNameSplitList[0];
				}
				//replace the view name to file name:
				var sourceViewNameFormat:String= TextUtil.toDominoViewNormalName(replaceName);
				content=content.replace("$ColumnName",sourceViewNameFormat);
				content=content.replace("$SharedColumnName",sharedColumnName);
				
				var fileToSave:FileLocation = new FileLocation(event.insideLocation.nativePath + event.fromTemplate.fileBridge.separator + replaceName +".column");
				fileToSave.fileBridge.save(content);

                notifyNewFileCreated(event.insideLocation, fileToSave);
			}
		}

		protected function onDominoSharedFieldFileCreateRequest(event:NewFileEvent):void
		{
			checkAndUpdateIfTemplateModified(event);
			if (event.fromTemplate.fileBridge.exists)
			{
				var content:String = String(event.fromTemplate.fileBridge.read());
				var fileToSave:FileLocation = new FileLocation(event.insideLocation.nativePath + event.fromTemplate.fileBridge.separator + event.fileName +".field");
				fileToSave.fileBridge.save(content);

                notifyNewFileCreated(event.insideLocation, fileToSave);
			}
		}

		protected function onDominoActionFileCreateRequest(event:NewFileEvent):void
		{
			checkAndUpdateIfTemplateModified(event);
			if (event.fromTemplate.fileBridge.exists)
			{
				var content:String = String(event.fromTemplate.fileBridge.read());
				var fileToSave:FileLocation = new FileLocation(event.insideLocation.nativePath + event.fromTemplate.fileBridge.separator + event.fileName +".view");
				//action name contain some specail character , so , we need base64 encode in here
				var fileName:String =event.fileName;
				fileName=fileName.replace( /\\/g, '%5C');
				fileName=fileName.replace( /\//g, '%2F');
				fileToSave = new FileLocation(event.insideLocation.nativePath + event.fromTemplate.fileBridge.separator + event.fileName +".action");
				
				content=updateDominoActionTitleName(content,event.fileName);
				fileToSave.fileBridge.save(content);

                notifyNewFileCreated(event.insideLocation, fileToSave);
			}
		}

		private function updateDominoActionTitleName(content:String,titleName:String):String
		{
			var actionXml:XML = new XML(content);
			var sourceTitle:String=actionXml.@title;
			if(sourceTitle!=titleName){
				actionXml.@title=titleName;
			}

			return actionXml.toXMLString();
		}




		protected function handleNewProjectFile(event:Event):void
		{
            newProjectFromTemplate(event.type);
		}
		
		private function filterProjectsTemplates(item:TemplateVO, index:int, arr:Array):Boolean
		{
			return item.displayHome;
		}

        private function handleExportNewProjectFromTemplate(event:ExportVisualEditorProjectEvent):void
        {
			newProjectFromTemplate("eventNewProjectFromTemplateFlex Desktop Project (MacOS, Windows)", event.exportedProject);
        }

        private function newProjectFromTemplate(eventName:String, exportProject:AS3ProjectVO = null):void
        {
            if (ConstantsCoreVO.IS_AIR)
            {
                eventName = eventName.substr(27);
                if(eventName == "HaXe SWF Project")
                {
                    Alert.show("coming shortly");
                    return;
                }
                // Figure out which menu item was clicked (add extra data var to MenuPlugin/event dispatching?)
                for each (var projectTemplate:FileLocation in projectTemplates)
                {
                    if ( TemplatingHelper.getTemplateLabel(projectTemplate) == eventName )
                    {
                        var extension:String = null;
                        var settingsFile:FileLocation = null;

                        settingsFile = getSettingsTemplateFileLocation(projectTemplate);
                        extension = settingsFile ? TemplatingHelper.getExtension(settingsFile) : null;

                        dispatcher.dispatchEvent(new NewProjectEvent(NewProjectEvent.CREATE_NEW_PROJECT,
                                extension, settingsFile, projectTemplate, exportProject));
                        break;
                    }
                }
            }
            else
            {
                dispatcher.dispatchEvent(
                        new NewProjectEvent(NewProjectEvent.CREATE_NEW_PROJECT, eventName, null, null)
                );
            }
        }

        public static function getSettingsTemplateFileLocation(projectDir:FileLocation):FileLocation
        {
            // TODO: If none is found, prompt user for location to save project & template it over
            var files:Array = projectDir.fileBridge.getDirectoryListing();

            for each (var file:Object in files)
            {
                if (!file.isDirectory)
                {
                    if (file.name.indexOf("$Settings.") == 0)
                    {
                        return new FileLocation(file.nativePath);
                    }
                }
            }

            return null;
        }

		/*
		Silly little helper methods
		*/
		protected function isCustom(template:FileLocation):Boolean
		{
			if (template.fileBridge.nativePath.indexOf(template.fileBridge.resolveApplicationStorageDirectoryPath(null).fileBridge.nativePath) == 0)
			{
				return true;
			}
			
			return false;
		}
		
		private function onNewFileBeingCreated(event:NewFileEvent):void
		{
			notifyNewFileCreated(event.insideLocation, event.newFileCreated, event.isOpenAfterCreate);
		}

		private function notifyNewFileCreated(insideLocation:FileWrapper, fileToSave:FileLocation, isOpenAfterCreate:Boolean=true):void
		{
            // opens the file after writing done
			if (isOpenAfterCreate)
			{
	            dispatcher.dispatchEvent(
					new OpenFileEvent(OpenFileEvent.OPEN_FILE, [fileToSave], -1, [insideLocation])
	            );
			}

            // notify the tree view if it needs to refresh
            // the containing folder to make newly created file show
            if (insideLocation)
            {
				var treeEvent:TreeMenuItemEvent = new TreeMenuItemEvent(TreeMenuItemEvent.NEW_FILE_CREATED, fileToSave.fileBridge.nativePath, insideLocation);
				treeEvent.extra = fileToSave;
				dispatcher.dispatchEvent(treeEvent);
            }
		}
		
		private function getNestingClassName(value:String):String
		{
			if (value.indexOf("/") != -1)
			{
				return value.split("/").pop() as String;
			}
			
			return value;
		}
		
		private function getNestedPackagePath(fileName:String, insideLocationPath:String):String
		{
			if (fileName.indexOf("/") != -1)
			{
				var tmpSplit:Array = fileName.split("/");
				tmpSplit.pop();
				
				return insideLocationPath + model.fileCore.separator + tmpSplit.join(model.fileCore.separator);
			}
			
			return insideLocationPath;
		}

		private function onCategorySettingsChanged(event:Event):void
		{
			// remove everything
			settings.splice(2,settings.length-2);

			if ((event.target as MultiOptionSetting).value == CATEGORY_FILES)
			{
				addFilesOptions();
			}
			else
			{
				addProjectsOptions();
			}

			dispatcher.dispatchEvent(new SettingsEvent(SettingsEvent.EVENT_REFRESH_CURRENT_SETTINGS));
		}
	}
}

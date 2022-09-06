////////////////////////////////////////////////////////////////////////////////
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
// No warranty of merchantability or fitness of any kind.
// Use this software at your own risk.
//
////////////////////////////////////////////////////////////////////////////////
package actionScripts.plugins.visualEditor.domino
{
    import actionScripts.factory.FileLocation;
    import actionScripts.plugin.templating.TemplatingHelper;
    import actionScripts.utils.TextUtil;
    import actionScripts.valueObjects.FileWrapper;

    import actionScripts.events.ExportVisualEditorProjectEvent;
    import actionScripts.plugin.PluginBase;
    import actionScripts.plugin.actionscript.as3project.vo.AS3ProjectVO;
    import actionScripts.valueObjects.ConstantsCoreVO;
    import converter.DominoConverter;
    import surface.SurfaceMockup;
    import lookup.Lookup;
    import actionScripts.valueObjects.ProjectVO;

    public class ExportDominoToRoyalePlugin extends PluginBase
    {
        private var currentProject:AS3ProjectVO;
        private var exportedProject:AS3ProjectVO;

        private var conversionCounter:int;

        public function ExportDominoToRoyalePlugin()
        {
            super();
        }

        override public function get name():String { return "Export Domino Visual Editor Project to Apache Royale Plugin"; }
        override public function get author():String { return ConstantsCoreVO.MOONSHINE_IDE_LABEL +" Project Team"; }
        override public function get description():String { return "Exports Domino Visual Editor project to Apache Royale."; }

        override public function activate():void
        {
            super.activate();

            dispatcher.addEventListener(ExportVisualEditorProjectEvent.EVENT_EXPORT_DOMINO_VISUALEDITOR_PROJECT_TO_ROYALE,
                    generateApacheRoyaleProjectHandler);
        }

        override public function deactivate():void
        {
            super.deactivate();

            dispatcher.removeEventListener(ExportVisualEditorProjectEvent.EVENT_EXPORT_DOMINO_VISUALEDITOR_PROJECT_TO_ROYALE,
                    generateApacheRoyaleProjectHandler);
        }

        private function generateApacheRoyaleProjectHandler(event:ExportVisualEditorProjectEvent):void
        {
            currentProject = model.activeProject as AS3ProjectVO;
            if (currentProject == null || !currentProject.isDominoVisualEditorProject)
            {
                error("This is not Visual Editor Domino project");
                return;
            }

            exportedProject = event.exportedProject;

            var visualEditorFiles:Array = getVisualEditorFiles(currentProject.projectFolder);
            conversionCounter = visualEditorFiles.length;

            var convertedFiles:Array = [];

            convertToRoyale(visualEditorFiles, convertedFiles, conversionFinishedCallback);
        }

        private function convertToRoyale(visualEditorFiles:Array, convertedFiles:Array, finishCallback:Function):void
        {
            for (var i:int = 0; i < visualEditorFiles.length; i++)
            {
                var veFile:FileLocation = new FileLocation(visualEditorFiles[i].nativePath);
                if (!veFile.fileBridge.isDirectory &&
                    veFile.fileBridge.extension == "xml")
                {
                    var dominoXML:XML = this.getXmlConversion(veFile);
                    var surfaceMockup:SurfaceMockup = new SurfaceMockup();

                    DominoConverter.fromXML(surfaceMockup, Lookup.DominoNonUILookup,  dominoXML);

                    convertedFiles.push({surface: surfaceMockup, file: veFile});

                    finishCallback(convertedFiles);
                }
                else
                {
                    var veFiles:Array = veFile.fileBridge.getDirectoryListing();
                    if (veFiles.length > 0)
                    {
                        conversionCounter += veFiles.length - 1;
                        convertToRoyale(veFiles, convertedFiles, finishCallback);
                    }
                    else
                    {
                        finishCallback(convertedFiles);
                    }
                }
            }
        }

        private function getVisualEditorFiles(destination:FileWrapper):Array
        {
            var separator:String = destination.file.fileBridge.separator;
            var visualEditorSrcPath:String = "visualeditor-src" + separator + "main" + separator + "webapp";
            var visualEditorSrcFolder:FileLocation = destination.file.resolvePath(visualEditorSrcPath);

            var veSrcFiles:Array = visualEditorSrcFolder.fileBridge.getDirectoryListing();

            return veSrcFiles.filter(function(item:Object, index:int, array:Array):Boolean {
                return item.extension == "xml";
            });
        }

        private function getXmlConversion(file:FileLocation):XML
        {
            var data:Object = file.fileBridge.read();
            var xmlConversion:XML = new XML(data);

            return xmlConversion;
        }

        private function conversionFinishedCallback(convertedFiles:Array):void
        {
            conversionCounter--;
            if (conversionCounter == 0)
            {
                var views:Array = createConvertedFiles(convertedFiles);

                saveMainFileWithViews(views);
            }
        }

        private function saveMainFileWithViews(views:Array):void
        {
            var mainFile:FileLocation = exportedProject.targets[0];
            var content:String = String(mainFile.fileBridge.read());

            var contentData:Object = {};
                contentData["$NavigationContent"] = getNavigationDp(views);
                contentData["$ApplicationMainContent"] = getMainContent(views);

            content = TemplatingHelper.replace(content, contentData);

            mainFile.fileBridge.save(content);
        }

        /**
         * Save converted files to new project
         * Create an array to display converted files in main view of app
         *
         * @param convertedFiles
         * @return Array
         */
        private function createConvertedFiles(convertedFiles:Array):Array
        {
            var views:Array = [];
            var viewFolder:FileLocation = exportedProject.sourceFolder.resolvePath("views");
            if (!viewFolder.fileBridge.exists)
            {
                viewFolder.fileBridge.createDirectory();
            }

            for (var i:int = 0; i < convertedFiles.length; i++)
            {
                var item:Object = convertedFiles[i];
                var viewObj:Object = {};

                var convertedFile:FileLocation = item.file;
                var destinationFilePath:String = convertedFile.fileBridge.parent.name == "pages" ?
                        convertedFile.fileBridge.nativePath.replace(currentProject.visualEditorSourceFolder.fileBridge.nativePath + exportedProject.sourceFolder.fileBridge.separator +
                                "pages" + exportedProject.sourceFolder.fileBridge.separator, "") :
                        convertedFile.fileBridge.nativePath.replace(currentProject.visualEditorSourceFolder.fileBridge.nativePath + exportedProject.sourceFolder.fileBridge.separator, "");

                //Replace white spaces in file for conversion purposes
                destinationFilePath = destinationFilePath.replace(/[\s_\(\)]/, "");
                var extensionIndex:int = destinationFilePath.lastIndexOf(convertedFile.fileBridge.extension);
                if (extensionIndex > -1)
                {
                    var nameWithoutExt:String = destinationFilePath.substring(0, extensionIndex - 1);
                    viewObj.label = nameWithoutExt;
                    viewObj.content = nameWithoutExt;
                    destinationFilePath = destinationFilePath.replace(".xml", ".mxml");
                }

                convertedFile = viewFolder.resolvePath(viewFolder.fileBridge.nativePath + viewFolder.fileBridge.separator + destinationFilePath);
                var componentData:Array = item.surface.getComponentData();
                var propertyVOName:String = convertedFile.fileBridge.nameWithoutExtension.toLowerCase() + "VO";
                var propertyVOType:String = convertedFile.fileBridge.nameWithoutExtension + "VO";

                var royaleMXMLContentFile:XML = null;
                var contentMXMLFile:String = "";

                if (componentData.length > 0)
                {
                    for (var k:int = 0; k < componentData.length; k++)
                    {
                        var componentDataItem:Object = componentData[k];
                        if (!componentDataItem.fields && !componentDataItem.name)
                        {
                            componentData.splice(k, 1);
                        }
                    }

                    //Prepare Data for VO
                    var propData:Object = {
                        prop: [
                            {
                                propName: propertyVOName,
                                propType: propertyVOType,
                                newInstance: false
                            }
                        ]
                    };
                    royaleMXMLContentFile = item.surface.toRoyaleConvertCode(propData);
                    contentMXMLFile = royaleMXMLContentFile.toXMLString();

                }
                else
                {
                    royaleMXMLContentFile = item.surface.toRoyaleConvertCode();
                    contentMXMLFile = royaleMXMLContentFile.toXMLString();
                }

                item.pageContent = royaleMXMLContentFile;

                views.push(viewObj);
            }

            new DominoRoyaleModuleExporter(
                    exportedProject.sourceFolder.resolvePath("views/modules"),
                    exportedProject as ProjectVO, convertedFiles
            );

            return views;
        }

        private function getNavigationDp(views:Array):String
        {
            var jNamespace:Namespace = new Namespace("j", "library://ns.apache.org/royale/jewel");
            var jsNamespace:Namespace = new Namespace("js", "library://ns.apache.org/royale/basic");
            var fxNamespace:Namespace = new Namespace("fx", "http://ns.adobe.com/mxml/2009");

            var dp:XML = <dataProvider/>;
                dp.setNamespace(jNamespace);

            var dpContent:XML = <ArrayList/>;
                dpContent.setNamespace(jsNamespace);

            for (var i:int = 0; i < views.length; i++)
            {
                var item:Object = views[i];
                var obj:XML = <Object />;
                    obj.setNamespace(fxNamespace);
                    obj.@label = item.label;
                    obj.@content = item.content;

                dpContent.appendChild(obj);
            }

            dp.appendChild(dpContent);
            return dp.toXMLString();
        }

        private function getMainContent(views:Array):String
        {
            var jNamespace:Namespace = new Namespace("j", "library://ns.apache.org/royale/jewel");
            var viewNamespace:Namespace = new Namespace("view", "views.*");

            var content:XML = <ApplicationMainContent/>;
                content.@id="mainContent";
                content.@hasTopAppBar="true";
                content.@hasFooterBar="true";

                content.setNamespace(jNamespace);

            for (var i:int = 0; i < views.length; i++)
            {
                var item:Object = views[i];
                if (i == 0)
                {
                    content.@selectedContent = item.content;
                }

                var sectionContent:XML = <ScrollableSectionContent />;
                    sectionContent.setNamespace(jNamespace);
                    sectionContent.@name = item.content;
                var viewName:String = String(item.label).split(" ").join("");
                var view:XML = new XML('<' + viewName + '/>');
                    view.setNamespace(viewNamespace);

                sectionContent.appendChild(view);
                content.appendChild(sectionContent);
            }

            return content.toXMLString();
        }
    }
}

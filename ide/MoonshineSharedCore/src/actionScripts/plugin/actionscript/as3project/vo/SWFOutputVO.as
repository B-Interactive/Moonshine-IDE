﻿////////////////////////////////////////////////////////////////////////////////
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
package actionScripts.plugin.actionscript.as3project.vo
{
	import actionScripts.factory.FileLocation;
	import actionScripts.locator.IDEModel;
	import actionScripts.utils.SDKUtils;
	import actionScripts.utils.SerializeUtil;
	import actionScripts.utils.TextUtil;
	import actionScripts.utils.UtilsCore;

	public class SWFOutputVO 
	{
		public static const PLATFORM_AIR:String = "AIR";
		public static const PLATFORM_MOBILE:String = "AIR Mobile";
		public static const PLATFORM_DEFAULT:String = "Flash Player";
		
		public var disabled:Boolean = false;
		public var path:FileLocation;
		public var frameRate:Number = 24;
		public var swfVersion:uint = 10;
		public var swfVersionStrict:Number = 0;
		public var swfMinorVersion:uint = 0;
		public var width:int = 100;
		public var height:int = 100;
		public var platform:String;
		
		// TODO What is this? It's present as <movie input="" /> in FD .as3proj
		/** Not sure what this is */
		public var input:String = "";
		
		/** Background color */
		public var background:uint;
		
		
		public function toString():String {
			return "[SWFOutput path='"+path.fileBridge.nativePath+"' frameRate='"+frameRate+"' swfVersion='"+swfVersion+"' width='"+width+"' height='"+height+"' background='#"+backgroundColorHex+"']";
		}
		
		public function get backgroundColorHex():String {
			return TextUtil.padLeft(background.toString(16).toUpperCase(), 6);
		}
		
		public function parse(output:XMLList, project:AS3ProjectVO):void 
		{
			var params:XMLList = output.movie;
			disabled = SerializeUtil.deserializeBoolean(params.@disabled);
			path = project.folderLocation.resolvePath(UtilsCore.fixSlashes(params.@path));
			frameRate = Number(params.@fps);
			width = int(params.@width);
			height = int(params.@height);
			background = uint("0x"+String(params.@background).substr(1));
			input = String(params.@input);
			platform = String(params.@platform);
			
			// we need to do a little more than just setting SWF version value
			// from config.xml.
			// To make thing properly works without much headache, we'll 
			// check if the project does uses any specific SDK, if exists then we'll
			// continue using the config.xml value.
			// If no specific SDK is in use, we'll check if any gloabla SDK is set in Moonshine,
			// if exists then we'll update SWF version by it's version value.
			// If no global SDK exists, then just copy the config.xml value
			if (!project.buildOptions.customSDK && IDEModel.getInstance().defaultSDK)
			{
				swfVersion = SDKUtils.getSdkSwfMajorVersion(null);
			}
			else
			{
				swfVersion = uint(params.@version);
			}
		}
		
		/*
			Returns XML representation of this class.
			If root is set you will get relative paths
		*/
		public function toXML(folder:FileLocation):XML
		{
			var output:XML = <output/>;
			
			var pathStr:String = path.fileBridge.nativePath;
			if (folder) {
				pathStr = folder.fileBridge.getRelativePath(path);
			}
			
			// in case parsing relative path returns null
			// particularly in scenario when "path" is outside folder
			// of "folder"
			if (!pathStr) pathStr = path.fileBridge.nativePath;
			
			var outputPairs:Object = {
				'disabled'	: 	SerializeUtil.serializeBoolean(disabled),
				'fps'		:	frameRate,
				'path'		:	pathStr,
				'width'		:	width,
				'height'	:	height,
				'version'	:	swfVersion,
				'background':	"#"+backgroundColorHex,
				'input'		:	input,
				'platform'	:	platform
			}
			
			output.appendChild(SerializeUtil.serializePairs(outputPairs, <movie/>));
				
			return output;
		}
	}
}
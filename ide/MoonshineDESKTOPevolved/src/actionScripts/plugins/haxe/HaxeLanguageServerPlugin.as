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
package actionScripts.plugins.haxe
{
	import actionScripts.languageServer.ILanguageServerManager;
	import actionScripts.plugin.ILanguageServerPlugin;
	import actionScripts.plugin.PluginBase;
	import actionScripts.plugin.haxe.hxproject.vo.HaxeProjectVO;
	import actionScripts.valueObjects.ConstantsCoreVO;
	import actionScripts.valueObjects.ProjectVO;

	public class HaxeLanguageServerPlugin extends PluginBase implements ILanguageServerPlugin
	{
		override public function get name():String 			{return "Haxe Language Server Plugin";}
		override public function get author():String 		{return ConstantsCoreVO.MOONSHINE_IDE_LABEL + " Project Team";}
		override public function get description():String 	{return "Haxe code intelligence provided by a language server";}

		public function get languageServerProjectType():Class
		{
			return HaxeProjectVO;
		}
		
		public function HaxeLanguageServerPlugin()
		{
			super();
		}

		public function createLanguageServerManager(project:ProjectVO):ILanguageServerManager
		{
			return new HaxeLanguageServerManager(HaxeProjectVO(project));
		}
	}
}
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
package actionScripts.plugins.versionControl
{
	import flash.filesystem.File;
	import flash.net.registerClassAlias;
	
	import mx.collections.ArrayCollection;
	import mx.utils.ObjectUtil;
	
	import actionScripts.utils.FileUtils;
	import actionScripts.utils.SharedObjectUtil;
	import actionScripts.valueObjects.RepositoryItemVO;
	import actionScripts.valueObjects.VersionControlTypes;

	public class VersionControlUtils
	{
		private static var _REPOSITORIES:ArrayCollection;
		public static function get REPOSITORIES():ArrayCollection
		{
			if (!_REPOSITORIES) _REPOSITORIES = SharedObjectUtil.getRepositoriesFromSO();
			return _REPOSITORIES;
		}
		
		public static function getRepositoryItemByUdid(value:String):RepositoryItemVO
		{
			for each (var item:RepositoryItemVO in REPOSITORIES)
			{
				if (item.udid == value) return item;
			}
			
			return null;
		}
		
		public static function hasAuthenticationFailError(value:String):Boolean
		{
			var match:Array = value.toLowerCase().match(/authentication failed/);
			if (!match) match = value.toLowerCase().match(/authorization failed/);
			
			return (match != null);
		}
		
		public static function parseGitDependencies(ofRepository:RepositoryItemVO, fromPath:File):Boolean
		{
			fromPath = fromPath.resolvePath("dependencies.xml")
			if (fromPath.exists)
			{
				var readObject:Object = FileUtils.readFromFile(fromPath);
				var dependencies:XML = new XML(readObject);
				var tmpRepo:RepositoryItemVO;
				
				// put this inside so we initialize only
				// if the correct xml format found
				ofRepository.children = [];
				for each (var repo:XML in dependencies..dependency)
				{
					tmpRepo = new RepositoryItemVO();
					tmpRepo.url = String(repo.url);
					tmpRepo.label = String(repo.label);
					tmpRepo.notes = String(repo.purpose);
					tmpRepo.isRequireAuthentication = ofRepository.isRequireAuthentication;
					tmpRepo.isTrustCertificate = ofRepository.isTrustCertificate;
					tmpRepo.udid = ofRepository.udid;
					tmpRepo.type = VersionControlTypes.XML;
					ofRepository.children.push(tmpRepo);
					
					registerClassAlias("actionScripts.valueObjects.RepositoryItemVO", RepositoryItemVO);
					VersionControlUtils.REPOSITORIES.addItem(ObjectUtil.copy(tmpRepo) as RepositoryItemVO);
				}
				
				SharedObjectUtil.saveRepositoriesToSO(REPOSITORIES);
				return true;
			}
			
			return false;
		}
	}
}
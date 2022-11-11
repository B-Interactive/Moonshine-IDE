////////////////////////////////////////////////////////////////////////////////
//
//  Copyright (C) 2016-present Prominic.NET, Inc.
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
package actionScripts.plugins.git.commands
{
	import actionScripts.events.WorkerEvent;
	import actionScripts.plugin.console.ConsoleOutputEvent;
	import actionScripts.plugins.git.model.GitProjectVO;
	import actionScripts.plugins.git.utils.GitUtils;
	import actionScripts.utils.UtilsCore;
	import actionScripts.valueObjects.ConstantsCoreVO;
	import actionScripts.valueObjects.NativeProcessQueueVO;

	import mx.utils.StringUtil;

	public class CheckBranchNameAvailabilityCommand extends GitCommandBase
	{
		private static const GIT_GET_REMOTE_ORIGINS:String = "gitGetRemoteOrigins";
		private static const GIT_REMOTE_BRANCH_NAME_VALIDATION:String = "gitRemoteValidateProposedBranchName";
		private static const GIT_LOCAL_BRANCH_NAME_VALIDATION:String = "gitLocalValidateProposedBranchName";
		
		private var onCompletion:Function;
		private var targetBranchName:String;
		private var localBranchFoundData:String;
		private var remoteBranchFoundData:String;
		private var remoteOriginWhereBranchFound:String;
		private var isRemoteBranchParsed:Boolean;
		private var isMultipleOrigin:Boolean;
		
		public function CheckBranchNameAvailabilityCommand(name:String, completion:Function)
		{
			super();

			targetBranchName = name;
			onCompletion = completion;
			queue = new Vector.<Object>();

			addToQueue(new NativeProcessQueueVO(ConstantsCoreVO.IS_MACOS ? gitBinaryPathOSX +" show-ref --heads $'"+ UtilsCore.getEncodedForShell(name) +"'" : gitBinaryPathOSX +'&&show-ref&&--heads&&'+ UtilsCore.getEncodedForShell(name), false, GIT_LOCAL_BRANCH_NAME_VALIDATION));
			addToQueue(new NativeProcessQueueVO(getPlatformMessage(' remote'), false, GIT_GET_REMOTE_ORIGINS));
			worker.sendToWorker(WorkerEvent.RUN_LIST_OF_NATIVEPROCESS, {queue:queue, workingDirectory:model.activeProject.folderLocation.fileBridge.nativePath}, subscribeIdToWorker);
		}
		
		override protected function shellData(value:Object):void
		{
			var tmpQueue:Object = value.queue; /** type of NativeProcessQueueVO **/
			if (value.output && value.output.match(/fatal: .*/))
			{
				shellError(value);
				return;
			}

			var tmpModel:GitProjectVO = plugin.modelAgainstProject[model.activeProject];
			switch(tmpQueue.processType)
			{
				case GIT_GET_REMOTE_ORIGINS:
				{
					value.output = StringUtil.trim(value.output);

					var tmpOrigins:Array = value.output.split(ConstantsCoreVO.IS_MACOS ? "\n" : "\r\n");
					isMultipleOrigin = tmpOrigins.length > 1;

					var calculatedURL:String;
					if (tmpModel && tmpModel.sessionUser)
					{
						calculatedURL = GitUtils.getCalculatedRemotePathWithAuth(tmpModel.remoteURL, tmpModel.sessionUser);
					}
					else
					{
						calculatedURL = "https://"+ tmpModel.remoteURL;
					}

					tmpOrigins.forEach(function (origin:String, index:int, arr:Array):void {
						if (origin != "")
						{
							// we'll run this for first instance
							// since we have only one exp file can contain
							// information of one origin
							if (ConstantsCoreVO.IS_MACOS && index == 0 && tmpModel.sessionUser)
							{
								var tmpExpFilePath:String = GitUtils.writeExpOnMacAuthentication(gitBinaryPathOSX +" ls-remote "+ (calculatedURL ? calculatedURL +' ' : '') + origin +' --heads "'+ UtilsCore.getEncodedForShell(targetBranchName) +'"');
								addToQueue(new NativeProcessQueueVO('expect -f "'+ tmpExpFilePath +'"', true, GIT_REMOTE_BRANCH_NAME_VALIDATION, origin));
							}
							else
							{
								addToQueue(new NativeProcessQueueVO(ConstantsCoreVO.IS_MACOS ? gitBinaryPathOSX +" ls-remote "+ (calculatedURL ? calculatedURL +' ' : '') + origin +" --heads $'"+ UtilsCore.getEncodedForShell(targetBranchName) +"'" : gitBinaryPathOSX +'&&ls-remote&&'+ origin +'&&--heads&&'+ UtilsCore.getEncodedForShell(targetBranchName), false, GIT_REMOTE_BRANCH_NAME_VALIDATION, origin));
							}
						}
					});
					worker.sendToWorker(WorkerEvent.RUN_LIST_OF_NATIVEPROCESS, {queue:queue, workingDirectory:model.activeProject.folderLocation.fileBridge.nativePath}, subscribeIdToWorker);
					break;
				}
				case GIT_LOCAL_BRANCH_NAME_VALIDATION:
				{
					localBranchFoundData = value.output;
					break;
				}
				case GIT_REMOTE_BRANCH_NAME_VALIDATION:
				{
					isRemoteBranchParsed = true;
					if (value.output.match(/Checking for any authentication...*/))
					{
						worker.sendToWorker(WorkerEvent.PROCESS_STDINPUT_WRITEUTF, {value:tmpModel.sessionPassword +"\n"}, subscribeIdToWorker);
					}
					else if (!remoteBranchFoundData)
					{
						remoteBranchFoundData = value.output;
						remoteOriginWhereBranchFound = tmpQueue.extraArguments[0];
					}

					break;
				}
			}
		}

		override protected function shellError(value:Object):void
		{
			// call super - it might have some essential
			// commands to run.
			super.shellError(value);

			switch (value.queue.processType)
			{
				case GIT_GET_REMOTE_ORIGINS:
				case GIT_REMOTE_BRANCH_NAME_VALIDATION:
				{
					if (testMessageIfNeedsAuthentication(value.output))
					{
						if (ConstantsCoreVO.IS_APP_STORE_VERSION)
						{
							showPrivateRepositorySandboxError();
							if (onCompletion != null)
							{
								onCompletion("Error: Check console for details.", null, false);
								onCompletion = null;
							}
						}
						else
						{
							openAuthentication(null);
						}
					}
					else
					{
						onCompletion = null;
					}
				}
			}
		}

		override protected function onAuthenticationSuccess(username:String, password:String):void
		{
			if (username && password)
			{
				super.onAuthenticationSuccess(username, password);

				new CheckBranchNameAvailabilityCommand(targetBranchName, onCompletion);
				onCompletion = null;
			}
		}

		override public function onWorkerValueIncoming(value:Object):void
		{
			var tmpValue:Object = value.value;

			// do not print enter password line
			if (ConstantsCoreVO.IS_MACOS && value.value && (("output" in value.value) && (value.value.output != null)) &&
					value.value.output.match(/Enter password \(exp\):.*/))
			{
				value.value.output = value.value.output.replace(/Enter password \(exp\):.*/, "Checking for any authentication..");
			}

			// we do not want to call listOfProcessEnded or
			// unsubscribe until we completes more process from line#69
			if (value.event != WorkerEvent.RUN_LIST_OF_NATIVEPROCESS_ENDED ||
					(value.event == WorkerEvent.RUN_LIST_OF_NATIVEPROCESS_ENDED && isRemoteBranchParsed))
			{
				super.onWorkerValueIncoming(value);
			}

			if (tmpValue && tmpValue.queue.processType == GIT_LOCAL_BRANCH_NAME_VALIDATION && !localBranchFoundData)
			{
				localBranchFoundData = tmpValue.output;
			}

			if (tmpValue && tmpValue.queue.processType == GIT_REMOTE_BRANCH_NAME_VALIDATION && !remoteBranchFoundData)
			{
				isRemoteBranchParsed = true;
				remoteBranchFoundData = tmpValue.output;
				remoteOriginWhereBranchFound = tmpValue.queue.extraArguments[0];
			}
		}

		override protected function listOfProcessEnded():void
		{
			super.listOfProcessEnded();

			if (onCompletion != null)
			{
				onCompletion(localBranchFoundData, remoteBranchFoundData, isMultipleOrigin, remoteOriginWhereBranchFound);
				onCompletion = null;
			}
		}
	}
}
package actionScripts.ui.editor
{
	import actionScripts.ui.editor.text.TextLineModel;
	import actionScripts.events.LanguageServerEvent;
	import actionScripts.events.CompletionItemsEvent;
	import actionScripts.events.SignatureHelpEvent;
	import actionScripts.events.HoverEvent;
	import actionScripts.events.GotoDefinitionEvent;
	import actionScripts.events.DiagnosticsEvent;
	import flash.events.Event;
	import flash.geom.Point;
	import actionScripts.events.ChangeEvent;
	import flash.events.MouseEvent;
	import actionScripts.valueObjects.Location;
	import actionScripts.ui.tabview.CloseTabEvent;
	import actionScripts.events.SaveFileEvent;
	import flash.utils.clearTimeout;
	import flash.utils.setTimeout;
	import actionScripts.events.CodeActionsEvent;
	import actionScripts.ui.tabview.TabEvent;

	public class LanguageServerTextEditor extends BasicTextEditor
	{
		public function LanguageServerTextEditor(languageID:String, readOnly:Boolean = false)
		{
			super(readOnly);

			this._languageID = languageID;

			this.addEventListener(Event.ADDED_TO_STAGE, addedToStageHandler);
			this.addEventListener(Event.REMOVED_FROM_STAGE, removedFromStageHandler);
			
			editor.addEventListener(ChangeEvent.TEXT_CHANGE, onTextChange);
			editor.addEventListener(MouseEvent.MOUSE_MOVE, onMouseMove);
			editor.addEventListener(MouseEvent.ROLL_OVER, onRollOver);
			editor.addEventListener(MouseEvent.ROLL_OUT, onRollOut);
			editor.model.addEventListener(Event.CHANGE, editorModel_onChange);
		}

		private var _languageID:String;

		public function get languageID():String
		{
			return this._languageID;
		}

		private var _codeActionTimeoutID:int = -1;

		protected function addGlobalListeners():void
		{
			dispatcher.addEventListener(DiagnosticsEvent.EVENT_SHOW_DIAGNOSTICS, showDiagnosticsHandler);
			dispatcher.addEventListener(CodeActionsEvent.EVENT_SHOW_CODE_ACTIONS, showCodeActionsHandler);
			dispatcher.addEventListener(CloseTabEvent.EVENT_CLOSE_TAB, closeTabHandler);
			dispatcher.addEventListener(SaveFileEvent.FILE_SAVED, fileSavedHandler);
			dispatcher.addEventListener(CompletionItemsEvent.EVENT_UPDATE_RESOLVED_COMPLETION_ITEM, updateResolvedCompletionItemHandler);
			dispatcher.addEventListener(SignatureHelpEvent.EVENT_SHOW_SIGNATURE_HELP, showSignatureHelpHandler);
			dispatcher.addEventListener(TabEvent.EVENT_TAB_SELECT, tabSelectHandler);
		}

		protected function removeGlobalListeners():void
		{
			dispatcher.removeEventListener(DiagnosticsEvent.EVENT_SHOW_DIAGNOSTICS, showDiagnosticsHandler);
			dispatcher.removeEventListener(CodeActionsEvent.EVENT_SHOW_CODE_ACTIONS, showCodeActionsHandler);
			dispatcher.removeEventListener(CloseTabEvent.EVENT_CLOSE_TAB, closeTabHandler);
			dispatcher.removeEventListener(SaveFileEvent.FILE_SAVED, fileSavedHandler);
			dispatcher.removeEventListener(CompletionItemsEvent.EVENT_UPDATE_RESOLVED_COMPLETION_ITEM, updateResolvedCompletionItemHandler);
			dispatcher.removeEventListener(SignatureHelpEvent.EVENT_SHOW_SIGNATURE_HELP, showSignatureHelpHandler);
			dispatcher.removeEventListener(TabEvent.EVENT_TAB_SELECT, tabSelectHandler);
		}

		protected function closeAllPopups():void
		{
			editor.showSignatureHelp(null);
			editor.showHover(null);
			editor.showDefinitionLink(null, null);
		}

		protected function dispatchCompletionEvent():void
		{
			dispatcher.addEventListener(CompletionItemsEvent.EVENT_SHOW_COMPLETION_LIST,showCompletionListHandler);

			var document:String = getTextDocument();
			var len:Number = editor.model.caretIndex - editor.startPos;
			var startLine:int = editor.model.selectedLineIndex;
			var startChar:int = editor.startPos;
			var endLine:int = editor.model.selectedLineIndex;
			var endChar:int = editor.model.caretIndex;
			dispatcher.dispatchEvent(new LanguageServerEvent(
				LanguageServerEvent.EVENT_COMPLETION,
				startChar, startLine, endChar,endLine,
				document, len, 1));
		}

		protected function dispatchSignatureHelpEvent():void
		{
			var document:String = getTextDocument();			
			var len:Number = editor.model.caretIndex - editor.startPos;
			var startLine:int = editor.model.selectedLineIndex;
			var startChar:int = editor.startPos;
			var endLine:int = editor.model.selectedLineIndex;
			var endChar:int = editor.model.caretIndex;
			dispatcher.dispatchEvent(new LanguageServerEvent(
				LanguageServerEvent.EVENT_SIGNATURE_HELP,
				startChar, startLine, endChar,endLine,
				document, len, 1));
		}

		protected function dispatchHoverEvent(charAndLine:Point):void
		{
			var document:String = getTextDocument();
			var line:int = charAndLine.y;
			var char:int = charAndLine.x;
			dispatcher.dispatchEvent(new LanguageServerEvent(
				LanguageServerEvent.EVENT_HOVER,
				char, line, char, line,
				document, 0, 1));
		}

		protected function dispatchGotoDefinitionEvent(charAndLine:Point):void
		{
			var document:String = getTextDocument();
			var line:int = charAndLine.y;
			var char:int = charAndLine.x;
			dispatcher.dispatchEvent(new LanguageServerEvent(
				LanguageServerEvent.EVENT_DEFINITION_LINK,
				char, line, char, line,
				document, 0, 1));
		}

		protected function getTextDocument():String
		{
			var document:String;
            var lines:Vector.<TextLineModel> = editor.model.lines;
			var textLinesCount:int = lines.length;
            if (textLinesCount > 1)
            {
				textLinesCount -= 1;
                for (var i:int = 0; i < textLinesCount; i++)
                {
                    var textLine:TextLineModel = lines[i];
                    document += textLine.text + "\n";
                }
            }

			return document;
		}

		override protected function openFileAsStringHandler(data:String):void
		{
			super.openFileAsStringHandler(data);
			if(!currentFile)
			{
				return;
			}
			dispatcher.dispatchEvent(new LanguageServerEvent(LanguageServerEvent.EVENT_DIDOPEN,
				0, 0, 0, 0, editor.dataProvider, 0, 0, currentFile.fileBridge.url));
		}

		override protected function openHandler(event:Event):void
		{
			super.openHandler(event);
			if(!currentFile)
			{
				return;
			}
			dispatcher.dispatchEvent(new LanguageServerEvent(LanguageServerEvent.EVENT_DIDOPEN,
				0, 0, 0, 0, editor.dataProvider, 0, 0, currentFile.fileBridge.url));
		}

		private function onRollOver(event:MouseEvent):void
		{
			dispatcher.addEventListener(HoverEvent.EVENT_SHOW_HOVER, showHoverHandler);
			dispatcher.addEventListener(GotoDefinitionEvent.EVENT_SHOW_DEFINITION_LINK, showDefinitionLinkHandler);
		}

		private function onRollOut(event:MouseEvent):void
		{
			dispatcher.removeEventListener(HoverEvent.EVENT_SHOW_HOVER, showHoverHandler);
			dispatcher.removeEventListener(GotoDefinitionEvent.EVENT_SHOW_DEFINITION_LINK, showDefinitionLinkHandler);
			editor.showHover(null);
			editor.showDefinitionLink(null, null);
		}
		
		private function onMouseMove(event:MouseEvent):void
		{
			var globalXY:Point = new Point(event.stageX, event.stageY);
			var charAndLine:Point = editor.getCharAndLineForXY(globalXY, true);
			if(charAndLine !== null)
			{
				if(event.ctrlKey)
				{
					dispatchGotoDefinitionEvent(charAndLine);
				}
				else
				{
					editor.showDefinitionLink(null, null);
					dispatchHoverEvent(charAndLine);
				}
			}
			else
			{
				editor.showDefinitionLink(null, null);
				editor.showHover(null);
			}
		}

		private function onTextChange(event:ChangeEvent):void
		{
			if(!currentFile)
			{
				return;
			}
			dispatcher.dispatchEvent(new LanguageServerEvent(
				LanguageServerEvent.EVENT_DIDCHANGE, 0, 0, 0, 0, editor.dataProvider, 0, 0, currentFile.fileBridge.url));
		}

		private function editorModel_onChange(event:Event):void
		{
			if(_codeActionTimeoutID != -1)
			{
				//we want to "debounce" this event, so reset the timer
				clearTimeout(_codeActionTimeoutID);
				_codeActionTimeoutID = -1;
			}
			_codeActionTimeoutID = setTimeout(dispatchCodeActionEvent, 250);
		}

		private function dispatchCodeActionEvent():void
		{
			_codeActionTimeoutID = -1;
			var document:String = getTextDocument();
			var startLine:int = editor.model.getSelectionLineStart();
			var startChar:int = editor.model.getSelectionCharStart();
			if(startChar == -1)
			{
				startChar = editor.model.caretIndex;
			}
			var endLine:int = editor.model.getSelectionLineEnd();
			var endChar:int = editor.model.getSelectionCharEnd();
			dispatcher.dispatchEvent(new LanguageServerEvent(
				LanguageServerEvent.EVENT_CODE_ACTION,
				startChar, startLine, endChar,endLine));
		}

		protected function showCompletionListHandler(event:CompletionItemsEvent):void
		{
            dispatcher.removeEventListener(CompletionItemsEvent.EVENT_SHOW_COMPLETION_LIST, showCompletionListHandler);
			if (event.items.length == 0)
			{
				return;
			}

			editor.showCompletionList(event.items);
		}

		protected function updateResolvedCompletionItemHandler(event:CompletionItemsEvent):void
		{
			if (event.items.length == 0)
			{
				return;
			}

			editor.resolveCompletionItem(event.items[0]);
		}

		protected function showSignatureHelpHandler(event:SignatureHelpEvent):void
		{
			if(model.activeEditor != this || !currentFile || event.uri !== currentFile.fileBridge.url)
			{
				return;
			}
			editor.showSignatureHelp(event.signatureHelp);
		}

		protected function showHoverHandler(event:HoverEvent):void
		{
			if(model.activeEditor != this || !currentFile || event.uri !== currentFile.fileBridge.url)
			{
				return;
			}
			editor.showHover(event.contents);
		}

		protected function showDefinitionLinkHandler(event:GotoDefinitionEvent):void
		{
			if(model.activeEditor != this || !currentFile || event.uri !== currentFile.fileBridge.url)
			{
				return;
			}
			editor.showDefinitionLink(event.locations, event.position);
		}

		protected function showDiagnosticsHandler(event:DiagnosticsEvent):void
		{
			if(!currentFile || event.path !== currentFile.fileBridge.nativePath)
			{
				return;
			}
			editor.showDiagnostics(event.diagnostics);
		}

		protected function showCodeActionsHandler(event:CodeActionsEvent):void
		{
			if(!currentFile || event.path !== currentFile.fileBridge.nativePath)
			{
				return;
			}
			editor.showCodeActions(event.codeActions);
		}

		protected function closeTabHandler(event:CloseTabEvent):void
		{
			var closedTab:LanguageServerTextEditor = event.tab as LanguageServerTextEditor;
			if(!closedTab || closedTab != this)
			{
				return;
			}
			if(!currentFile)
			{
				return;
			}
			dispatcher.dispatchEvent(new LanguageServerEvent(LanguageServerEvent.EVENT_DIDCLOSE,
				0, 0, 0, 0, null, 0, 0, currentFile.fileBridge.url));
		}

		protected function fileSavedHandler(event:SaveFileEvent):void
		{
			var savedTab:LanguageServerTextEditor = event.editor as LanguageServerTextEditor;
			if(!savedTab || savedTab != this)
			{
				return;
			}
			if(!currentFile)
			{
				return;
			}
			dispatcher.dispatchEvent(new LanguageServerEvent(LanguageServerEvent.EVENT_WILLSAVE,
				0, 0, 0, 0, null, 0, 0, currentFile.fileBridge.url));
			
			dispatcher.dispatchEvent(new LanguageServerEvent(LanguageServerEvent.EVENT_DIDSAVE,
				0, 0, 0, 0, null, 0, 0, currentFile.fileBridge.url));
		}

		protected function tabSelectHandler(event:TabEvent):void
		{
			if(event.child != this)
			{
				this.closeAllPopups();
			}
		}

		private function addedToStageHandler(event:Event):void
		{
			this.addGlobalListeners();
		}

		private function removedFromStageHandler(event:Event):void
		{
			this.removeGlobalListeners();
			this.closeAllPopups();
		}
	}
}
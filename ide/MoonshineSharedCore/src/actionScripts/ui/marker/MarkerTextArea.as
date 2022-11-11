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
package actionScripts.ui.marker
{
	import flash.events.Event;
	import flash.utils.Dictionary;
	
	import mx.events.ResizeEvent;
	import mx.graphics.SolidColor;
	
	import spark.components.Group;
	import spark.components.TextArea;
	import spark.primitives.Rect;
	
	import actionScripts.events.GeneralEvent;
	
	import components.skins.TransparentTextAreaSkin;
	
	import flashx.textLayout.compose.StandardFlowComposer;
	import flashx.textLayout.compose.TextFlowLine;
	import flashx.textLayout.formats.TextLayoutFormat;
	
	[Event(name="VSCrollUpdate", type="actionScripts.events.GeneralEvent")]
	[Event(name="HSCrollUpdate", type="actionScripts.events.GeneralEvent")]
	public class MarkerTextArea extends Group
	{
		private static var LINE_HEIGHT:Number;
		
		public var isMatchCase:Boolean;
		public var isRegexp:Boolean;
		public var isEscapeChars:Boolean;
		public var isRefactoredView:Boolean;
		public var searchRegExp:RegExp;
		
		//public var positions:Array;
		
		private var _text:String;
		public function get text():String {	return _text;	}
		public function set text(value:String):void {
			_text = value;
			if (textArea) textArea.text = _text;
		};
		
		private var textArea:TextArea;
		private var lineHighlightContainer:Group;
		private var lastLinesIndex:int;
		private var highlightDict:Dictionary = new Dictionary();
		private var contentInLineBreaks:Array;
		private var isAllLinesRendered:Boolean;
		
		public function MarkerTextArea()
		{
			super();
			clipAndEnableScrolling = true;
		}
		
		override protected function createChildren():void
		{
			super.createChildren();
			
			var bg:Rect = new Rect();
			bg.fill = new SolidColor(0xf5f5f5);
			bg.left = bg.right = bg.top = bg.bottom = 0;
			addElement(bg);
			
			addElement(getHighlighterBase());
			
			textArea = new TextArea();
			textArea.editable = false;
			textArea.percentWidth = textArea.percentHeight = 100;
			textArea.setStyle("lineBreak", "explicit");
			textArea.setStyle("skinClass", TransparentTextAreaSkin);
			addElement(textArea);
		}
		
		private var replaceValue:String;
		public function highlight(search:String):void
		{
			replaceValue = search;
			
			highlightDict = new Dictionary();
			isAllLinesRendered = false;
			textArea.scroller.verticalScrollBar.value = 0;
			textArea.setFormatOfRange(new TextLayoutFormat());
			if (lineHighlightContainer)
			{
				var tmpIndex:int = getElementIndex(lineHighlightContainer);
				removeElement(lineHighlightContainer);
				addElementAt(getHighlighterBase(), tmpIndex);
			}
			
			if (!textArea.scroller.verticalScrollBar.hasEventListener(Event.CHANGE)) 
			{
				textArea.scroller.verticalScrollBar.addEventListener(Event.CHANGE, onVScrollUpdate);
				textArea.scroller.horizontalScrollBar.addEventListener(Event.CHANGE, onHScrollUpdate);
			}
			
			var positions:Array = getPositions(textArea.text);
			var len:uint = positions.length;
			
			for(var i:int = 0; i<len; i++)
			{
				var textLayoutFormat:TextLayoutFormat = new TextLayoutFormat();
				textLayoutFormat.backgroundColor = 0xffb2ff;
				textArea.setFormatOfRange(textLayoutFormat, positions[i].posStart, positions[i].posEnd);
			}
			
			// adding necessary listeners
			this.addEventListener(ResizeEvent.RESIZE, onStageResized);
			this.addEventListener(Event.REMOVED_FROM_STAGE, onRemovedFromStage);
		}
		
		public function getPositions(original:String):Array 
		{
			// @note
			// we can do the highlight generation in two ways -
			// looping through contentInLineBreaks or adding highlights on-demand
			// upon scroll event updates. If a line has 1000 lines it may would be
			// overkill to generate all the lines in one go looping through the
			// contentsInLineBreaks array. Many a time an user may do not checks
			// till bottom, thus it shoud be more efficient to add the
			// lines based on available TextFlowLine array on scroll event
			contentInLineBreaks = original.split("\n");
			
			var updateLastIndex:Boolean = true;
			var composer:StandardFlowComposer = textArea.textFlow.flowComposer as StandardFlowComposer;
			
			lineHighlightContainer.graphics.beginFill(0xffff00, .35); 
			lineHighlightContainer.graphics.lineStyle(1, 0xffff00, .65, true);
			
			composer.lines.forEach(function(element:TextFlowLine, index:int, arr:Array):void
			{
				if (index == 1) LINE_HEIGHT = element.y - composer.lines[0].y;
				if (element.paragraph && searchRegExp.exec(element.paragraph.mxmlChildren[0].text))
				{
					lineHighlightContainer.graphics.drawRect(0, element.y-1, width, element.height);
					highlightDict[index] = true;
					searchRegExp.lastIndex = 0;
				}
				
				if (!element.paragraph && updateLastIndex)
				{
					lastLinesIndex = index;
					updateLastIndex = false;
				}
				else if (updateLastIndex)
					lastLinesIndex = index;
			});
			
			lineHighlightContainer.graphics.endFill();
			
			var tmpPositions:Array = [];
			var results:Array;
			if (!isRefactoredView)
			{
				results = searchRegExp.exec(original);
				while (results != null)
				{ 
					tmpPositions.push({posStart:results.index, posEnd:searchRegExp.lastIndex});
					results = searchRegExp.exec(original); 
				}
			}
			else
			{
				var replaceValueLength:int = replaceValue.length;
				var t1:String = "";
				var t2:String;
				results = searchRegExp.exec(original);
				while (results != null)
				{
					tmpPositions.push({posStart:results.index, posEnd:results.index + replaceValueLength});
					t2 = (t1 != "" ) ? t1.substring(0, results.index) : original.substring(0, results.index);
					t2 += replaceValue;
					t1 = t2 + ((t1 != "") ? t1.substr(searchRegExp.lastIndex, t1.length) : original.substr(searchRegExp.lastIndex, original.length));
					results = searchRegExp.exec(t1);
				}
				
				this.text = t1;
			}
			
			return tmpPositions;
		}
		
		public function updateVScrollByNeighbour(event:GeneralEvent):void
		{
			textArea.scroller.viewport.verticalScrollPosition = event.value as Number;
			onVScrollUpdate(null, false);
		}
		
		public function updateHScrollByNeighbour(event:GeneralEvent):void
		{
			textArea.scroller.viewport.horizontalScrollPosition = event.value as Number;
		}
		
		private function getHighlighterBase():Group
		{
			lineHighlightContainer = new Group();
			lineHighlightContainer.percentWidth = lineHighlightContainer.percentHeight = 100;
			
			return lineHighlightContainer;
		}
		
		private function onVScrollUpdate(event:Event, isDispatchEvent:Boolean=true):void
		{
			if (!isAllLinesRendered)
			{
				var composer:StandardFlowComposer = textArea.textFlow.flowComposer as StandardFlowComposer;
				if (composer.lines.length == contentInLineBreaks.length - 1) isAllLinesRendered = true;

				if (composer.lines.length > lastLinesIndex)
				{
					var updateLastIndex:Boolean = true;
					lineHighlightContainer.graphics.beginFill(0xffff00, .35); 
					lineHighlightContainer.graphics.lineStyle(1, 0xffff00, .65, true);
					for (var i:int=lastLinesIndex; i < composer.lines.length; i++)
					{
						var tfl:TextFlowLine = composer.lines[i];
						if (highlightDict[i] == undefined && searchRegExp.exec(contentInLineBreaks[i]))
						{
							lineHighlightContainer.graphics.drawRect(0, (i * LINE_HEIGHT)+4, width, LINE_HEIGHT);
							highlightDict[i] = true;
							searchRegExp.lastIndex = 0;
						}
						
						if (!tfl.paragraph && updateLastIndex)
						{
							lastLinesIndex = i;
							updateLastIndex = false;
						}
						else if (updateLastIndex)
							lastLinesIndex = i;
					}
					
					lineHighlightContainer.graphics.endFill();
				}
			}
			
			lineHighlightContainer.y = -textArea.scroller.viewport.verticalScrollPosition;
			if (isDispatchEvent) dispatchEvent(new GeneralEvent("VSCrollUpdate", textArea.scroller.viewport.verticalScrollPosition));
		}
		
		private function onHScrollUpdate(event:Event):void
		{
			dispatchEvent(new GeneralEvent("HSCrollUpdate", textArea.scroller.viewport.horizontalScrollPosition));
		}
		
		private function onRemovedFromStage(event:Event):void
		{
			textArea.scroller.verticalScrollBar.removeEventListener(Event.CHANGE, onVScrollUpdate);
			textArea.scroller.horizontalScrollBar.removeEventListener(Event.CHANGE, onHScrollUpdate);
			this.removeEventListener(ResizeEvent.RESIZE, onStageResized);
			this.removeEventListener(Event.REMOVED_FROM_STAGE, onRemovedFromStage);
		}
		
		private function onStageResized(event:ResizeEvent):void
		{
			trace("Resized");
		}
	}
}
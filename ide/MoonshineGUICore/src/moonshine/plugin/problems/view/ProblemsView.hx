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


package moonshine.plugin.problems.view;

import openfl.events.MouseEvent;
import actionScripts.interfaces.IViewWithTitle;
import feathers.controls.LayoutGroup;
import feathers.controls.TextCallout;
import feathers.controls.TreeView;
import feathers.core.InvalidationFlag;
import feathers.events.HierarchicalCollectionEvent;
import feathers.events.TreeViewEvent;
import feathers.layout.AnchorLayout;
import feathers.layout.AnchorLayoutData;
import feathers.utils.DisplayObjectRecycler;
import moonshine.plugin.problems.data.DiagnosticHierarchicalCollection;
import moonshine.plugin.problems.events.ProblemsViewEvent;
import moonshine.plugin.problems.vo.MoonshineDiagnostic;
import openfl.events.Event;

class ProblemsView extends LayoutGroup implements IViewWithTitle {
	public function new() {
		super();
		this.problems = new DiagnosticHierarchicalCollection();
	}

	private var treeView:TreeView;

	@:flash.property
	public var title(get, never):String;

	public function get_title():String {
		return "Problems";
	}

	private var _problems:DiagnosticHierarchicalCollection;

	@:flash.property
	public var problems(get, set):DiagnosticHierarchicalCollection;

	private function get_problems():DiagnosticHierarchicalCollection {
		return this._problems;
	}

	private function set_problems(value:DiagnosticHierarchicalCollection):DiagnosticHierarchicalCollection {
		if (this._problems == value) {
			return this._problems;
		}
		if (this._problems != null) {
			this._problems.removeEventListener(HierarchicalCollectionEvent.ADD_ITEM, problemsView_problems_addItemHandler);
			this._problems.removeEventListener(HierarchicalCollectionEvent.REPLACE_ITEM, problemsView_problems_replaceItemHandler);
			this._problems.removeEventListener(Event.CHANGE, problemsView_problems_changeHandler);
		}
		this._problems = value;
		if (this._problems != null) {
			this._problems.addEventListener(HierarchicalCollectionEvent.ADD_ITEM, problemsView_problems_addItemHandler, false, 0, true);
			this._problems.addEventListener(HierarchicalCollectionEvent.REPLACE_ITEM, problemsView_problems_replaceItemHandler, false, 0, true);
			this._problems.addEventListener(Event.CHANGE, problemsView_problems_changeHandler, false, 0, true);
		}
		this.setInvalid(InvalidationFlag.DATA);
		return this._problems;
	}

	private var _pendingSelectedLocation:Array<Int>;

	@:flash.property
	public var selectedProblem(get, never):MoonshineDiagnostic;

	public function get_selectedProblem():MoonshineDiagnostic {
		if (this.treeView == null) {
			return null;
		}
		var selectedItem = this.treeView.selectedItem;
		if ((selectedItem is MoonshineDiagnostic)) {
			return (selectedItem : MoonshineDiagnostic);
		}
		return null;
	}

	override private function initialize():Void {
		this.layout = new AnchorLayout();

		this.treeView = new TreeView();
		this.treeView.variant = TreeView.VARIANT_BORDERLESS;
		this.treeView.layoutData = AnchorLayoutData.fill();
		this.treeView.itemToText = item -> {
			if ((item is MoonshineDiagnostic)) {
				var diagnostic = cast(item, MoonshineDiagnostic);
				return this.getMessageLabel(diagnostic);
			} else if ((item is DiagnosticsByUri)) {
				var diagnosticsByUri = cast(item, DiagnosticsByUri);
				return this.getLocationLabel(diagnosticsByUri);
			}
			return Std.string(item);
		}
		this.treeView.itemRendererRecycler = DisplayObjectRecycler.withClass(ProblemItemRenderer);
		this.treeView.addEventListener(TreeViewEvent.ITEM_TRIGGER, problemsView_treeView_itemTriggerHandler);
		this.treeView.name = "diagnostics";
		this.addChild(this.treeView);

		super.initialize();
	}

	override private function update():Void {
		var dataInvalid = this.isInvalid(InvalidationFlag.DATA);

		if (dataInvalid) {
			this.treeView.dataProvider = this._problems;
		}

		super.update();
	}

	private function getMessageLabel(diagnostic:MoonshineDiagnostic):String {
		var result = diagnostic.message;
		var hasCode = diagnostic.code != null && diagnostic.code.length > 0;
		var range = diagnostic.range;
		var start = range.start;
		var hasRangeStart = start != null;
		if (hasCode || hasRangeStart) {
			result += " ";
			if (hasCode) {
				result += "(" + diagnostic.code + ")";
			}
			if (hasRangeStart) {
				result += " [Ln " + (start.line + 1) + ", Col " + (start.character + 1) + "]";
			}
		}
		return result;
	}

	private function getLocationLabel(diagnosticsByUri:DiagnosticsByUri):String {
		var uri = diagnosticsByUri.uri;
		var index = uri.lastIndexOf("/");
		while (index == (uri.length - 1)) {
			uri = uri.substr(0, uri.length - 1);
			index = uri.lastIndexOf("/");
		}
		var fileName = uri.substr(index + 1);
		if (fileName.length == 0 && diagnosticsByUri.project != null) {
			fileName = diagnosticsByUri.project.name;
		}
		var result = fileName;
		if (diagnosticsByUri.project != null) {
			result += " ";
			result += diagnosticsByUri.project.name;
		}
		return result;
	}

	private function problemsView_treeView_itemTriggerHandler(event:TreeViewEvent):Void {
		var item = event.state.data;
		if ((item is MoonshineDiagnostic)) {
			var diagnostic = cast(item, MoonshineDiagnostic);
			if (diagnostic.fileLocation.fileBridge.isDirectory) {
				var itemRenderer = cast(treeView.itemToItemRenderer(event.state.data));
				if (itemRenderer != null) {
					var callout = TextCallout.show("File cannot be opened because file is a directory", itemRenderer);
					callout.addEventListener(MouseEvent.MOUSE_DOWN, event -> {
						callout.close();
					});
				}
				return;
			}
			this.dispatchEvent(new ProblemsViewEvent(ProblemsViewEvent.OPEN_PROBLEM, diagnostic));
		} else if (treeView.dataProvider.isBranch(item)) {
			var isOpen = treeView.isBranchOpen(item);
			this.treeView.toggleBranch(item, !isOpen);
		}
	}

	private function problemsView_problems_addItemHandler(event:HierarchicalCollectionEvent):Void {
		if (!this.created && !this.validating) {
			// ensure that the TreeView data provider has been populated
			// or toggleBranch() won't work
			this.validateNow();
		}
		this.treeView.toggleBranch(event.addedItem, true);
	}

	private function problemsView_problems_replaceItemHandler(event:HierarchicalCollectionEvent):Void {
		if (!this.created && !this.validating) {
			// ensure that the TreeView data provider has been populated
			// or toggleBranch() won't work
			this.validateNow();
		}
		this.treeView.toggleBranch(event.addedItem, true);
		if (!this.locationContains(event.location, this.treeView.selectedLocation)) {
			return;
		}
		var branchLength = this._problems.getLength(event.location);
		var newSelectedLocation = this.treeView.selectedLocation.copy();
		var lastIndex = newSelectedLocation[newSelectedLocation.length - 1];
		if (lastIndex >= branchLength) {
			newSelectedLocation[newSelectedLocation.length - 1] = branchLength - 1;
		}
		this._pendingSelectedLocation = newSelectedLocation;
	}

	private function problemsView_problems_changeHandler(event:Event):Void {
		if (this._pendingSelectedLocation != null) {
			this.treeView.selectedLocation = this._pendingSelectedLocation;
			this._pendingSelectedLocation = null;
		}
	}

	private function locationContains(parent:Array<Int>, possibleChild:Array<Int>):Bool {
		if (parent == null || possibleChild == null || parent.length > possibleChild.length) {
			return false;
		}
		for (i in 0...parent.length) {
			if (parent[i] != possibleChild[i]) {
				return false;
			}
		}
		return true;
	}
}

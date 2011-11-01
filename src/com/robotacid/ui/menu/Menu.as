﻿package com.robotacid.ui.menu {
	import com.robotacid.gfx.BlitRect;
	import com.robotacid.gfx.CaptureBitmap;
	import com.robotacid.gfx.DebrisFX;
	import com.robotacid.sound.SoundManager;
	import com.robotacid.ui.Key;
	import com.robotacid.ui.TextBox;
	import com.robotacid.util.XorRandom;
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.DisplayObjectContainer;
	import flash.display.Shape;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.geom.Matrix;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.text.TextLineMetrics;
	import flash.ui.Keyboard;
	
	/**
	 * This is a key based menu system, designed to allow the player to maintain
	 * preferences and player inventory / skills from one place. The ability to
	 * modify key inputs and setting up of "hot keys" that activate user defined
	 * menu options has been implemented.
	 *
	 * To use: Define MenuLists and MenuOptions. MenuOptions can be pointers to MenuLists
	 * or when they are not, an attempt to traverse right from them will fire an event.
	 *
	 * There are two events:
	 *
	 * SELECT: The user has traversed right until they have reached a MenuOption that does
	 * not point to a MenuList. Steping right from that option fires the SELECT event.
	 * Listening to this event gives the programmer the opportunity to examine the "branch"
	 * property of the Menu and see what the user selected. An appropriate method can then
	 * be called.
	 *
	 * CHANGE: Every time the menu is moved, change is called. The programmer may want to
	 * emit a noise for this, or deactivate/reactivate options based on where the user has
	 * walked to. Bear in mind that MenuOptions are already capable of deactivating other
	 * options when stepped forward through (this is to prevent infinite menu walks, whilst
	 * allowing a recursive path to define hot keys).
	 *
	 * @author Aaron Steed, robotacid.com
	 */
	public class Menu extends Sprite{
		
		// gfx
		public var holder:DisplayObjectContainer;
		public var textHolder:Sprite;
		public var help:TextBox;
		public var selection:int;
		public var selectionWindow:Bitmap;
		public var selectionWindowTaperPrevious:Bitmap;
		public var selectionWindowTaperNext:Bitmap;
		public var previousTextBox:TextBox;
		public var currentTextBox:TextBox;
		public var nextTextBox:TextBox;
		public var capture:CaptureBitmap;
		public var menuSword:Bitmap;
		
		public var hideChangeEvent:Boolean;
		public var selectionWindowCol:uint = 0xFFEEEEEE;
		
		public var branch:Vector.<MenuList>;
		public var branchStringCurrentOption:String;
		public var branchStringHistory:String;
		public var branchStringSeparator:String = "/";
		
		public var hotKeyMaps:Vector.<HotKeyMap>;
		public var hotKeyMapRecord:HotKeyMap;
		public var changeKeysOption:MenuOption;
		public var hotKeyOption:MenuOption;
		
		public var random:XorRandom;
		
		public var previousMenuList:MenuList;
		public var currentMenuList:MenuList;
		public var nextMenuList:MenuList;
		
		public static var keyChanger:MenuList;
		
		// display area that the menu takes up
		public var _width:Number;
		public var _height:Number;
		
		public var maskShape:Shape;
		
		// animation and key states
		public var keyLock:Boolean;
		private var dirStack:Vector.<int>;
		private var dir:int;
		private var moveCount:int;
		private var moveReset:int;
		private var vx:Number;
		private var vy:Number;
		private var previousAlphaStep:Number;
		private var currentAlphaStep:Number;
		private var nextAlphaStep:Number;
		private var captureAlphaStep:Number;
		private var keysDown:int;
		private var keysLocked:int;
		private var keysHeldCount:int;
		private var stackCount:int;
		// sword animation states
		private var animatingSelection:Boolean;
		private var swordCount:int;
		private var swordVx:Number;
		private var bloodCount:int;
		private var blood:Vector.<DebrisFX>;
		
		public static const SWORD_DELAY:int = 3;
		public static const BLOOD_DELAY:int = 12;
		
		public static const LIST_WIDTH:Number = 100;
		public static const LINE_SPACING:Number = 11;
		public static const SELECTION_WINDOW_TAPER_WIDTH:Number = 50;
		public static const SIDE_ALPHAS:Number = 0.7;
		
		public static const MOVE_DELAY:int = 4;
		public static const KEYS_HELD_DELAY:int = 5;
		
		// game key properties
		public static const UP_KEY:int = 0;
		public static const DOWN_KEY:int = 1;
		public static const LEFT_KEY:int = 2;
		public static const RIGHT_KEY:int = 3;
		public static const MENU_KEY:int = 4;
		
		public static const HOT_KEY_OFFSET:int = 5;
		
		public static const UP:int = 1;
		public static const RIGHT:int = 2;
		public static const DOWN:int = 4;
		public static const LEFT:int = 8;
		
		public function Menu(width:Number, height:Number, trunk:MenuList = null):void{
			_width = width;
			_height = height;
			
			dirStack = new Vector.<int>();
			dir = 0;
			vx = vy = 0;
			moveCount = 0;
			moveReset = MOVE_DELAY;
			keysHeldCount = KEYS_HELD_DELAY;
			hideChangeEvent = false;
			animatingSelection = false;
			swordCount = 0;
			bloodCount = 0;
			
			random = new XorRandom();
			
			// initialise the branch recorders - these will help examine the history of
			// menu usage
			branch = new Vector.<MenuList>();
			hotKeyMaps = new Vector.<HotKeyMap>();
			for(var i:int = 0; i < Key.hotKeyTotal; i++){
				hotKeyMaps.push(null);
			}
			
			// create a mask to contain the menu
			maskShape = new Shape();
			addChild(maskShape);
			maskShape.graphics.beginFill(0xFF0000);
			maskShape.graphics.drawRect(0, 0, _width, _height);
			maskShape.graphics.endFill();
			mask = maskShape;
			
			help = new TextBox(320, 36, 0x66111111, 0xFF999999, 0xFFDDDDDD);
			
			// create TextBoxes to render the current state of the menu
			textHolder = new Sprite();
			addChild(textHolder);
			textHolder.x = (-LIST_WIDTH * 0.5 + _width * 0.5) >> 0;
			textHolder.y = ((LINE_SPACING * 3) + (_height - (LINE_SPACING * 3)) * 0.5 - LINE_SPACING * 0.5) >> 0;
			
			previousTextBox = new TextBox(LIST_WIDTH, 1 + LINE_SPACING + TextBox.BORDER_ALLOWANCE * 2, 0x66111111, 0xFF999999, 0xFFDDDDDD);
			previousTextBox.alpha = 0.7;
			previousTextBox.wordWrap = false;
			currentTextBox = new TextBox(LIST_WIDTH, 1 + LINE_SPACING + TextBox.BORDER_ALLOWANCE * 2, 0x66111111, 0xFF999999, 0xFFDDDDDD);
			currentTextBox.wordWrap = false;
			nextTextBox = new TextBox(LIST_WIDTH, 1 + LINE_SPACING + TextBox.BORDER_ALLOWANCE * 2, 0x66111111, 0xFF999999, 0xFFDDDDDD);
			nextTextBox.alpha = 0.7;
			nextTextBox.wordWrap = false;
			capture = new CaptureBitmap();
			capture.visible = false;
			menuSword = new Game.g.library.MenuSwordB();
			
			previousTextBox.x = -LIST_WIDTH;
			nextTextBox.x = LIST_WIDTH;
			
			textHolder.addChild(previousTextBox);
			textHolder.addChild(currentTextBox);
			textHolder.addChild(nextTextBox);
			textHolder.addChild(capture);
			
			blood = new Vector.<DebrisFX>();
			
			previousTextBox.visible = false;
			nextTextBox.visible = false;
			
			// the selection window shows what option we are currently on
			selectionWindow = new Bitmap(new BitmapData(LIST_WIDTH, LINE_SPACING));
			selectionWindow.x = -selectionWindow.width * 0.5 + _width * 0.5;
			selectionWindow.y = 1 + ((LINE_SPACING * 3) + (_height - (LINE_SPACING * 3)) * 0.5 - LINE_SPACING * 0.5 - TextBox.BORDER_ALLOWANCE) >> 0;
			selectionWindowTaperNext = new Bitmap(new BitmapData(SELECTION_WINDOW_TAPER_WIDTH, LINE_SPACING, true, 0x00000000));
			selectionWindowTaperNext.x = selectionWindow.x + selectionWindow.width;
			selectionWindowTaperNext.y = selectionWindow.y;
			selectionWindowTaperPrevious = new Bitmap(new BitmapData(SELECTION_WINDOW_TAPER_WIDTH, LINE_SPACING, true, 0x00000000));
			selectionWindowTaperPrevious.x = selectionWindow.x - selectionWindowTaperPrevious.width;
			selectionWindowTaperPrevious.y = selectionWindow.y;
			drawSelectionWindow();
			addChild(selectionWindow);
			addChild(selectionWindowTaperNext);
			addChild(selectionWindowTaperPrevious);
			
			addChild(help);
			
			if(trunk) setTrunk(trunk);
			
			addEventListener(Event.ENTER_FRAME, onEnterFrame, false, 0, true);
			
		}
		
		/* The trunk is MenuList 0. All options and lists branch outwards like a tree
		 * from this list. Calling this method also moves the menu to the trunk and
		 * renders the current state
		 */
		public function setTrunk(menuList:MenuList):void{
			currentMenuList = menuList;
			previousMenuList = null;
			branch = new Vector.<MenuList>();
			branch.push(menuList);
			branchStringHistory = "";
			moveReset = MOVE_DELAY;
			keysHeldCount = KEYS_HELD_DELAY;
			keyLock = true;
			update();
		}
		
		/* Returns a string representation of the current menu history.
		 * Use this to debug the menu and to quickly identify traversed menu paths
		 */
		public function branchString():String{
			return branchStringHistory + (branchStringHistory.length > 0 ? branchStringSeparator : "") + branchStringCurrentOption;
		}
		
		/* Sets the current MenuList selection, re-renders the menu and fires
		 * the CHANGE event
		 */
		public function select(n:int):void{
			selection = n;
			currentMenuList.selection = n;
			branchStringCurrentOption = currentMenuList.options[n].name;
			if(currentMenuList.options[n].target){
				nextMenuList = currentMenuList.options[n].target;
			} else {
				nextMenuList = null;
			}
			renderMenu();
			if(!hideChangeEvent) dispatchEvent(new Event(Event.CHANGE));
		}
		
		/* Either walks forward to the MenuList pointed to by the current option
		 * or when there is no MenuList pointed to, fires the SELECT event and
		 * jumps the menu back to the trunk.
		 */
		public function stepRight():void{
			if(
				(hotKeyMapRecord && currentMenuList.options[selection].recordable) ||
				(!hotKeyMapRecord && currentMenuList.options[selection].active)
			){
				// walk forward
				if(nextMenuList){
					// recording?
					if(hotKeyMapRecord){
						hotKeyMapRecord.push(currentMenuList.options[currentMenuList.selection], currentMenuList.selection);
					}
					
					// hot key? initialise a HotKeyMap
					if(currentMenuList.options[currentMenuList.selection].hotKeyOption){
						hotKeyMapRecord = new HotKeyMap(currentMenuList.selection, this);
						hotKeyMapRecord.init();
					}
					
					branchStringHistory += (branchStringHistory.length > 0 ? branchStringSeparator : "") + currentMenuList.options[selection].name;
					
					branch.push(nextMenuList);
					
					previousMenuList = currentMenuList;
					currentMenuList = nextMenuList;
					if(currentMenuList == keyChanger) keyLock = true;
					update();
					
				// nothing to walk forward to - call the SELECT event
				} else {
					dirStack.length = 0;
					// if the Menu is recording a path for a hot key, then we store that
					// hot key here:
					if(hotKeyMapRecord){
						hotKeyMapRecord.push(currentMenuList.options[currentMenuList.selection], currentMenuList.selection);
						hotKeyMaps[hotKeyMapRecord.key] = hotKeyMapRecord;
						hotKeyMapRecord = null;
						// because recording a hot key involves deactivating recursive MenuOptions
						// we have to return to the trunk by foot.
						hideChangeEvent = true;
						while(branch.length > 1) stepLeft();
						hideChangeEvent = false;
					} else {
						dispatchEvent(new Event(Event.SELECT));
						setTrunk(branch[0]);
					}
				}
			}
		}
		
		/* Walk back to the previous MenuList. MenuLists and MenuOptions have no memory
		 * of their forebears, so the branch history and previousMenuList is used
		 */
		public function stepLeft():void{
			if(previousMenuList){
				// are we recording?
				if(hotKeyMapRecord){
					hotKeyMapRecord.pop();
					if(hotKeyMapRecord.length < 0){
						hotKeyMapRecord = null;
					}
				}
				branch.pop();
				if(branch.length > 1){
					branchStringHistory = branchStringHistory.substr(0, branchStringHistory.lastIndexOf(branchStringSeparator));
				} else {
					branchStringHistory = "";
				}
				nextMenuList = currentMenuList;
				currentMenuList = previousMenuList;
				previousMenuList = branch.length > 1 ? branch[branch.length - 2] : null;
				
				update();
			}
		}
		
		/* This renders the current menu state, though it is better to use the select()
		 * as it will also update the branchString property and update
		 * what MenuList leads from the currently selected MenuOption.
		 */
		public function renderMenu():void{
			if(previousMenuList){
				previousTextBox.setSize(LIST_WIDTH, LINE_SPACING * previousMenuList.options.length + TextBox.BORDER_ALLOWANCE);
				previousTextBox.text = previousMenuList.optionsToString();
				previousTextBox.y = -previousMenuList.selection * LINE_SPACING - TextBox.BORDER_ALLOWANCE;
				setDisabledLines(previousMenuList, previousTextBox);
				previousTextBox.visible = true;
				selectionWindowTaperPrevious.visible = true;
			} else {
				previousTextBox.visible = false;
				selectionWindowTaperPrevious.visible = false;
			}
			if(currentMenuList){
				if(currentMenuList == keyChanger){
					keyChanger.options[0].name = "press a key";
				}
				currentTextBox.setSize(LIST_WIDTH, LINE_SPACING * currentMenuList.options.length + TextBox.BORDER_ALLOWANCE);
				currentTextBox.text = currentMenuList.optionsToString();
				currentTextBox.y = -currentMenuList.selection * LINE_SPACING - TextBox.BORDER_ALLOWANCE;
				setDisabledLines(currentMenuList, currentTextBox);
			}
			if(currentMenuList.options[selection].active && nextMenuList){
				if(nextMenuList == keyChanger){
					keyChanger.options[0].name = Key.keyString(Key.custom[selection]);
				}
				nextTextBox.setSize(LIST_WIDTH, LINE_SPACING * nextMenuList.options.length + TextBox.BORDER_ALLOWANCE);
				nextTextBox.text = nextMenuList.optionsToString();
				nextTextBox.y = -nextMenuList.selection * LINE_SPACING - TextBox.BORDER_ALLOWANCE;
				setDisabledLines(nextMenuList, nextTextBox);
				nextTextBox.visible = true;
				selectionWindowTaperNext.visible = true;
			} else {
				nextTextBox.visible = false;
				selectionWindowTaperNext.visible = false;
			}
		}
		
		/* Updates the rendering of disabled MenuOptions */
		public function setDisabledLines(menuList:MenuList, textBox:TextBox):void{
			for(var i:int = 0; i < menuList.options.length; i++){
				if(
					!(
						(hotKeyMapRecord && menuList.options[i].recordable) ||
						(!hotKeyMapRecord && menuList.options[i].active)
					)
				) textBox.setDisabledLine(i);
			}
		}
		
		private function animateUp():void{
			//if((dir & UP) && moveReset > 2) moveReset--;
			
			// capture the next menu
			capture.capture(nextTextBox);
			capture.visible = nextTextBox.visible;
			capture.alpha = nextTextBox.alpha;
			nextTextBox.alpha = 0;
			nextAlphaStep = SIDE_ALPHAS / moveReset;
			captureAlphaStep = -SIDE_ALPHAS / moveReset;
			
			var currentY:Number = currentTextBox.y;
			select(selection - 1);
			vy = (currentTextBox.y - currentY) / moveReset;
			currentTextBox.y = currentY;
			
			SoundManager.playSound("step");
			
			dir |= UP;
			dir &= ~DOWN;
		}
		
		private function animateDown():void{
			//if((dir & DOWN) && moveReset > 2) moveReset--;
			
			// capture the next menu
			capture.capture(nextTextBox);
			capture.visible = nextTextBox.visible;
			capture.alpha = nextTextBox.alpha;
			nextTextBox.alpha = 0;
			nextAlphaStep = SIDE_ALPHAS / moveReset;
			captureAlphaStep = -SIDE_ALPHAS / moveReset;
			
			var currentY:Number = currentTextBox.y;
			select(selection + 1);
			vy = (currentTextBox.y - currentY) / moveReset;
			currentTextBox.y = currentY;
			
			SoundManager.playSound("step");
			
			dir |= DOWN;
			dir &= ~UP;
		}
		
		private function animateRight():void{
			if(nextMenuList){
				// capture the previous menu
				capture.capture(previousTextBox);
				capture.visible = previousTextBox.visible;
				capture.alpha = previousTextBox.alpha;
				stepRight();
				
				previousTextBox.x += LIST_WIDTH;
				currentTextBox.x += LIST_WIDTH;
				nextTextBox.x += LIST_WIDTH;
				previousTextBox.alpha = 1;
				currentTextBox.alpha = SIDE_ALPHAS;
				nextTextBox.alpha = 0;
				
				previousAlphaStep = (SIDE_ALPHAS - 1.0) / moveReset;
				currentAlphaStep = (1.0 - SIDE_ALPHAS) / moveReset;
				nextAlphaStep = 1.0 / moveReset;
				captureAlphaStep = -SIDE_ALPHAS / moveReset;
				vx = -LIST_WIDTH / moveReset;
			
				SoundManager.playSound("step");
			
			// initialise and launch menu selection animation
			} else {
				capture.capture(textHolder, new Matrix(1, 0, 0, 1, textHolder.x, textHolder.y), _width, _height);
				capture.x = -textHolder.x;
				capture.y = -textHolder.y;
				capture.alpha = 1;
				capture.visible = true;
				stepRight();
				previousTextBox.alpha = 0;
				currentTextBox.alpha = 0;
				nextTextBox.alpha = 0;
			
				moveReset = MOVE_DELAY * 3;
				moveCount = moveReset;
				
				previousAlphaStep = SIDE_ALPHAS / moveReset;
				currentAlphaStep = 1.0 / moveReset;
				nextAlphaStep = SIDE_ALPHAS / moveReset;
				captureAlphaStep = -1.0 / moveReset;
				vx = 0;
				
				animatingSelection = true;
				swordCount = SWORD_DELAY;
				bloodCount = BLOOD_DELAY;
				menuSword.x = _width;
				swordVx = -(_width - (textHolder.x + LIST_WIDTH * 0.5)) / SWORD_DELAY;
				selectionWindowTaperNext.visible = false;
			}
			
			dir |= RIGHT;
			dir &= ~LEFT;
		}
		
		private function animateLeft():void{
			// capture the next menu
			capture.capture(nextTextBox);
			capture.visible = nextTextBox.visible;
			capture.alpha = previousTextBox.alpha;
			stepLeft();
			
			previousTextBox.x -= LIST_WIDTH;
			currentTextBox.x -= LIST_WIDTH;
			nextTextBox.x -= LIST_WIDTH;
			previousTextBox.alpha = 0;
			currentTextBox.alpha = SIDE_ALPHAS;
			nextTextBox.alpha = 1;
			
			previousAlphaStep = 1.0 / moveReset;
			currentAlphaStep = (1.0 - SIDE_ALPHAS) / moveReset;
			nextAlphaStep = (SIDE_ALPHAS - 1.0) / moveReset;
			captureAlphaStep = -SIDE_ALPHAS / moveReset;
			vx = LIST_WIDTH / moveReset;
			
			SoundManager.playSound("step");
			
			dir |= LEFT;
			dir &= ~RIGHT;
		}
		
		/* We listen for key input here, the keyLock property is used to stop the menu
		 * endlessly firing the same selection */
		public function onEnterFrame(e:Event = null):void{
			var i:int, j:int;
			// if the keyChanger is active, listen for keys to change the current key set
			if(!keyLock && keyChanger && currentMenuList == keyChanger){
				if(Key.keysPressed){
					var newKey:int = Key.keyLog[Key.KEY_LOG_LENGTH - 1];
					Key.custom[previousMenuList.selection] = newKey;
					// change the menu names of the affected keys
					changeKeyName(changeKeysOption.target.options[previousMenuList.selection], newKey);
					if(previousMenuList.selection >= HOT_KEY_OFFSET){
						changeKeyName(hotKeyOption.target.options[previousMenuList.selection - HOT_KEY_OFFSET], newKey);
					}
					keyLock = true;
					stepLeft();
				}
			}
			// track hot keys so they can instantly perform menu actions
			if(!keyLock && Key.keysPressed){
				for(i = 0; i < Key.hotKeyTotal; i++){
					if(hotKeyMaps[i] && Key.customDown(HOT_KEY_OFFSET + i)){
						hotKeyMaps[i].execute();
						keyLock = true;
						break;
					}
				}
			}
			// load key inputs into a single variable
			var lastKeysDown:int = keysDown;
			keysDown = 0;
			if(Key.keysPressed){
				// bypass reading keys if the menu is not on the display list
				if(parent){
					if(!keyLock){
						if((Key.isDown(Keyboard.UP) || Key.customDown(UP_KEY)) && !(Key.isDown(Keyboard.DOWN) || Key.customDown(DOWN_KEY))){
							keysDown |= UP;
							keysDown &= ~DOWN;
						} else {
							keysLocked &= ~UP;
						}
						if((Key.isDown(Keyboard.DOWN) || Key.customDown(DOWN_KEY)) && !(Key.isDown(Keyboard.UP) || Key.customDown(UP_KEY))){
							keysDown |= DOWN;
							keysDown &= ~UP;
						} else {
							keysLocked &= ~DOWN;
						}
						if((Key.isDown(Keyboard.LEFT) || Key.customDown(LEFT_KEY)) && !(Key.isDown(Keyboard.RIGHT) || Key.customDown(RIGHT_KEY))){
							keysDown |= LEFT;
							keysDown &= ~RIGHT;
						} else {
							keysLocked &= ~LEFT;
						}
						if((Key.isDown(Keyboard.RIGHT) || Key.customDown(RIGHT_KEY)) && !(Key.isDown(Keyboard.LEFT) || Key.customDown(LEFT_KEY))){
							keysDown |= RIGHT;
							keysDown &= ~LEFT;
						} else {
							keysLocked &= ~RIGHT;
						}
					}
				} else {
					keyLock = true;
				}
				if(lastKeysDown & keysDown){
					if(keysHeldCount) keysHeldCount--;
				}
			} else {
				keyLock = false;
				keysLocked = 0;
				lastKeysDown = 0;
				moveReset = MOVE_DELAY;
				keysHeldCount = KEYS_HELD_DELAY;
			}
			// load directions in - keys are locked out of new input unless held down till
			// keysHeldCount reaches zero - then fast browsing is activated
			if(keysDown){
				if(!(keysDown & keysLocked)){
					dirStack.push(keysDown);
					keysLocked |= keysDown;
				} else if(keysHeldCount == 0 && moveCount == 0){
					dirStack.push(keysDown);
				}
			}
			// check if there are directions loaded into the dirStack
			if(dir == 0){
				do{
					if(dirStack.length){
						dir = dirStack.shift();
						if((dir & UP) && selection > 0) animateUp();
						else if((dir & DOWN) && selection < currentMenuList.options.length - 1) animateDown();
						else if(
							(dir & RIGHT) &&
							(
								(hotKeyMapRecord && currentMenuList.options[selection].recordable) ||
								(!hotKeyMapRecord && currentMenuList.options[selection].active)
							)
						){
							animateRight();
						}
						else if((dir & LEFT) && previousMenuList) animateLeft();
						else {
							// illegal move
							dir = 0;
						}
					} else break;
				} while(dir == 0);
				if(dir) moveCount = moveReset;
				
			// animate the menu
			} else {
				// selection animation
				if(animatingSelection){
					var animAreaX:Number = textHolder.x + LIST_WIDTH;
					
					if(swordCount){
						swordCount--;
						menuSword.x += swordVx;
						capture.bitmapData.fillRect(new Rectangle(animAreaX, 0, _width - animAreaX, height), 0x00000000);
						if(swordCount == 0) SoundManager.playSound("hit");
					} else if(bloodCount){
						bloodCount--;
						var blit:BlitRect, debris:DebrisFX;
						if(random.value() < 0.5){
							blit = Game.renderer.smallDebrisBlits[0];
						} else {
							blit = Game.renderer.bigDebrisBlits[0];
						}
						for(i = 0; i < 15; i++){
							debris = new DebrisFX(-5 + animAreaX + random.range(50), textHolder.y + random.range(LINE_SPACING), blit, capture.bitmapData, this, null, false, false);
							debris.addVelocity(5 + random.range(10), -5 + random.range(5));
							blood.push(debris);
						}
						if(bloodCount == 0){
							animatingSelection = false;
							blood.length = 0;
							moveReset = MOVE_DELAY;
							// flush the direction stack again to avoid leaping off selecting things after the anim
							dirStack.length = 0;
						}
					}
					var maskRect:Rectangle = new Rectangle(Math.max(animAreaX - menuSword.x, 0), 0, menuSword.width, menuSword.height);
					capture.bitmapData.copyPixels(menuSword.bitmapData, maskRect, new Point(menuSword.x + maskRect.x, textHolder.y), null, null, true);
					for(i = blood.length - 1; i > -1; i--){
						debris = blood[i];
						if(debris.x < _width && debris.y < _height) debris.main();
						else blood.splice(1, 1);
					}
				} else {
					// browsing animation
					if(moveCount){
						if(dir & (UP | DOWN)){
							currentTextBox.y += vy;
							nextTextBox.alpha += nextAlphaStep;
							capture.alpha += captureAlphaStep;
						}
						if(dir & (RIGHT | LEFT)){
							previousTextBox.x += vx;
							currentTextBox.x += vx;
							nextTextBox.x += vx;
							capture.x += vx;
							previousTextBox.alpha += previousAlphaStep;
							currentTextBox.alpha += currentAlphaStep;
							nextTextBox.alpha += nextAlphaStep;
							capture.alpha += captureAlphaStep;
						}
						moveCount--;
						// animation over
						if(moveCount == 0){
							// force everything into its right place to avoid floating point error build up
							currentTextBox.x = 0;
							previousTextBox.x = -LIST_WIDTH;
							nextTextBox.x = LIST_WIDTH;
							currentTextBox.alpha = 1;
							previousTextBox.alpha = nextTextBox.alpha = SIDE_ALPHAS;
							capture.alpha = 0;
							dir = 0;
							// reduce the animation time when holding down keys for fast browsing
							if(keysDown && keysHeldCount == 0){
								if(moveReset > 1) moveReset--;
							} else {
								moveReset = MOVE_DELAY;
							}
							update();
						}
					}
				}
			}
		}
		
		/* Update the bitmapdata for the selection window */
		public function drawSelectionWindow():void{
			selectionWindow.bitmapData.fillRect(
				new Rectangle(
					selectionWindow.bitmapData.rect.x,
					selectionWindow.bitmapData.rect.y,
					selectionWindow.bitmapData.rect.width,
					selectionWindow.bitmapData.rect.height
				), selectionWindowCol);
			selectionWindow.bitmapData.fillRect(
				new Rectangle(
					selectionWindow.bitmapData.rect.x + 1,
					selectionWindow.bitmapData.rect.y + 1,
					selectionWindow.bitmapData.rect.width - 2,
					selectionWindow.bitmapData.rect.height- 2
				), 0x00000000);
				var step:int = 255 / SELECTION_WINDOW_TAPER_WIDTH;
			for(var c:uint = selectionWindowCol, n:int = 0; n < SELECTION_WINDOW_TAPER_WIDTH; c -= 0x01000000 * step, n++){
				selectionWindowTaperNext.bitmapData.setPixel32(n, 0, c);
				selectionWindowTaperNext.bitmapData.setPixel32(n, selectionWindow.height-1, c);
				selectionWindowTaperPrevious.bitmapData.setPixel32(SELECTION_WINDOW_TAPER_WIDTH - n, 0, c);
				selectionWindowTaperPrevious.bitmapData.setPixel32(SELECTION_WINDOW_TAPER_WIDTH - n, selectionWindow.height - 1, c);
			}
		}
		
		/* Short hand for calling select(currentMenuList.selection) - and more obvious */
		public function update():void{
			select(currentMenuList.selection);
		}
		
		/* Returns a MenuOption that leads to a MenuList offering the ability to redefine keys. */
		public function initChangeKeysMenuOption():void{
			var keyChangerOption:MenuOption = new MenuOption("no key data");
			var keyChangerOptions:Vector.<MenuOption> = new Vector.<MenuOption>();
			keyChangerOptions.push(keyChangerOption);
			keyChanger = new MenuList(keyChangerOptions);
			
			var changeKeysMenuOptions:Vector.<MenuOption> = new Vector.<MenuOption>();
			changeKeysMenuOptions.push(new MenuOption("up:" + Key.keyString(Key.custom[0]), keyChanger));
			changeKeysMenuOptions.push(new MenuOption("down:" + Key.keyString(Key.custom[1]), keyChanger));
			changeKeysMenuOptions.push(new MenuOption("left:" + Key.keyString(Key.custom[2]), keyChanger));
			changeKeysMenuOptions.push(new MenuOption("right:" + Key.keyString(Key.custom[3]), keyChanger));
			changeKeysMenuOptions.push(new MenuOption("menu:" + Key.keyString(Key.custom[4]), keyChanger));
			
			var changeKeysMenuList:MenuList = new MenuList(changeKeysMenuOptions);
			
			for(var i:int = 0; i < Key.hotKeyTotal; i++){
				changeKeysMenuList.options.push(new MenuOption("hot key:" + Key.keyString(Key.custom[HOT_KEY_OFFSET + i]), keyChanger));
			}
			changeKeysOption = new MenuOption("change keys", changeKeysMenuList);
			changeKeysOption.recordable = false;
		}
		
		/* Returns a MenuOption that leads to a MenuList offering the ability to create "hot keys"
		 *
		 * Recording a hot key involves walking from the trunk out and firing a SELECT
		 * event. This will not fire the event, but store the selections made and bind
		 * them to that hot key. Pressing the hot key will then walk the menu back to the trunk
		 * and out to the selected option for that hot key.
		 *
		 * This feature requires submitting the trunk MenuList and a MenuOption that can be
		 * deactivated to prevent the user from walking out to the hot key menu again or
		 * doing another menu activity like redefining keys. I will expand the deactivation
		 * reference to an array at a later date.
		 */
		public function initHotKeyMenuOption(trunk:MenuList):void{
			var hotKeyMenuList:MenuList = new MenuList();
			var option:MenuOption;
			hotKeyOption = new MenuOption("set hot key");
			hotKeyOption.recordable = false;
			for(var i:int = 0; i < Key.hotKeyTotal; i++){
				option = new MenuOption("");
				option.name = "hot key:" + Key.keyString(Key.custom[HOT_KEY_OFFSET + i]);
				option.help = "pressing right on the menu will begin recording. execute a menu option to bind it to this key. this will not actually execute the option"
				option.target = trunk;
				option.hotKeyOption = true;
				hotKeyMenuList.options.push(option);
			}
			hotKeyOption.target = hotKeyMenuList
		}
		
		/* Changes the name of a menu option associated with a key to a given keyCode */
		private function changeKeyName(option:MenuOption, newKey:int):void{
			var str:String = option.name.substr(0, option.name.indexOf(":") + 1) + Key.keyString(newKey);
			option.name = str;
		}
		
	}

}
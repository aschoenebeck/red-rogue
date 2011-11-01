﻿package com.robotacid.engine {
	import com.robotacid.engine.Entity;
	import com.robotacid.gfx.ItemMovieClip;
	import com.robotacid.phys.Cast;
	import com.robotacid.phys.Collider;
	import com.robotacid.ui.menu.InventoryMenuList;
	import com.robotacid.ui.menu.MenuOptionStack;
	import com.robotacid.util.HiddenInt;
	import flash.display.DisplayObject;
	import flash.display.MovieClip;
	import flash.filters.GlowFilter;
	import flash.geom.ColorTransform;
	import flash.geom.Rectangle;
	
	/**
	* The usable item object -
	*
	* These are equippable, and usable in numerous ways.
	* This objects serves to bring all items in the game under one roof.
	*
	* @author Aaron Steed, robotacid.com
	*/
	public class Item extends ColliderEntity{
		
		public var type:int;
		public var level:int;
		public var nameStr:String;
		
		// states
		public var location:int;
		public var stacked:Boolean;
		public var curseState:int;
		public var twinkleCount:int;
		public var range:int;
		public var position:int;
		public var user:Character;
		
		// stats
		public var damage:Number;
		public var attack:Number;
		public var defence:Number;
		public var stun:Number;
		public var knockback:Number;
		public var endurance:Number;
		public var leech:Number;
		
		public var effects:Vector.<Effect>;
		public var missileGfxClass:Class;
		private var bounds:Rectangle;
		
		public static var runeNames:Array;
		
		public static const TWINKLE_DELAY:int = 20;
		
		// types
		public static const WEAPON:int = 0;
		public static const ARMOUR:int = 1;
		public static const RUNE:int = 2;
		public static const HEART:int = 3;
		
		// location
		public static const UNASSIGNED:int = 0;
		public static const DROPPED:int = 1;
		public static const INVENTORY:int = 2;
		public static const EQUIPPED:int = 3;
		public static const FLIGHT:int = 4;
		
		// ranges
		public static const MELEE:int = 1 << 0;
		public static const MISSILE:int = 1 << 1;
		public static const THROWN:int = 1 << 2;
		
		// positions
		public static const HAT:int = 0;
		public static const FULL_BODY:int = 1;
		
		// item names - keeping these constants because I can refactor them easier than
		// references to itemStats.json which I may want to change
		
		// weapons
		public static const DAGGER:int = 0;
		public static const MACE:int = 1;
		public static const SWORD:int = 2;
		public static const STAFF:int = 3;
		public static const SHORT_BOW:int = 4;
		public static const HAMMER:int = 5;
		public static const LEECH_WEAPON:int = 6;
		
		// armour
		public static const FLIES:int = 0;
		public static const FEDORA:int = 1;
		public static const VIKING_HELM:int = 2;
		public static const SKULL:int = 3;
		public static const BLOOD:int = 4;
		public static const INVISIBILITY:int = 5;
		public static const GOGGLES:int = 6;
		
		// runes
		public static const LIGHT:int = 0;
		public static const HEAL:int = 1;
		public static const POISON:int = 2;
		public static const TELEPORT:int = 3;
		public static const UNDEAD:int = 4;
		public static const POLYMORPH:int = 5;
		public static const XP:int = 6;
		public static const LEECH_RUNE:int = 7;
		
		// curse states
		public static const NO_CURSE:int = 0;
		public static const CURSE_HIDDEN:int = 1;
		public static const CURSE_REVEALED:int = 2;
		
		public static const CURSE_CHANCE:Number = 0.05;
		
		public static const MAX_LEVEL:int = 20;
		public static const DROP_GLOW_FILTER:GlowFilter = new GlowFilter(0xFFFFFF, 0.5, 2, 2, 1000);
		/* There are five health stealing opportunities: being a vampire, the leech weapon, blood armour and leech enchantment
		 * counts as two - but we're going to treat it as four and divide 1.0 by 20 * 4 */
		public static const LEECH_PER_LEVEL:Number = 0.0125;
		
		[Embed(source = "itemStats.json", mimeType = "application/octet-stream")] public static var statsData:Class;
		public static var stats:Object;
		
		public function Item(mc:DisplayObject, name:int, type:int, level:int) {
			super(mc, false);
			this.type = type;
			this.name = name;
			this.level = level;
			active = false;
			setStats();
			curseState = NO_CURSE;
			location = UNASSIGNED;
			stacked = false;
			callMain = true;
			user = null;
			twinkleCount = TWINKLE_DELAY + g.random.range(TWINKLE_DELAY);
		}
		
		public function setStats():void{
			var i:int, effect:Effect;
			if(type == WEAPON){
				nameStr = stats["weapon names"][name];
				damage = stats["weapon damages"][name] + stats["weapon damage levels"][name] * level;
				attack = stats["weapon attacks"][name] + stats["weapon attack levels"][name] * level;
				stun = stats["weapon stuns"][name];
				knockback = stats["weapon knockbacks"][name];
				range = stats["weapon ranges"][name];
				
				if(name == SHORT_BOW){
					missileGfxClass = ShortBowArrowMC;
				}
				if(name == LEECH_WEAPON){
					leech = LEECH_PER_LEVEL * level;
				} else {
					leech = 0;
				}
				if(effects){
					for(i = 0; i < effects.length; i++){
						effect = effects[i];
						if(effect.name == Effect.LEECH) leech += LEECH_PER_LEVEL * effect.level;
					}
				}
				
			} else if(type == ARMOUR){
				nameStr = stats["armour names"][name];
				defence = stats["armour defences"][name] + stats["armour defence levels"][name] * level;
				endurance = stats["armour endurance"][name];
				position = stats["armour positions"][name];
				if(name == BLOOD){
					leech = LEECH_PER_LEVEL * level;
				} else {
					leech = 0;
				}
				if(effects){
					for(i = 0; i < effects.length; i++){
						effect = effects[i];
						if(effect.name == Effect.LEECH) leech += LEECH_PER_LEVEL * effect.level;
					}
				}
				
			} else if(type == RUNE){
				nameStr = stats["rune names"][name];
			}
		}
		
		/* Initialises the collider for this Entity */
		override public function createCollider(x:Number, y:Number, properties:int, ignoreProperties:int, state:int = 0, positionByBase:Boolean = true):void{
			
			bounds = gfx.getBounds(gfx);
			if(bounds.width == 0){
				bounds.x = 0;
				bounds.y = 0;
				bounds.width = 8;
				bounds.height = 8;
			} else {
				bounds.x -= 1;
				bounds.y -= 1;
				bounds.width += 2;
				bounds.height += 2;
			}
			
			collider = new Collider(x - bounds.width * 0.5, y - bounds.height, bounds.width, bounds.height, Game.SCALE, properties, ignoreProperties, state);
			
			collider.userData = this;
			mapX = (collider.x + collider.width * 0.5) * Game.INV_SCALE;
			mapY = (collider.y + collider.height * 0.5) * Game.INV_SCALE;
		}
		
		override public function main():void {
			if(collider.state == Collider.STACK){
				if(!g.mapRenderer.contains(collider.x + collider.width * 0.5, collider.y + collider.height * 0.5)) remove();
			}
			// concealing the item in the dark will help avoid showing a clipped effect on the edge
			// of the light map
			if(g.dungeon.level <= 0) gfx.visible = true;
			else gfx.visible = g.lightMap.darkImage.getPixel32(mapX, mapY) != 0xFF000000 || g.player.infravision > 1;
			
			if(gfx.visible){
				// create a twinkle twinkle effect when the item is on the map to collect
				if(twinkleCount-- <= 0){
					renderer.addFX(collider.x + g.random.range(collider.width), collider.y + g.random.range(collider.height), renderer.twinkleBlit);
					twinkleCount = TWINKLE_DELAY + g.random.range(TWINKLE_DELAY);
				}
			}
			
			// check for collection by player
			if((g.player.actions & Collider.UP) && collider.intersects(g.player.collider)){
				collect(g.player);
			}
		}
		
		public function collect(character:Character, print:Boolean = true):void{
			if(location == DROPPED){
				collider.world.removeCollider(collider);
				active = false;
			}
			location = INVENTORY;
			if(character is Player){
				g.menu.inventoryList.addItem(this);
				if(print) g.console.print("picked up " + nameToString());
			} else character.loot.push(this);
			gfx.filters = [];
			gfx.visible = true;
		}
		
		/* Puts this item on the map */
		public function dropToMap(mx:int, my:int):void{
			active = true;
			location = DROPPED;
			mapX = mx;
			mapY = my;
			mapZ = MapRenderer.ENTITY_LAYER;
			setDroppedRender();
			createCollider((mx + 0.5) * Game.SCALE, (my + 1) * Game.SCALE, Collider.ITEM | Collider.SOLID, 0, Collider.FALL);
			g.items.push(this);
			g.world.restoreCollider(collider);
		}
		
		/* Increases current level of item and sets attributes accordingly */
		public function levelUp(n:int = 1):void{
			if(!(type == WEAPON || type == ARMOUR)) return;
			if(level + n < Game.MAX_LEVEL){
				level += 1;
			}
			setStats();
		}
		
		/* Adjusts the graphics for the Item for being dropped to the map and adds a GlowFilter to make it more
		 * visible against the grey background */
		public function setDroppedRender():void{
			if(gfx is ItemMovieClip) (gfx as ItemMovieClip).setDropRender();
			gfx.filters = [DROP_GLOW_FILTER];
		}
		
		public function enchantable(runeName:int):Boolean{
			if(runeName == XP && level == Game.MAX_LEVEL) return false;
			if(!effects) return true;
			for(var i:int = 0; i < effects.length; i++){
				if(effects[i].name == runeName && effects[i].level >= Game.MAX_LEVEL) return false;
			}
			return true;
		}
		
		/* Turns this item into a cursed item - it cannot be unequipped by the player other than through Effects */
		public function applyCurse():void{
			if(curseState == CURSE_REVEALED) return;
			
			curseState = CURSE_HIDDEN;
			
			if(location == EQUIPPED){
				revealCurse();
				if(user && user == g.minion){
					g.console.print("but the minion is unaffected...");
				}
			}
		}
		
		/* Reveals that this item is cursed in the menu */
		public function revealCurse():void{
			if(location == INVENTORY) g.console.print("the " + nameToString() + " is cursed!");
			curseState = CURSE_REVEALED;
		}
		
		/* Adds special abilities to a Character when equipped */
		public function addBuff(character:Character):void{
			if(leech) character.leech += leech;
			if(type == ARMOUR){
				if(name == GOGGLES){
					character.setInfravision(character.infravision + 1);
				}
			}
		}
		
		/* Removes previously added abilities from a Character */
		public function removeBuff(character:Character):void{
			if(leech) character.leech -= leech;
			if(type == ARMOUR){
				if(name == GOGGLES){
					character.setInfravision(character.infravision - 1);
				}
			}
		}
		
		public function toString():String {
			return nameToString();
		}
		
		override public function nameToString():String {
			var str:String = "";
			if(user && user == g.player) str += "w: ";
			else if(user && user == g.minion) str += "m: ";
			//if(stack > 0) str += stack + "x ";
			//if(level > 0) str += "+" + level + " ";
			
			if(curseState == CURSE_REVEALED) str += "- ";
			else if(effects) str += "+ ";
			
			if(type == RUNE) return str + "rune of " + runeNames[name];
			else if(type == ARMOUR) return str + stats["armour names"][name];
			else if(type == WEAPON) return str + stats["weapon names"][name];
			else if(type == HEART) return Character.stats["names"][name] + " heart";
			//if(effect) str += effect.toString();
			return str
		}
		
		public static function revealName(n:int, inventoryList:InventoryMenuList):void{
			if(runeNames[n] != "?") return;
			runeNames[n] = stats["rune names"][n];
			for(var i:int = 0; i < inventoryList.options.length; i++){
				if((inventoryList.options[i].userData as Item).type == RUNE && (inventoryList.options[i].userData as Item).name == n){
					(inventoryList.options[i] as MenuOptionStack).singleName = (inventoryList.options[i].userData as Item).nameToString();
					(inventoryList.options[i] as MenuOptionStack).total = (inventoryList.options[i] as MenuOptionStack).total;
				}
			}
		}
		override public function remove():void {
			super.remove();
			g.items.splice(g.items.indexOf(this), 1);
		}
		
		/* Is 'item' essentially identical to this Item, suggesting we can stack the two */
		public function stackable(item:Item):Boolean{
			return item != this && item.type == type && item.name == name && item.level == level && !(type == ARMOUR || type == WEAPON);
		}
		
		public function copy():Item{
			return new Item(new (Object(gfx).constructor as Class), name, type, level);
		}
		
		public function getHelpText():String{
			var str:String = "";
			if(type == RUNE){
				str += "this rune ";
				if(runeNames[name] == "?"){
					str += "is unknown\nuse it to discover its power";
				} else {
					str += stats["rune descriptions"][name];
				}
				str += "\nrunes can be cast on items, monsters and yourself"
			} else if(type == ARMOUR){
				str += "this armour is a \nlevel " + level + " ";
				if(curseState == CURSE_REVEALED) str += "cursed ";
				else if(effects) str += "enchanted ";
				str += stats["armour names"][name];
			} else if(type == WEAPON){
				str += "this weapon is a \nlevel " + level + " ";
				if(curseState == CURSE_REVEALED) str += "cursed ";
				else if(effects) str += "enchanted ";
				str += stats["weapon names"][name];
			} else if(type == HEART){
				str += "this level " + level + " " + Character.stats["names"][name] + " heart\nrestores health when eaten";
			}
			return str;
		}
		
		override public function toXML():XML{
			var xml:XML = <item />;
			xml.@name = name;
			xml.@type = type;
			xml.@level = level;
			xml.@location = location;
			xml.@curseState = curseState;
			xml.@user = user ? user.trueNameToString() : "";
			if(effects && effects.length){
				for(var i:int = 0; i < effects.length; i++){
					xml.appendChild(effects[i].toXML());
				}
			}
			
			return xml;
		}
		
		override public function render():void {
			gfx.x = collider.x - bounds.left;
			gfx.y = collider.y - bounds.top;
			super.render();
		}
	}
	
}
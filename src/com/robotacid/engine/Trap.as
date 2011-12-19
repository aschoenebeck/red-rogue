﻿package com.robotacid.engine {
	import com.robotacid.ai.Brain;
	import com.robotacid.dungeon.Content;
	import com.robotacid.dungeon.Map;
	import com.robotacid.geom.Pixel;
	import com.robotacid.gfx.BlitSprite;
	import com.robotacid.gfx.Renderer;
	import com.robotacid.phys.Collider;
	import com.robotacid.sound.SoundManager;
	import com.robotacid.ui.MinimapFX;
	import com.robotacid.util.HiddenInt;
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.DisplayObject;
	import flash.display.Sprite;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	
	/**
	 * Various entities that will attack the player when triggered
	 *
	 * @author Aaron Steed, robotacid.com
	 */
	public class Trap extends Entity{
		
		public var rect:Rectangle;
		public var type:int;
		public var contact:Boolean;
		public var revealed:Boolean;
		public var dartGun:Point;
		public var count:int;
		
		public var disarmingRect:Rectangle;
		public var disarmingContact:Boolean;
		
		private var minimapFX:MinimapFX;
		
		// type flags
		public static const PIT:int = 0;
		public static const POISON_DART:int = 1;
		public static const TELEPORT_DART:int = 2;
		public static const STUPEFY_DART:int = 3;
		public static const MONSTER_PORTAL:int = 4;
		
		public static const PIT_COVER_DELAY:int = 7;
		
		public static const DISARMING_XP_REWARD:Number = 1;
		
		public function Trap(mc:DisplayObject, mapX:int, mapY:int, type:int, dartPos:Pixel = null) {
			super(mc, false, false);
			this.type = type;
			revealed = false;
			if(type == PIT){
				rect = new Rectangle(mapX * Game.SCALE, -1 + mapY * Game.SCALE, SCALE, SCALE);
			} else {
				rect = new Rectangle(mapX * Game.SCALE, -1 + mapY * Game.SCALE, SCALE, 5);
				if(dartPos){
					dartGun = new Point((dartPos.x + 0.5) * Game.SCALE, (dartPos.y + 1) * Game.SCALE);
				}
			}
			disarmingRect = new Rectangle((mapX - 1) * Game.SCALE, -1 + (mapY * Game.SCALE), SCALE * 3, 5);
			callMain = true;
			contact = false;
			disarmingContact = false;
			addToEntities = true;
		}
		
		override public function main():void {
			//Game.debug.drawRect(rect.x, rect.y, rect.width, rect.height);
			// check the player is fully on the trap before springing it
			if(
				g.player.collider.x >= rect.x &&
				g.player.collider.x + g.player.collider.width <= rect.x + rect.width &&
				g.player.collider.y < rect.y + rect.height &&
				g.player.collider.y + g.player.collider.height > rect.y &&
				!g.player.indifferent
			){
				if(!contact){
					contact = true;
					resolveCollision();
				}
			} else if(contact){
				contact = false;
			}
			if(revealed && disarmingRect.intersects(g.player.collider)){
				if(!disarmingContact){
					disarmingContact = true;
					g.player.addDisarmableTrap(this);
				}
			} else if(disarmingContact){
				disarmingContact = false;
				g.player.removeDisarmableTrap(this);
			}
			if(count){
				count--;
				if(count == 0){
					if(type == PIT){
						active = false;
						g.world.map[mapY][mapX] = Collider.UP | Collider.LEDGE;
					}
				}
			}
		}
		
		public function resolveCollision():void {
			if(type == PIT){
				if(count) return;
				count = PIT_COVER_DELAY;
				g.console.print("pit trap triggered");
				renderer.createDebrisRect(rect, 0, 100, Renderer.STONE);
				renderer.shake(0, 3);
				g.soundQueue.add("kill");
				g.world.map[mapY][mapX] = 0;
				g.mapTileManager.removeTile(this, mapX, mapY, mapZ);
				renderer.blockBitmapData.fillRect(new Rectangle(mapX * SCALE, mapY * SCALE, SCALE, SCALE), 0x00000000);
				var blit:BlitSprite = MapTileConverter.ID_TO_GRAPHIC[MapTileConverter.LEDGE_SINGLE];
				blit.x = mapX * SCALE;
				blit.y = mapY * SCALE;
				blit.render(renderer.blockBitmapData);
				// check to see if any colliders are on this and drop them
				var dropped:Vector.<Collider> = g.world.getCollidersIn(rect);
				var dropCollider:Collider;
				for(var i:int = 0; i < dropped.length; i++){
					dropCollider = dropped[i];
					dropCollider.divorce();
				}
				// make sure the player can't disarm a trap that no longer exists
				if(g.player.disarmableTraps.indexOf(this) > -1){
					g.player.removeDisarmableTrap(this);
				}
				disarmingRect = new Rectangle(0, 0, 1, 1);
				// the dungeon graph is currently unaware of a new route
				// we need to educate it by looking down from the node that must be above the
				// pit to the node that must be below it
				for(var r:int = mapY; r < g.dungeon.height; r++){
					if(Brain.dungeonGraph.nodes[r][mapX]){
						Brain.dungeonGraph.nodes[mapY - 1][mapX].connections.push(Brain.dungeonGraph.nodes[r][mapX]);
						break;
					}
				}
				if(!minimapFX) g.miniMap.addFX(mapX, mapY, renderer.featureRevealedBlit);
				else{
					minimapFX.active = false;
					minimapFX = null;
				}
				
			} else if(type == POISON_DART){
				g.console.print("poison trap triggered");
				g.soundQueue.add("throw");
				shootDart(new Effect(Effect.POISON, g.dungeon.level < Game.MAX_LEVEL ? g.dungeon.level : Game.MAX_LEVEL, Effect.THROWN));
			} else if(type == STUPEFY_DART){
				g.console.print("stupefy trap triggered");
				g.soundQueue.add("throw");
				shootDart(new Effect(Effect.STUPEFY, g.dungeon.level < Game.MAX_LEVEL ? g.dungeon.level : Game.MAX_LEVEL, Effect.THROWN));
			} else if(type == TELEPORT_DART){
				g.console.print("teleport trap triggered");
				g.soundQueue.add("throw");
				shootDart(new Effect(Effect.TELEPORT, Game.MAX_LEVEL, Effect.THROWN));
				
			} else if(type == MONSTER_PORTAL){
				g.console.print("monster trap triggered");
				var portal:Portal = Portal.createPortal(Portal.MONSTER, mapX, mapY - 1, g.dungeon.level);
				portal.setMonsterTemplate(Content.createCharacterXML(g.dungeon.level < Game.MAX_LEVEL ? g.dungeon.level : Game.MAX_LEVEL, Character.MONSTER));
				// monster portal traps are triggered once and then destroy themselves
				active = false;
				if(!minimapFX) g.miniMap.addFX(mapX, mapY, renderer.featureRevealedBlit);
				else{
					minimapFX.active = false;
					minimapFX = null;
				}
				return;
			}
			// a trap that still exists after being triggered gets revealed
			if(!revealed && active && type != PIT){
				reveal();
			}
		}
		
		/* Adds a graphic to this trap to show the player where it is and adds a feature to the minimap */
		public function reveal():void{
			var trapRevealedB:Bitmap = new g.library.TrapRevealedB();
			trapRevealedB.y = -SCALE;
			(gfx as Sprite).addChild(trapRevealedB);
			minimapFX = g.miniMap.addFeature(mapX, mapY, renderer.searchFeatureBlit, true);
			revealed = true;
		}
		
		/* Destroys this object and gives xp */
		public function disarm():void{
			if(!active) return;
			active = false;
			if(minimapFX) {
				minimapFX.active = false;
				minimapFX = null;
			}
			g.player.addXP(DISARMING_XP_REWARD * g.dungeon.level);
			g.content.removeTrap(g.dungeon.level, g.dungeon.type);
		}
		
		/* Launches a missile from the ceiling that bears a magic effect */
		public function shootDart(effect:Effect):void{
			var missileMc:DisplayObject = new DartMC();
			var clipRect:Rectangle = new Rectangle(dartGun.x - Game.SCALE * 0.5, dartGun.y, Game.SCALE, (rect.y + 1) - dartGun.y);
			var missile:Missile = new Missile(missileMc, dartGun.x, dartGun.y, Missile.DART, null, 0, 1, 5, Collider.LADDER | Collider.LEDGE | Collider.HEAD | Collider.ITEM | Collider.CORPSE, effect, null, clipRect);
		}
		
	}
	
}
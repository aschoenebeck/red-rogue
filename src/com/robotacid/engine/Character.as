﻿package com.robotacid.engine {
	import com.robotacid.ai.Brain;
	import com.robotacid.gfx.ItemMovieClip;
	import com.robotacid.gfx.Renderer;
	import com.robotacid.phys.Collider;
	import com.robotacid.sound.SoundManager;
	import com.robotacid.util.clips.localToLocal;
	import com.robotacid.util.HiddenInt;
	import com.robotacid.util.HiddenNumber;
	import flash.display.DisplayObject;
	import flash.display.DisplayObjectContainer;
	import flash.display.MovieClip;
	import flash.display.Sprite;
	import flash.geom.ColorTransform;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	
	/**
	 * This is the base class for all creatures in the game - including the player.
	 *
	 * By levelling the playing field we get creatures that behave like the player -
	 * and as a bonus the player can transform into them with magic
	 *
	 * @author Aaron Steed, robotacid.com
	 */
	public class Character extends ColliderEntity{
		
		public var loot:Vector.<Item>;
		public var effects:Vector.<Effect>;
		public var effectsBuffer:Vector.<Effect>;
		public var portal:Portal;
		public var weapon:Item;
		public var armour:Item;
		public var brain:Brain;
		
		// states
		public var level:int;
		public var type:int
		public var state:int;
		public var dir:int;
		public var looking:int;
		public var actions:int;
		public var moving:Boolean;
		public var attackSpeed:Number;
		public var attackCount:Number;
		public var stunCount:Number;
		public var mapProperties:int;
		public var moveFrame:int;
		public var moveCount:int;
		public var quickeningCount:int;
		public var tileCenter:Number;
		public var victim:Character;
		public var stepNoise:Boolean;
		public var crushed:Boolean;
		public var undead:Boolean;
		public var inTheDark:Boolean;
		public var debrisType:int;
		public var missileIgnore:int;
		public var infravisionRenderState:int;
		
		// stats
		public var speed:Number;
		public var health:Number;
		public var totalHealth:Number;
		public var damage:Number;
		public var xpReward:Number;
		public var attack:Number;
		public var defence:Number;
		public var stun:Number;
		public var knockback:Number;
		public var endurance:Number;
		public var infravision:int;
		public var leech:Number;
		
		private var hitResult:int;
		
		// type flags - do not refactor from bitwise, the AI checks for (PLAYER | MINION)
		public static const PLAYER:int = 1;
		public static const MONSTER:int = 1 << 1;
		public static const MINION:int = 1 << 2;
		public static const STONE:int = 1 << 3;
		
		// character names
		public static const ROGUE:int = 0;
		public static const SKELETON:int = 1;
		public static const KOBOLD:int = 2;
		public static const GOBLIN:int = 3;
		public static const ORC:int = 4;
		public static const TROLL:int = 5;
		
		// states
		public static const WALKING:int = 1;
		public static const LUNGING:int = 2;
		public static const DEAD:int = 3;
		public static const QUICKENING:int = 4;
		public static const EXITING:int = 5;
		public static const ENTERING:int = 6;
		public static const STUNNED:int = 7;
		
		public static const MOVE_DELAY:int = 3;
		
		// physics constants
		public static const GRAVITY:Number = 0.8;
		public static const DAMPING_Y:Number = 0.99;
		public static const DAMPING_X:Number = 0.45;
		public static const THROW_SPEED:Number = 16;
		
		public static const LADDER_WIDTH:Number = 10;
		public static const LADDER_RIGHT:Number = 12;
		public static const LADDER_LEFT:Number = 3;
		
		public static const PORTAL_STEPS:int = 8;
		public static const PORTAL_SPEED:Number = 2;
		public static const PORTAL_DISTANCE:Number = PORTAL_SPEED * PORTAL_STEPS;
		
		public static const UP:int = 1;
		public static const RIGHT:int = 2;
		public static const DOWN:int = 4;
		public static const LEFT:int = 8;
		
		// hit flags
		public static const MISS:int = 0;
		public static const HIT:int = 1 << 0;
		public static const CRITICAL:int = 1 << 1;
		public static const STUN:int = 1 << 2;
		
		public static const CRITICAL_HIT:Number = 0.94;
		public static const CRITICAL_MISS:Number = 0.05;
		public static const QUICKENING_DELAY:int = 90;
		public static const STUN_DECAY:Number = 1.0 / 90; // The denominator is maximum duration of stun in frames
		
		public static const DEFAULT_COL:ColorTransform = new ColorTransform();
		public static const INFRAVISION_COLS:Vector.<ColorTransform> = Vector.<ColorTransform>([DEFAULT_COL, new ColorTransform(1, 0, 0, 1, 255), new ColorTransform(1, 0.7, 0.7, 1, 50)]);
		
		public static var p:Point = new Point();
		
		[Embed(source = "characterStats.json", mimeType = "application/octet-stream")] public static var statsData:Class;
		public static var stats:Object;
		
		public function Character(gfx:DisplayObject, x:Number, y:Number, name:int, type:int, level:int, addToEntities:Boolean = true) {
			super(gfx, addToEntities);
			
			this.name = name;
			this.level = level;
			this.type = type;
			
			createCollider(x, y, Collider.CHARACTER | Collider.SOLID, Collider.CORPSE | Collider.ITEM);
			
			state = WALKING;
			stepNoise = false;
			attackCount = 1;
			moving = false;
			moveCount = 0;
			moveFrame = 0;
			mapProperties = 0;
			callMain = true;
			inTheDark = false;
			missileIgnore = Collider.LADDER | Collider.LEDGE | Collider.CORPSE | Collider.ITEM | Collider.HEAD;
			
			setStats();
			
			loot = new Vector.<Item>();
		}
		
		/* Initialise a character's abilities and statistics */
		public function setStats():void{
			// the character's equipment needs to be removed whilst stats are applied
			var weaponTemp:Item, armourTemp:Item;
			if(weapon) weaponTemp = unequip(weapon);
			if(armour) armourTemp = unequip(armour);
			
			health = stats["healths"][name] + stats["health levels"][name] * level;
			totalHealth = health;
			attack = stats["attacks"][name] + stats["attack levels"][name] * level;
			defence = stats["defences"][name] + stats["defence levels"][name] * level;
			attackSpeed = stats["attack speeds"][name] + stats["attack speed levels"][name] * level;
			damage = stats["damages"][name] + stats["damage levels"][name] * level;
			speed = stats["speeds"][name] + stats["speed levels"][name] * level;
			xpReward = stats["xp rewards"][name] + stats["xp reward levels"][name] * level;
			stun = stats["stuns"][name];
			knockback = stats["knockbacks"][name];
			endurance = stats["endurance"][name];
			undead = name == SKELETON;
			debrisType = name == SKELETON ? Renderer.BONE : Renderer.BLOOD;
			
			if(true){
				setInfravision(0);
			} else {
				setInfravision(0);
			}
			
			if(true){
				leech = 0;
			} else {
				leech = 0;
			}
			
			// re-equip
			if(weaponTemp) equip(weaponTemp);
			if(armourTemp) equip(armourTemp);
		}
		
		override public function createCollider(x:Number, y:Number, properties:int, ignoreProperties:int, state:int = 0, positionByBase:Boolean = true):void {
			super.createCollider(x, y, properties, ignoreProperties, state, positionByBase);
			collider.crushCallback = death;
			if(!(type & STONE)){
				collider.stompCallback = stompCallback;
			}
		}
		
		override public function main():void{
			
			move();
			
			// lighting check - if the monster is in total darkness, we need not tend to their animation
			// and making them invisible will help the lighting engine conceal their presence.
			// however - if they are moving, they may "pop" in and out of darkness, so we check around them
			// for light
			if(light || g.dungeon.level <= 0) inTheDark = false;
			else{
				if(dir == 0){
					if(g.lightMap.darkImage.getPixel32(mapX, mapY) != 0xFF000000) inTheDark = false;
					else inTheDark = true;
				} else if(dir & (RIGHT | LEFT)){
					if(g.lightMap.darkImage.getPixel32(mapX, mapY) != 0xFF000000 || g.lightMap.darkImage.getPixel32(mapX + 1, mapY) != 0xFF000000 || g.lightMap.darkImage.getPixel32(mapX - 1, mapY) != 0xFF000000) inTheDark = false;
					else inTheDark = true;
				} else if(dir & (UP | DOWN)){
					if(g.lightMap.darkImage.getPixel32(mapX, mapY) != 0xFF000000 || g.lightMap.darkImage.getPixel32(mapX, mapY + 1) != 0xFF000000 || g.lightMap.darkImage.getPixel32(mapX, mapY - 1) != 0xFF000000) inTheDark = false;
					else inTheDark = true;
				}
			}
			
			// set visibility - account for player infravision and changes to their infravision
			// this is handled here instead of at the rendering stage to save us the cost of the method call
			// to get into the rendering method
			gfx.visible = !inTheDark || (g.player.infravision);
			var targetInfravisionRenderState:int = !inTheDark ? 0 : g.player.infravision;
			if(infravisionRenderState != targetInfravisionRenderState){
				gfx.transform.colorTransform = INFRAVISION_COLS[targetInfravisionRenderState];
				infravisionRenderState = targetInfravisionRenderState;
			}
		}
		
		// This chunk is the core state machine for all Characters
		protected function move():void{
			
			tileCenter = (mapX + 0.5) * SCALE;
			var mc:MovieClip = gfx as MovieClip;
			
			// react to direction state
			if(state == WALKING){
				if(collider.state == Collider.STACK || collider.state == Collider.FALL) moving = Boolean(dir & (LEFT | RIGHT));
				else if(collider.state == Collider.HOVER) moving = Boolean(dir & (UP | DOWN));
			}
			// moving left or right
			if(state == WALKING){
				if(dir & RIGHT) collider.vx += speed;
				else if(dir & LEFT) collider.vx -= speed;
				// climbing
				if(dir & UP){
					if(canClimb() && !(collider.parent && (collider.parent.properties & Collider.LEDGE) && !(mapProperties & Collider.LADDER))){
						collider.divorce();
						collider.state = Collider.HOVER;
					}
				}
				// dropping through ledges and climbing down
				if(dir & DOWN){
					if(collider.parent && (collider.parent.properties & Collider.LEDGE)){
						collider.ignoreProperties |= Collider.LEDGE;
						collider.divorce();
						if(canClimb()){
							collider.state = Collider.HOVER;
						}
					}
				} else if(collider.ignoreProperties & Collider.LEDGE){
					collider.ignoreProperties &= ~Collider.LEDGE;
				}
			}

			// COMBAT =====================================================================================
			
			if(state == WALKING){
				if(collider.state == Collider.STACK || collider.state == Collider.FALL){
					if(collider.leftContact || collider.rightContact){
						var target:Character = null;
						if((dir & LEFT) && collider.leftContact && (collider.leftContact.properties & Collider.CHARACTER) && enemy(collider.leftContact.userData)){
							target = collider.leftContact.userData as Character;
						} else if((dir & RIGHT) && collider.rightContact && (collider.rightContact.properties & Collider.CHARACTER) && enemy(collider.rightContact.userData)){
							target = collider.rightContact.userData as Character;
						}
						if(target){
							moving = false;
							if(attackCount >= 1){
								
								hitResult = hit(target, Item.MELEE);
								if(hitResult){
									if(!(target.type & STONE)) target.collider.pushDamping = 1;
									if(weapon && weapon.effects && target.active && !(target.type & STONE)){
										target.applyWeaponEffects(weapon);
									}
									var meleeWeapon:Boolean = Boolean(weapon && (weapon.range & Item.MELEE));
									var hitDamage:Number = damage + (meleeWeapon ? weapon.damage : 0);
									if(hitResult & CRITICAL) hitDamage *= 2;
									var enduranceDamping:Number = 1.0 - (target.endurance + (target.armour ? target.armour.endurance : 0));
									if(enduranceDamping < 0) enduranceDamping = 0;
									var hitKnockback:Number = (knockback + (meleeWeapon ? weapon.knockback : 0)) * enduranceDamping;
									if(dir & LEFT) hitKnockback = -hitKnockback;
									target.applyDamage(hitDamage, nameToString(), hitKnockback, Boolean(hitResult & CRITICAL), type);
									if(leech){
										var leechValue:Number = leech > 1 ? 1 : leech;
										applyHealth(leechValue * hitDamage);
									}
									if(hitResult & STUN){
										var hitStun:Number = (stun + (meleeWeapon ? weapon.stun : 0)) * enduranceDamping;
										if(hitStun) target.applyStun(hitStun);
									}
									g.soundQueue.add("hit");
									
									p.x = gfx.x + (mc.weapon ? mc.weapon.x : 0);
									p.y = gfx.y + (mc.weapon ? mc.weapon.y : 0);
									if(dir & RIGHT){
										renderer.createDebrisSpurt(p.x < target.collider.x ? p.x : target.collider.x - 1, p.y, -2, 8, target.debrisType);
									} else if(dir & LEFT){
										renderer.createDebrisSpurt(p.x >= target.collider.x + target.collider.width ? p.x : target.collider.x + target.collider.width, p.y, 2, 8, target.debrisType);
									}
								} else {
									g.soundQueue.add("miss");
								}
								if(state != QUICKENING) state = LUNGING;
							}
							victim = target;
						}
					}
				} else if(collider.state == Collider.HOVER){
					if(canClimb()){
						// a character always tries to center itself on a ladder
						if((dir & UP)){
							collider.vy = -speed;
							centerOnTile();
						} else if(dir & DOWN){
							collider.vy = speed;
							centerOnTile();
						} else if(dir & (RIGHT | LEFT)){
							state = WALKING;
							collider.state = Collider.FALL;
						} else {
							collider.vy = 0;
						}
						if(collider.parent){
							state = WALKING;
							dir &= ~(UP | DOWN);
						}
					} else {
						state = WALKING;
						collider.state = Collider.FALL;
						dir &= ~(UP | DOWN);
						collider.vy = 0;
					}
				}
			} else if(state == STUNNED){
				stunCount -= STUN_DECAY;
				if(stunCount <= 0){
					state = WALKING;
				}
			} else if(state == LUNGING){
				if(attackCount > 0.5){
					state = WALKING;
				}
			} else if(state == QUICKENING){
				collider.vy = -1.5;
				var colTrans:ColorTransform = gfx.transform.colorTransform;
				colTrans.redOffset += 4;
				colTrans.greenOffset += 4;
				colTrans.blueOffset += 4;
				gfx.transform.colorTransform = colTrans;
				var node:Character;
				var tx:Number, ty:Number;
				// lightning from the right hand
				if(mc.weapon && mc.leftHand) {
					p.x = mc.x + (mc.scaleX == 1 ? mc.weapon.x : -mc.leftHand.x);
					p.y = mc.y + mc.weapon.y;
					node = null;
					if(type == MINION || type == PLAYER){
						if(Brain.monsterCharacters.length){
							node = Brain.monsterCharacters[g.random.rangeInt(Brain.monsterCharacters.length)];
						}
					} else if(type == MONSTER){
						if(Brain.playerCharacters.length){
							node = Brain.playerCharacters[g.random.rangeInt(Brain.playerCharacters.length)];
						}
					}
					if(!node || !node.active || node.collider.x + node.collider.width * 0.5 < collider.x + collider.width * 0.5){
						node = null;
						tx = g.mapRenderer.width * SCALE;
						ty = g.random.range(g.mapRenderer.height) * SCALE;
					} else {
						tx = node.collider.x + node.collider.width * 0.5;
						ty = node.collider.y + node.collider.height * 0.5;
					}
					if(g.lightning.strike(renderer.lightningShape.graphics, g.world.map, p.x, p.y, tx, ty) && node && enemy(node.collider.userData)){
						node.applyDamage(g.random.value(), "quickening");
						renderer.createDebrisSpurt(tx, ty, 5, 5, node.debrisType);
					}
					// lightning from the left hand
					p.x = mc.x + (mc.scaleX == 1 ? mc.leftHand.x : -mc.weapon.x);
					p.y = mc.y + mc.leftHand.y;
					node = null;
					if(type == MINION || type == PLAYER){
						if(Brain.monsterCharacters.length){
							node = Brain.monsterCharacters[g.random.rangeInt(Brain.monsterCharacters.length)];
						}
					} else if(type == MONSTER){
						if(Brain.playerCharacters.length){
							node = Brain.playerCharacters[g.random.rangeInt(Brain.playerCharacters.length)];
						}
					}
					if(!node || !node.active || node.collider.x + node.collider.width * 0.5 > collider.x + collider.width * 0.5){
						node = null;
						tx = 0;
						ty = g.random.range(g.mapRenderer.height) * SCALE;
					} else {
						tx = node.collider.x + node.collider.width * 0.5;
						ty = node.collider.y + node.collider.height * 0.5;
					}
					if(g.lightning.strike(renderer.lightningShape.graphics, g.world.map, p.x, p.y, tx, ty) && node && enemy(node.collider.userData)){
						node.applyDamage(g.random.value(), "quickening");
						renderer.createDebrisSpurt(tx, ty, -5, 5, node.debrisType);
					}
				}
				if(quickeningCount-- <= 0){
					state = WALKING;
					gfx.transform.colorTransform = new ColorTransform();
					if(this is Player) g.console.print("welcome to level " + level + " " + nameToString());
				}
			} else if(state == ENTERING){
				moving = true;
				if(portal.type == Portal.UP){
					if(moveCount){
						if(dir == RIGHT) gfx.x += PORTAL_SPEED;
						else if(dir == LEFT) gfx.x -= PORTAL_SPEED;
						gfx.y += PORTAL_SPEED;
					}
					if(gfx.y >= (portal.mapY + 1) * Game.SCALE) portal = null;
				} else if(portal.type == Portal.DOWN){
					if(moveCount){
						if(dir == RIGHT) gfx.x += PORTAL_SPEED;
						else if(dir == LEFT) gfx.x -= PORTAL_SPEED;
						gfx.y -= PORTAL_SPEED;
					}
					if(gfx.y <= (portal.mapY + 1) * Game.SCALE) portal = null;
				} else if(portal.type == Portal.SIDE){
					if(dir == RIGHT){
						gfx.x += PORTAL_SPEED;
						if(gfx.x > (portal.mapX + 0.5) * Game.SCALE) portal = null;
					} else if(dir == LEFT){
						gfx.x -= PORTAL_SPEED;
						if(gfx.x > (portal.mapX + 0.5) * Game.SCALE) portal = null;
					}
				}
				if(!portal){
					g.world.restoreCollider(collider);
					collider.state = Collider.FALL;
					state = WALKING;
				}
			}
			//trace(g.blockMap[((rect.y + rect.height - 1) * INV_SCALE) >> 0][mapX] & Block.LADDER);
			//trace(mapX);
			
			if(attackCount < 1){
				attackCount += attackSpeed;
			}
			if(dir) collider.awake = Collider.AWAKE_DELAY;
		}
		
		private function stompCallback(stomper:Collider):void{
			applyStun(0.5);
			var center:Number = collider.x + collider.width * 0.5;
			var stomperCenter:Number = stomper.x + stomper.width * 0.5;
			if(center < stomperCenter){
				collider.vx -= stomper.width + stomper.userData.knockback;
			} else {
				collider.vx += stomper.width + stomper.userData.knockback;
			}
		}
		
		/* Kill the Character, printing a cause to the console and generating a Head object
		 * on decapitation. Decapitation is meant to occur only via hand to hand combat */
		public function death(cause:String = "crushing", decapitation:Boolean = false, aggressor:int = 0):void{
			active = false;
			renderer.createDebrisRect(collider, 0, 32, debrisType);
			var method:String = decapitation ? "decapitated" : stats["death strings"][name];
			
			//decapitation = true;
			
			if(decapitation){
				var head:Head = new Head(this, totalHealth * 0.5);
				var corpse:Corpse = new Corpse(this);
			}
			g.console.print(stats["names"][name] + " " + method + " by " + cause);
			renderer.shake(0, 3);
			g.soundQueue.add("kill");
			if(type == MONSTER) g.player.addXP(xpReward);
			if(effects) removeEffects();
			if(!active) collider.world.removeCollider(collider);
		}
		
		/* Enter the level via a portal */
		public function enterLevel(portal:Portal, dir:int = RIGHT):void{
			this.portal = portal;
			if(dir == RIGHT){
				gfx.x = (portal.mapX + 0.5) * Game.SCALE - PORTAL_DISTANCE;
			} else if(dir == LEFT){
				gfx.x = (portal.mapX + 0.5) * Game.SCALE + PORTAL_DISTANCE;
			}
			if(portal.type == Portal.DOWN){
				gfx.y = (portal.mapY + 1) * Game.SCALE + PORTAL_DISTANCE;
			} else if(portal.type == Portal.UP){
				gfx.y = (portal.mapY + 1) * Game.SCALE - PORTAL_DISTANCE;
			} else if(portal.type == Portal.SIDE){
				gfx.y = (portal.mapY + 1) * Game.SCALE;
			}
			this.dir = looking = dir;
			state = ENTERING;
			
			// reinitialise equipment animations
			if(armour && armour.gfx is ItemMovieClip) (armour.gfx as ItemMovieClip).setEquipRender();
			if(weapon && weapon.gfx is ItemMovieClip) (weapon.gfx as ItemMovieClip).setEquipRender();
		}
		
		/* Advances the character to the next level */
		public function levelUp():void{
			level++;
			setStats();
			applyHealth(totalHealth);
			quicken();
		}
		
		/* This method kicks off a character's quickening state. Whilst a character quickens, they
		 * send out lightning bolts from their hands and float up to the ceiling */
		public function quicken():void{
			state = QUICKENING;
			dir = RIGHT;
			collider.divorce();
			quickeningCount = QUICKENING_DELAY;
		}
		
		/* Used to auto-center when climbing */
		public function centerOnTile():void{
			var colliderCenter:Number = collider.x + collider.width * 0.5;
			if(colliderCenter > tileCenter) collider.vx = colliderCenter - speed > tileCenter ? -speed : tileCenter - colliderCenter;
			else if(colliderCenter < tileCenter) collider.vx = colliderCenter + speed < tileCenter ? speed : tileCenter - colliderCenter;
		}
		
		/* The logic to validate climbing is pretty convoluted so it resides in another method,
		 * this goes against all my normal programming style, but I can still inline this
		 * shit if I'm in a pinch */
		public function canClimb():Boolean{
			return ((mapProperties & Collider.LADDER) ||
			(g.world.map[((collider.y + collider.height + Collider.INTERVAL_TOLERANCE) * INV_SCALE) >> 0][mapX] & Collider.LADDER)) &&
			collider.x + collider.width >= LADDER_LEFT + mapX * SCALE &&
			collider.x <= LADDER_RIGHT + mapX * SCALE;
		}
		
		/* This reactivates any buffered effects  */
		public function restoreEffects(): void{
			if(effectsBuffer){
				var effect:Effect;
				for(var i:int = 0; i < effectsBuffer.length; i++){
					effect = effectsBuffer[i];
					effect.apply(this);
				}
				effectsBuffer = null;
			}
		}
		
		/* This buffers effects while the characters sleeps out of range of the renderer */
		public function bufferEffects(): void{
			while(effects && effects.length){
				effects[0].dismiss(true);
			}
		}
		
		/* This deactivates all effects - used in the event of death */
		public function removeEffects(): void{
			while(effects && effects.length){
				effects[0].dismiss();
			}
		}
		
		/* Select an item as a weapon or armour */
		public function equip(item:Item):Item{
			if(item.type == Item.WEAPON){
				if(weapon) return null;
				weapon = item;
			}
			if(item.type == Item.ARMOUR){
				if(armour) return null;
				armour = item;
				if(item.effects){
					for(var i:int = 0; i < item.effects.length; i++){
						item.effects[i].apply(this);
					}
				}
				armour.gfx.x = armour.gfx.y = 0;
			}
			
			item.addBuff(this);
			
			item.location = Item.EQUIPPED;
			item.user = this;
			(gfx as Sprite).addChild(item.gfx);
			if(item.gfx is ItemMovieClip) (item.gfx as ItemMovieClip).setEquipRender();
			return item;
		}
		
		/* Unselect item as equipped */
		public function unequip(item:Item):Item{
			if(item != armour && item != weapon) return null;
			var i:int;
			for(i = 0; i < (gfx as MovieClip).numChildren; i++){
				if((gfx as MovieClip).getChildAt(i) == item.gfx){
					(gfx as MovieClip).removeChildAt(i);
					break;
				}
			}
			if(item == armour){
				if(item.effects){
					for(i = 0; i < item.effects.length; i++){
						item.effects[i].dismiss();
					}
				}
				armour = null;
			}
			if(item == weapon) weapon = null;
			
			item.removeBuff(this);
			
			item.location = Item.INVENTORY;
			item.user = null;
			return item;
		}
		
		/* Drops an item from the Character's loot */
		public function dropItem(item:Item):void{
			var n:int = loot.indexOf(item);
			if(n > -1) loot.splice(n, 1);
		}
		
		/* Determine if we have hit another character */
		public function hit(character:Character, range:int):int{
			attackCount = 0;
			var attackRoll:Number = g.random.value();
			if(attackRoll >= CRITICAL_HIT)
				return CRITICAL | STUN;
			else if(attackRoll <= CRITICAL_MISS)
				return MISS;
			else if(attack + attackRoll + (weapon && (weapon.range & range) ? weapon.attack : 0) > character.defence + (character.armour ? character.armour.defence : 0)){
				// stun roll
				var enduranceDamping:Number = 1.0 - (character.endurance + (character.armour ? character.armour.endurance : 0));
				var stunCheck:Number = (stun + (weapon && (weapon.range & range) ? weapon.stun : 0)) * enduranceDamping;
				if(stunCheck && g.random.value() <= stunCheck) return HIT | STUN;
				return HIT;
			}
				
			return MISS;
		}
		
		/* Effect stun state on this character */
		public function applyStun(delay:Number):void{
			stunCount = delay;
			state = STUNNED;
			if(collider.state == Collider.HOVER){
				collider.state = Collider.FALL;
			}
		}
		
		/* Loose a missile, could be an arrow or a rune */
		public function shoot(type:int, effect:Effect = null):void{
			if(attackCount < 1) return;
			state = LUNGING;
			attackCount = 0;
			var missileMc:DisplayObject;
			var item:Item;
			if(type == Missile.ITEM){
				if(weapon.range & Item.MISSILE){
					missileMc = new weapon.missileGfxClass();
					item = weapon;
				} else if(weapon.range & Item.THROWN){
					item = unequip(weapon);
					item = g.menu.inventoryList.removeItem(item);
					item.location = Item.FLIGHT;
					missileMc = item.gfx;
				}
			} else if(type == Missile.RUNE){
				missileMc = new ThrownRuneMC();
			}
			if(type == Missile.ITEM) {
				g.soundQueue.add("bowShoot");
			} else if (type == Missile.RUNE){
				g.soundQueue.add("throw");
			}
			var missile:Missile = new Missile(missileMc, collider.x + collider.width * 0.5, collider.y + collider.height * 0.5, type, this, (looking & RIGHT) ? 1 : -1, 0, 5, missileIgnore, effect, item);
		}
		
		/* Adds damage to the Character */
		public function applyDamage(n:Number, source:String, knockback:Number = 0, critical:Boolean = false, aggressor:int = 0):void{
			// killing a character on a set of stairs could crash the game
			if(state == ENTERING || state == EXITING || state == QUICKENING) return;
			health-= n;
			if(critical) renderer.shake(0, 5);
			if(health <= 0){
				death(source, critical, aggressor);
			} else if(knockback){
				collider.vx += knockback;
			}
		}
		
		public function applyHealth(n:Number):void{
			health += n;
			if(health > totalHealth) health = totalHealth;
		}
		
		public function applyWeaponEffects(item:Item):void{
			if(item.effects){
				var effect:Effect;
				for(var i:int = 0; i < item.effects.length; i++){
					effect = item.effects[i];
					if(effect.applicable) effect.copy().apply(this);
				}
			}
		}
		
		public function enemy(target:Character):Boolean{
			if(type & (PLAYER | MINION)) return Boolean(target.type & (MONSTER | STONE));
			else if(type & MONSTER) return Boolean(target.type & (PLAYER | MINION));
			return false;
		}
		
		/* Activate the infravision stat on a Character - affects Minion, Monster and Player differently
		 * Player's see the lightMap differently and see monsters in the dark in red, monsters get superior
		 * vision in their Brain calculations */
		public function setInfravision(value:int):void{
			if(value == infravision) return;
			var i:int, character:Character;
			infravision = value;
			if(this is Player){
				if(infravision){
					if(infravision == 1){
						renderer.lightBitmap.alpha = 0.86;
					} else if(infravision == 2){
						renderer.lightBitmap.alpha = 0.44;
					}
				} else {
					renderer.lightBitmap.alpha = 1;
				}
			} else {
				brain.losBorder = Brain.DEFAULT_LOS_BORDER + infravision * Brain.INFRAVISION_LOS_BORDER_BONUS;
			}
		}
		
		public function changeName(name:int, gfx:MovieClip = null):void{
			if(this.name == name && !gfx) return;
			
			// change gfx
			this.name = name;
			if(!gfx){
				this.gfx = gfx = g.library.getCharacterGfx(name);
			} else{
				this.gfx = gfx;
			}
			
			// change physics
			var restore:Boolean = false;
			if(collider.world){
				collider.world.removeCollider(collider);
				restore = true;
			}
			createCollider(collider.x + collider.width * 0.5, collider.y + collider.height, collider.properties, collider.ignoreProperties, Collider.FALL);
			if(restore) g.world.restoreCollider(collider);
			
			// change stats - items will be equipped to the new graphic in the setStats method
			var originalHealthRatio:Number = health / totalHealth;
			setStats();
			health = 0;
			applyHealth(originalHealthRatio * totalHealth);
			
		}
		
		override public function toXML():XML {
			var xml:XML = <character />;
			xml.@name = name;
			xml.@type = type;
			xml.@level = level;
			xml.@health = health;
 			if(effects && effects.length){
				for(var i:int = 0; i < effects.length; i++){
					if(effects[i].source != Effect.ARMOUR){
						xml.appendChild(effects[i].toXML());
					}
				}
			}
			return xml;
		}
		
		override public function nameToString():String {
			return stats["names"][name];
		}
		
		public function trueNameToString():String {
			if(this is Player) return "rogue";
			else if(this is Minion) return "minion";
			return stats["names"][name];
		}
		
		override public function remove():void {
			if(effects){
				bufferEffects();
			}
			super.remove();
		}
		
		override public function render():void{
			
			var mc:MovieClip = gfx as MovieClip
			
			if(!portal){
				gfx.x = ((collider.x + collider.width * 0.5) + 0.5) >> 0;
				gfx.y = ((collider.y + collider.height) + 0.5) >> 0;
			}
			if ((looking & LEFT) && mc.scaleX != -1) mc.scaleX = -1;
			else if ((looking & RIGHT) && mc.scaleX != 1) mc.scaleX = 1;
			
			// pace movement
			if(state == WALKING || state == EXITING || state == ENTERING){
				if(!moving) moveCount = 0;
				else {
					if(stepNoise && moving && moveCount == 0 && moveFrame == 0){
						g.soundQueue.add("step");
					}
					moveCount = (moveCount + 1) % MOVE_DELAY;
					// flip between climb frames as we move
					if(moveCount == 0) moveFrame ^= 1;
				}
			}
			if(state == WALKING){
				if(collider.state == Collider.STACK){
					if(moving){
						if(moveFrame){
							if(mc.currentLabel != "move1") mc.gotoAndStop("move1");
						} else {
							if(mc.currentLabel != "move0") mc.gotoAndStop("move0");
						}
					} else {
						if(mc.currentLabel != "idle"){
							mc.gotoAndStop("idle");
						}
					}
				} else if(collider.state == Collider.FALL){
					if(mc.currentLabel != "move1"){
						mc.gotoAndStop("move1");
					}
				} else if(collider.state == Collider.HOVER){
					if(moveFrame){
						if(mc.currentLabel != "climb1") mc.gotoAndStop("climb1");
					} else {
						if(mc.currentLabel != "climb0") mc.gotoAndStop("climb0");
					}
				}
			} else if(state == LUNGING){
				if(mc.currentLabel != "lunge") mc.gotoAndStop("lunge");
				
			} else if(state == QUICKENING){
				if(mc.currentLabel != "quicken") mc.gotoAndStop("quicken");
				
			} else if(state == EXITING || state == ENTERING){
				if(moveFrame){
					if(mc.currentLabel != "move1") mc.gotoAndStop("move1");
				} else {
					if(mc.currentLabel != "move0") mc.gotoAndStop("move0");
				}
			} else if(state == STUNNED){
				if(mc.currentLabel != "stun") mc.gotoAndStop("stun");
			}
			
			if(gfx.alpha < 1){
				gfx.alpha += 0.1;
			}
			if(weapon){
				if((gfx as MovieClip).weapon){
					weapon.gfx.x = mc.weapon.x;
					weapon.gfx.y = mc.weapon.y;
					if(collider.state == Collider.HOVER) weapon.gfx.visible = false;
					else weapon.gfx.visible = true;
				}
				if(weapon.gfx is ItemMovieClip){
					(weapon.gfx as ItemMovieClip).render(this, mc);
				}
			}
			if(armour){
				if((gfx as MovieClip).armour){
					if(armour.position == Item.HAT){
						armour.gfx.x = mc.armour.x;
						armour.gfx.y = mc.armour.y;
					}
				}
				if(armour.gfx is ItemMovieClip){
					(armour.gfx as ItemMovieClip).render(this, mc);
				}
			}
			// armour may render the gfx non-visible
			if(gfx.visible){
				if(portal){
					var clipRect:Rectangle = new Rectangle( -renderer.bitmap.x + portal.rect.x, -renderer.bitmap.y + portal.rect.y, portal.rect.width, portal.rect.height);
					matrix = gfx.transform.matrix;
					matrix.tx -= renderer.bitmap.x;
					matrix.ty -= renderer.bitmap.y;
					renderer.bitmapData.draw(gfx, matrix, gfx.transform.colorTransform, null, clipRect);
				} else {
					super.render();
					// render stars above a character's head when they are stunned
					if(state == STUNNED){
						renderer.stunBlit.x = -renderer.bitmap.x + gfx.x;
						renderer.stunBlit.y = -renderer.bitmap.y + gfx.y - (collider.height + 2);
						renderer.stunBlit.render(renderer.bitmapData, g.frameCount % renderer.stunBlit.totalFrames);
					}
				}
			}
		}
		
	}
	
}
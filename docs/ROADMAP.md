# Development roadmap

## Foundation
- [x] Godot 4 project structure
- [x] Third-person survivor controller and follow camera
- [x] Touch movement/look input and fire button
- [x] Basic zombie chase, melee damage, and health
- [x] Procedural graybox abandoned district

## Character quality and animation
- [ ] Replace graybox survivor and zombies with original, detailed 3D character models
- [ ] Build full-body rigs with clearly modeled face, eyes, nose, ears, hands, individual fingers, feet, and shoes
- [ ] Add natural animation states: idle, walk, run, sprint, turn, look around, jump, land, crouch, climb, attack, aim, reload, hit, and death
- [ ] Add head/eye look-at, facial expressions, and secondary motion for hair and clothing
- [ ] Add collision-aware movement and interaction so characters do not pass through solid world objects
- [ ] Add varied outfits, shoes, and equipment; allow player customization
- [ ] Use the player's supplied photo only if the family later chooses to provide one; keep a placeholder character until then

## World, physics, and vehicles
- [ ] Replace graybox environment with detailed original buildings, roads, interiors, parks, sports areas, public hangouts, and exploration locations
- [ ] Add solid collision to buildings, walls, vehicles, props, and other obstacles; add appropriate interaction points
- [ ] Add water bodies and water-edge/interaction behavior
- [ ] Add usable vehicles with enter/exit, driving controls, camera, collision, and vehicle audio
- [ ] Add loot, doors, pickups, destructible or movable props where appropriate

## Weapons, gameplay, and story
- [ ] Add multiple weapon classes, including firearms and melee weapons such as knives, with distinct handling and animations
- [ ] Add weapon models, aiming, firing, reload, muzzle flash, impact effects, and balanced ammo behavior
- [ ] Create a coherent age-appropriate survival-adventure story, missions, objectives, characters, rewards, and progression
- [ ] Keep zombie encounters adventurous rather than graphically gory, suitable for the intended young player
- [ ] Add inventory, equipment, save/load, and mission tracking

## Audio and atmosphere
- [x] Add initial offline synthesized sound effects for footsteps, jump, landing, weapon fire, reload, zombie attack, hit, and defeat
- [ ] Expand coordinated sound effects by surface, vehicles, doors, weather, and interactions
- [ ] Add varied zombie vocalizations, ambient world audio, music, and optional Filipino voice lines
- [x] Generate initial sound effects locally at runtime so they are included in offline builds
- [ ] Verify sound levels, overlap, and playback on a physical Android device
- [ ] Add day, afternoon, sunset, night, rain, and changing weather with matching lighting, ambience, and shadows

## Mobile UI, settings, and performance
- [ ] Polish landscape mobile HUD with a left movement joystick and right camera/action controls that do not obscure gameplay
- [ ] Add settings for graphics quality, sound/music/voice volume, control sensitivity, and accessibility
- [ ] Add graphics presets and device-specific performance profiling
- [ ] Optimize models, textures, lighting, animation, audio, and world streaming for stable Android performance
- [ ] Test touch controls, audio, collisions, vehicles, save/load, and performance on a physical Android device

## Android delivery
- [ ] Configure Android export and produce a sample APK
- [ ] Verify installation, launch, landscape orientation, and core gameplay on a physical device
- [ ] Publish a test build only after a successful export; do not describe an APK as ready before an artifact exists

The current geometry is a functional blockout, not final art. The items above are planned production milestones, not claims that these systems are already implemented. Build quality and visual detail will be balanced against the target Android device's performance and storage.

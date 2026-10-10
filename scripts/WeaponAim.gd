extends RefCounted
## Shared maths for barrel art and actual shot trajectories.
## All sprites use a local +X barrel axis with a calibrated artistic twist.
## Flip compensation is essential: mirroring local Y reverses that twist.
const ART_ANGLE_DEG = {
	"pistol": 16.0, "revolver": 16.0, "shotgun": 27.0, "smg": 0.0,
	"minigun": 16.0, "sniper": 25.0, "rocket": 17.0, "grenade": 16.0,
	"laser": 15.0, "tesla": 0.0, "flame": 10.0, "disc": 9.0,
	"boomerang": 0.0, "rail": 0.0, "bees": 6.0, "bowling": 10.0,
	"nailgun": 0.0, "chicken": 9.0, "bubble": 11.0, "pinball": 8.0,
	"splitbow": 0.0, "snow": 8.0,
}
const MUZZLE_DISTANCE = 22.0
const SPRITE_TIP_DISTANCE = 24.0

static func muzzle(hand: Vector2, body_aim: Vector2) -> Vector2:
	return hand + body_aim.normalized() * MUZZLE_DISTANCE

static func shot_direction(body_aim: Vector2, muzzle_point: Vector2, target: Vector2) -> Vector2:
	var to_target = target - muzzle_point
	if to_target.length_squared() <= 64.0:
		return body_aim.normalized() if body_aim.length_squared() > 0.0 else Vector2.RIGHT
	return to_target.normalized()

static func is_mirrored(direction: Vector2) -> bool:
	return direction.x < 0.0

## Gun silhouettes are mirrored per hand, independent of the world-facing
## direction. The rear off-hand grip is opposite the primary hand.
static func mirrored_grip(direction: Vector2, slot: int) -> bool:
	return is_mirrored(direction) != (slot == 1)

static func art_rotation_for_mirror(direction: Vector2, weapon_id: String, mirrored: bool) -> float:
	var correction = deg_to_rad(float(ART_ANGLE_DEG.get(weapon_id, 0.0)))
	return direction.angle() + (-correction if mirrored else correction)

static func art_rotation(direction: Vector2, weapon_id: String) -> float:
	return art_rotation_for_mirror(direction, weapon_id, is_mirrored(direction))

static func barrel_axis(rotation: float, weapon_id: String, mirrored: bool) -> Vector2:
	# Forward barrel direction in calibrated, optionally Y-flipped sprite space.
	var correction = deg_to_rad(float(ART_ANGLE_DEG.get(weapon_id, 0.0)))
	var axis = Vector2.from_angle(-correction)
	if mirrored:
		axis.y = -axis.y
	return axis.rotated(rotation)

static func sprite_anchor(muzzle_point: Vector2, direction: Vector2) -> Vector2:
	return muzzle_point - direction.normalized() * SPRITE_TIP_DISTANCE

## The two visible support arms bend outward, then forward to grip the gun.
## Left/right slots deliberately form opposite L silhouettes. They are
## decorative and never modify the real muzzle or projectile trajectory.
static func arm_pose(center: Vector2, aim: Vector2, slot: int, hand: Vector2) -> PackedVector2Array:
	var forward = aim.normalized()
	if forward.length_squared() < 0.01:
		forward = Vector2.RIGHT
	var side = forward.orthogonal()
	var sign = 1.0 if slot == 0 else (-1.0 if slot == 1 else 0.0)
	if sign == 0.0:
		return PackedVector2Array([center + forward * 7.0, hand + forward * 2.0])
	var shoulder = center + side * sign * 11.0 - forward * 5.0
	var elbow = center + side * sign * 24.0 - forward * 5.0
	var grip = hand + forward * 7.0
	return PackedVector2Array([shoulder, elbow, grip])

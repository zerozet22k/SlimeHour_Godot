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

static func art_rotation(direction: Vector2, weapon_id: String) -> float:
	var correction = deg_to_rad(float(ART_ANGLE_DEG.get(weapon_id, 0.0)))
	return direction.angle() + (-correction if is_mirrored(direction) else correction)

static func barrel_axis(rotation: float, weapon_id: String, mirrored: bool) -> Vector2:
	# Forward barrel direction in calibrated, optionally Y-flipped sprite space.
	var correction = deg_to_rad(float(ART_ANGLE_DEG.get(weapon_id, 0.0)))
	var axis = Vector2.from_angle(-correction)
	if mirrored:
		axis.y = -axis.y
	return axis.rotated(rotation)

static func sprite_anchor(muzzle_point: Vector2, direction: Vector2) -> Vector2:
	return muzzle_point - direction.normalized() * SPRITE_TIP_DISTANCE

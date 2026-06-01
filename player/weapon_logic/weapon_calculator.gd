extends RefCounted
class_name WeaponCalculator

static var recoil_cache: Dictionary[WeaponStats, float] = {}
static var dps_cache: Dictionary[WeaponStats, float] = {}


static func calculate_recoil_score(data: WeaponStats) -> float:
	if recoil_cache.has(data):
		return recoil_cache[data]
	
	var avg_kick := 0.0
	var avg_snap := 0.0
	var avg_return := 0.0

	if data.layered_recoil_enabled and data.layered_recoil != null:
		var rd: RecoilData = data.layered_recoil

		var kick_score := 0.0
		var count := 0
		for i in rd.hip_camera_max_recoil_data.size():
			var max_v: Vector3 = rd.hip_camera_max_recoil_data[i]
			var min_v: Vector3 = rd.hip_camera_min_recoil_data[i]
			kick_score += abs(max_v.y) * 2.0 + abs(max_v.x)
			kick_score += abs(min_v.y) * 2.0 + abs(min_v.x)
			count += 2
		avg_kick = kick_score / maxf(count, 1)

		var snap_sum := 0.0
		for v in rd.hip_camera_recoil_snappines:
			snap_sum += v.length()
		avg_snap = snap_sum / maxf(rd.hip_camera_recoil_snappines.size(), 1)

		var return_sum := 0.0
		for v in rd.hip_camera_recoil_return_speed:
			return_sum += v.length()
		avg_return = return_sum / maxf(rd.hip_camera_recoil_return_speed.size(), 1)
	else:
		var max_v: Vector3 = data.max_hip_camera_kick
		var min_v: Vector3 = data.min_hip_camera_kick
		avg_kick = (abs(max_v.y) * 2.0 + abs(max_v.x) + abs(min_v.y) * 2.0 + abs(min_v.x)) / 2.0
		avg_snap = data.snappinnes
		avg_return = data.return_speed

	var return_factor := 1.0 / maxf(avg_return, 0.1)
	var nonstop_factor := data.max_non_stop_mult if data.non_stop_mult_enabled else 1.0
	var raw := avg_kick * avg_snap * return_factor * nonstop_factor

	const max_expected := 500.0
	
	var result : float = clampf(raw / max_expected * 100.0, 0.0, 100.0)
	recoil_cache[data] = result
	
	return result


static func calculate_dps(data: WeaponStats) -> float:
	if dps_cache.has(data):
		return dps_cache[data]
	
	var result : float = data.damage * max(
		data.fire_rate,
		data.burst_fire_rate
		) / 60.0 * max(
			1.0, 
			data.buckshot_size
			)
	
	dps_cache[data] = result
	
	return result

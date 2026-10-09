class_name MatchScore
extends RefCounted
## Volleyball scoring (docs/GDD.md "Scoring"): points win sets, sets win the match.
## A set is won at `set_points_to_win` with a lead of `set_win_by`, or straight
## away at `set_point_cap`. Plain data; MatchSim decides when a point happens.

enum Result { POINT, SET, MATCH }

## Points in the current set, per team (0, 1). Kept as-is when the match ends.
var points: Array[int] = [0, 0]
var sets: Array[int] = [0, 0]
## 1-based number of the set being played.
var set_number: int = 1
## Team that won the match, or -1.
var winner: int = -1

var _rules: GameRules


func _init(rules: GameRules) -> void:
	_rules = rules


func award_point(team: int) -> Result:
	if winner >= 0:
		return Result.MATCH
	points[team] += 1
	var mine: int = points[team]
	var theirs: int = points[1 - team]
	var won_set: bool = mine >= _rules.set_point_cap or (
		mine >= _rules.set_points_to_win and mine - theirs >= _rules.set_win_by
	)
	if not won_set:
		return Result.POINT
	sets[team] += 1
	if sets[team] >= _rules.match_sets_to_win:
		winner = team
		return Result.MATCH
	points = [0, 0]
	set_number += 1
	return Result.SET

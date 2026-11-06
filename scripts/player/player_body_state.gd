class_name PlayerBodyState
extends RefCounted

enum Stance { STAND, CROUCH }
enum Move { IDLE, WALK, SPRINT }

var stance: Stance = Stance.STAND


func wants_crouch() -> bool:
	return stance == Stance.CROUCH


func can_sprint() -> bool:
	return stance == Stance.STAND


func can_walk() -> bool:
	return true


func can_jump() -> bool:
	return true


func enter_crouch() -> void:
	stance = Stance.CROUCH


func enter_stand() -> void:
	stance = Stance.STAND


func resolve_move(moving: bool, sprint_requested: bool) -> Move:
	if not moving:
		return Move.IDLE
	if sprint_requested and can_sprint():
		return Move.SPRINT
	return Move.WALK

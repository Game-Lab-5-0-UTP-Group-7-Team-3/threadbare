# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
class_name FillGameLogic
extends Node
## Manages the logic of the fill-matching game.

## Emited when [member barrels_completed] reaches [member barrels_to_win].
signal goal_reached

## How many barrels to complete for winning.
@export var barrels_to_win: int = 3

@export var intro_dialogue: DialogueResource

## Counter for the completed barrels.
var barrels_completed: int = 0

## LISTA 1: Enemigos a eliminar en orden (NPC 1, 2, 3...)
var npcs_to_remove: Array[NodePath] = [
	NodePath("../OnTheGround/ThrowingNPC"),  # Se elimina con el 1er barril
	NodePath("../OnTheGround/ThrowingNPC2"), # Se elimina con el 2do barril
	NodePath("../OnTheGround/ThrowingNPC3"), # Se elimina con el 3er barril
	NodePath("../OnTheGround/ThrowingNPC4"), # Se elimina con el 4to barril
	NodePath("../OnTheGround/ThrowingNPC5"), # Se elimina con el 5to barril
]

## LISTA 2: Puertas a eliminar en orden (Door Enter, Door Enter2, ...)
var doors_to_remove: Array[NodePath] = [
	NodePath("../Door Enter"),    # Se elimina con el 1er barril
	NodePath("../Door Enter2"),   # Se elimina con el 2do barril
	NodePath("../Door Enter3"),   # Se elimina con el 3er barril
	NodePath("../Door Enter4"),   # Se elimina con el 4to barril
	NodePath("../Door Enter5"),   # Se elimina con el 5to barril
]


func start() -> void:
	var player: Player = get_tree().get_first_node_in_group("player")
	if player:
		player.mode = Player.Mode.FIGHTING
	get_tree().call_group("throwing_enemy", "start")
	for filling_barrel: FillingBarrel in get_tree().get_nodes_in_group("filling_barrels"):
		filling_barrel.completed.connect(_on_barrel_completed)
	_update_allowed_colors()


func _ready() -> void:
	var filling_barrels: Array = get_tree().get_nodes_in_group("filling_barrels")
	# Asegura que la meta no exceda el número de barriles existentes
	barrels_to_win = clampi(barrels_to_win, 0, filling_barrels.size())
	if intro_dialogue:
		var player: Player = get_tree().get_first_node_in_group("player")
		DialogueManager.show_dialogue_balloon(intro_dialogue, "", [self, player])
		await DialogueManager.dialogue_ended
	start()


func _update_allowed_colors() -> void:
	var allowed_labels: Array[String] = []
	var color_per_label: Dictionary[String, Color]
	for filling_barrel: FillingBarrel in get_tree().get_nodes_in_group("filling_barrels"):
		if filling_barrel.is_queued_for_deletion():
			continue
		
		if filling_barrel.label not in allowed_labels:
			allowed_labels.append(filling_barrel.label)
			if not filling_barrel.color:
				continue
			color_per_label[filling_barrel.label] = filling_barrel.color
	for enemy: ThrowingEnemy in get_tree().get_nodes_in_group("throwing_enemy"):
		enemy.allowed_labels = allowed_labels
		enemy.color_per_label = color_per_label


func _on_barrel_completed() -> void:
	# 1. Incrementa el contador de barriles
	barrels_completed += 1
	
	var index_to_remove = barrels_completed - 1
	
	# 2. LÓGICA DE ELIMINACIÓN SECUENCIAL
	
	# Eliminar la PUERTA correspondiente (si existe en la lista)
	if index_to_remove >= 0 and index_to_remove < doors_to_remove.size():
		var door_path: NodePath = doors_to_remove[index_to_remove]
		var door_to_remove: Node = get_node_or_null(door_path) 
		
		if is_instance_valid(door_to_remove):
			door_to_remove.queue_free() 
			
	# Eliminar el NPC/Enemigo correspondiente (si existe en la lista)
	if index_to_remove >= 0 and index_to_remove < npcs_to_remove.size():
		var npc_path: NodePath = npcs_to_remove[index_to_remove]
		var npc_to_remove: Node = get_node_or_null(npc_path) 
		
		if is_instance_valid(npc_to_remove):
			
			# Limpia los proyectiles del enemigo antes de eliminarlo
			if npc_to_remove.has_method("cleanup_projectiles"):
				npc_to_remove.cleanup_projectiles()
				
			# Luego elimina el nodo del enemigo
			npc_to_remove.remove()
			
	# 3. Actualiza qué proyectiles deben lanzar los enemigos restantes
	_update_allowed_colors()
	
	# 4. Chequeo de Victoria
	if barrels_completed < barrels_to_win:
		return
		
	# Lógica de Victoria: Desactiva el combate y emite la señal
	get_tree().call_group("throwing_enemy", "remove")
	get_tree().call_group("projectiles", "remove")
	var player: Player = get_tree().get_first_node_in_group("player")
	if player:
		player.mode = Player.Mode.COZY
	goal_reached.emit()

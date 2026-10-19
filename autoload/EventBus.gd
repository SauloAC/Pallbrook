extends Node

# Global signals: any system can emit or listen to these
@warning_ignore_start("unused_signal")
signal phase_changed(is_night: bool)
signal npc_died(npc_name: String)
signal clue_found(clue_id: String)
signal player_collapsed
signal player_slept
signal hour_changed(hour: int)
signal dialogue_started(speaker: String, text: String)
signal conversation_started(npc: Node)  # Talking to a living NPC: opens the question menu
signal dialogue_ended
signal accusation_requested(npc: Node)
signal game_ended(won: bool, message: String)
